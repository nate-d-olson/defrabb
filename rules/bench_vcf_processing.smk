# process T2TXY_v2.7.dip.vcf to match hifiDV GT using JZ sed command `
rule fix_XY_genotype:
    input:
        "results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.vcf.gz",
    output:
        "results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.fix_XY_genotype.vcf.gz",
    conda:
        "../envs/dipcall.yml"
    log:
        "logs/fix_XY_genotype/{bench_id}_{prefix}.log",
    conda:
        "../envs/download_remotes.yml"
    shell:
        """
        gunzip -c {input} \
            | sed 's/\.|1:0,1/1:1/;s/1|\.:0,1/1:1/'  \
            | bgzip -c \
            > {output}
        """


## Use when evaluating assembly accuracy with established benchmark
##  This rule is an artifact from previous assembly benchmarking pipeline
##  Not current used - keeping here for potential future use
rule dip_gap2homvarbutfiltered:
    input:
        "results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.vcf.gz",
    output:
        "results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.gap2homvarbutfiltered.vcf.gz",
    # bgzip is part of samtools, which is part of the dipcall env
    conda:
        "../envs/download_remotes.yml"
    log:
        "logs/dip_gap2homvarbutfiltered/{bench_id}_{prefix}.log",
    shell:
        """
        gunzip -c {input} |\
        sed 's/1|\./1|1/' |\
        grep -v 'HET\|GAP1\|DIP' |\
        bgzip -c > {output}
        """


## Primarily for SVs
rule split_multiallelic_sites:
    input:
        "results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.vcf.gz",
    output:
        vcf="results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.split_multi.vcf.gz",
        vcf_tbi="results/draft_benchmarksets/{bench_id}/intermediates/{prefix}.split_multi.vcf.gz.tbi",
    conda:
        "../envs/bcftools.yml"
    log:
        "logs/split_multiallelic_sites/{bench_id}_{prefix}.log",
    shell:
        """
        bcftools norm -m-any {input} -Oz -o {output.vcf} 2> {log}
        tabix -p vcf {output.vcf} 2>> {log}
        """


# Split multi-allelic variants, left-align/normalize, remove duplicates, and
# filter all lines that have REF or ALT > 20bp and no '*' characters. If this
# isn't done, svwiden will choke on commas and star characters
rule filter_lt19_and_norm:
    input:
        vcf="results/draft_benchmarksets/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.vcf.gz",
        ref="resources/references/{ref_id}.fa",
    output:
        "results/draft_benchmarksets/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.gt19_norm.vcf.gz",
    resources:
        mem_mb=8000,
    conda:
        "../envs/bcftools.yml"
    log:
        "logs/gt19_norm/{bench_id}_{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.log",
    shell:
        """
        bcftools norm -m- -Ou {input.vcf} \
            | bcftools norm -d exact -Ou \
            | bcftools norm -cs -f {input.ref} -Ov\
            | awk '($4!="*" && $5!="*" && (length($4)>20 || length($5)>20)) || $1~/^#/' \
            | bcftools sort -m{resources.mem_mb}m -Oz > {output} 2> {log}
        """


## Using Adotto as tr catalogue for SV annotations - currently only for GRCh38
## https://github.com/ACEnglish/adotto
rule get_adotto_tr_anno_db:
    output:
        bed="resources/references/{ref_id}_adotto_trf.bed.gz",
        tbi="resources/references/{ref_id}_adotto_trf.bed.gz.tbi",
    conda:
        "../envs/download_remotes.yml"
    params:
        url=get_addoto_tr_anno_db_url,
    log:
        "logs/get_addoto_tr_anno_db/{ref_id}.log",
    shell:
        """
        curl -L {params.url} 2> {log} \
        | zcat \
        | cut -f1-3,18 \
        | bgzip > {output.bed}

        tabix {output.bed}
        """

rule get_trf_db:
    output:
        bed="resources/references/{ref_id}_trf.bed.gz",
        tbi="resources/references/{ref_id}_trf.bed.gz.tbi"
    conda:
        "../envs/download_remotes.yml"
    params:
        url=get_trf_db_url
    log:
        "logs/get_trf_db/{ref_id}.log",
    shell: """
        curl -L {params.url} 1> {output.bed} 2> {log} 
        tabix {output.bed}
    """

rule run_truvari_anno_trf:
    input:
        vcf="results/draft_benchmarksets/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.gt19_norm.vcf.gz",
        vcfidx="results/draft_benchmarksets/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.gt19_norm.vcf.gz.tbi",
        ref="resources/references/{ref_id}.fa",
        trdb="resources/references/{ref_id}_trf.bed.gz",
    output:
        vcf="results/draft_benchmarksets/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.trfanno.vcf",
    log:
        "logs/truvari_anno_trf/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.log",
    conda:
        "../envs/truvari.yml"
    params:
        min_length=20,
    threads: 5
    shell:
        """
        truvari anno trf \
            -i {input.vcf} \
            -o {output.vcf} \
            -r {input.trdb} \
            -f {input.ref} \
            -t {threads} \
            --min-length {params.min_length} \
            -e trf &> {log}
        """


rule move_asm_vcf_to_draft_bench:
    input:
        lambda wildcards: f"results/asm_varcalls/{bench_tbl.loc[wildcards.bench_id, 'vc_id']}/{{ref_id}}_{{asm_id}}_{{vc_cmd}}-{{vc_param_id}}.dip.vcf.gz",
    output:
        "results/draft_benchmarksets/{bench_id}/intermediates/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.vcf.gz",
    log:
        "logs/process_benchmark_vcf/{bench_id}_{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.log",
    conda:
        "../envs/download_remotes.yml"
    shell:
        "cp {input} {output} &> {log}"


rule move_processed_draft_bench_vcf:
    input:
        get_processed_vcf,
    output:
        "results/draft_benchmarksets/{bench_id}/{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.vcf.gz",
    log:
        "logs/move_processed_draft_bench_vcf/{bench_id}_{ref_id}_{asm_id}_{vc_cmd}-{vc_param_id}.log",
    conda:
        "../envs/download_remotes.yml"
    shell:
        "cp {input} {output}"
