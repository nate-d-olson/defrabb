#!/usr/bin/env bash
## defrabb wrapper script for executing and archiving framework

## Script usage text
usage() { 
    local err=${1:-""};
    cat <<EOF
Usage: $0 [options] [extra arguments passed to snakemake]
Required:
    -r STRING   Analysis RUN ID, please use following naming convention YYYYMMDD_milestone_brief-id

Optional:
    -a FILE     defrabb run analyses table, if not provided assumes at config/analyses_[RUN ID].tsv
    -o DIR      output directory for framework run, pipeline will create a named directory [RUN ID] at defined location, default is "/defrabb_runs/runs_in_progress/", note this is a system specific path.
    -s all|pipe|report|archive|release  Defining which workflow steps are run
                                    all: pipe, report, and archive (default)
                                    pipe: just the snakemake pipeline
                                    report: generating the snakemake run report
                                    archive: generating snakemake archive tarball
                                    release: copy run output to NAS for upload to Google Drive
    -j          number of jobs used by snakemake, default number of system cores
    -n          Run snakemake in dry run mode, only runs pipe step
    -F          Force rerunning all steps, includes downloading resouces
    -k          keep going with independent jobs if one job fails
    -u          unlock snakeamke run directory
EOF
>&2;
    echo -e "\n$err" >&2;
    exit 1;
}

## Parsing command line arguments
dry_run=""
force=""
steps="all"
unlock=""
keepgoing=""
jobs=0

while getopts "r:a:o:s:j:nFku" flag; do
    case "${flag}" in
        r) runid=${OPTARG};;
        a) analyses_file=${OPTARG};;
        o) out_dir=${OPTARG};;
        s) steps=${OPTARG};;
        n) dry_run="-n";;
        j) jobs=${OPTARG};;
        F) force="-F";;
        k) keepgoing="-k";;
        u) unlock="--unlock";;
        *) usage;;
    esac
done
shift $((OPTIND-1))
echo ${jobs}
extra_args="$*" ## Capturing extra arguments for snakemake
 
if [ -z "${runid}" ]; then
    usage "Missing required parameter -r";
fi

## Getting system resource information
source etc/common.sh

## Setting the number of jobs run by snakemake to either number of cores on 
## system or user specified value.
cores=$(find_core_limit)
if [ ${jobs} < 1 ]; then
    cores=${jobs};
fi

mem_gb=$(find_mem_limit_gb)
log "Number of cores: $cores"
log "Memory limit: $mem_gb GB"

# SET VARIABLES WITH EACH RUN
### setting run analyses table path
echo "${analyses_file}"

if [[ -z ${analyses_file} ]]; then
    analyses_file="config/analyses_${runid}.tsv"
fi

### Making sure analyses table exists
if [[ -f "${analyses_file}" ]]; then
    echo "Analyses Table Path: ${analyses_file}"
else
    echo "analyses table file not present at: ${analyses_file}"
fi


### setting run directory path
if [[ -n "${out_dir}" ]]; then
   run_dir="${out_dir}/${runid}"
else
   run_dir="/defrabb_runs/runs_in_progress/${runid}"
fi

mkdir -p ${run_dir}

echo "Run output directory: ${run_dir}"

## path to workflow run log file
run_log="${run_dir}/run.log"

## Only run pipeline if -n used
if [[ ${dry_run} == "-n" ]]; then steps="pipe"; fi


## setting report name
report_name="${runid}.report.zip"

## setting archive path
smk_archive_path="${run_dir}/${runid}.archive.tar.gz"

### Directory on NAS used for archiving runs
archive_dir="/mnt/bbdhg-nas/analysis/defrabb-runs/"


## Activating mamba environment
##   TODO add check to see if defrabb env activated

################################################################################
## System Configuration

log "Saving mamba runtime environment"
mamba env export --file ${run_dir}/defrabb_environment.yml -n defrabb

## Run info 
gitcommit=$(git rev-parse HEAD)
echo "DeFrABB repo last commit: ${gitcommit}" > ${run_log}

echo "Repo Status"
git status >> ${run_log}

################################################################################
# Run Snakemake pipeline
set -euo pipefail

if [ ${steps}  == "all" ] || [ ${steps} == "pipe" ]; then
    log "Running DeFrABB snakemake pipeline";

    snakemake \
            --printshellcmds \
            --rerun-incomplete \
            --jobs "${cores}" \
            --resources "mem_gb=${mem_gb}" \
            --use-conda \
            --config analyses=${analyses_file} \
            --directory ${run_dir} \
            ${dry_run} \
            ${force} \
            ${unlock} \
            ${keepgoing} \
            ${extra_args}

    log "Done Executing DeFrABB"

fi


## Generating Report
if [ ${steps}  == "all" ] || [ ${steps} == "report" ]; then
    log "Generating Snakemake Report"

    time snakemake \
            --config analyses=${analyses_file} \
            --directory ${run_dir} \
            --report ${report_name};

    log "Done Generating Report"

fi


## Making snakemake archive
if [ ${steps}  == "all" ] || [ ${steps} == "archive" ]; then
    log "Generating Snakemake Archive"

    time snakemake \
    --use-conda \
    --config analyses=${analyses_file} \
    --archive ${smk_archive_path};

    log "Done Making Snakemake Archive"

fi

## Archiving run - syncing run directory with NAS
if [ ${steps}  == "all" ] || [ ${steps} == "release" ]; then
    log "Releasing Run"

    time rsync -rlptoDv \
        --exclude=.snakemake \
        --exclude=resources \
        --exclude=GRCh38_chr21 \
        --exclude=GRCh38 \
        --exclude=GRCh37 \
        --exclude=CHM13v2.0 \
        ${run_dir} \
        ${archive_dir};

    log "Done Releasing Run"

fi

log "DeFrABB execution complete!"

### Resources for bash scripting and snakemake wrappers
## Example snakemake pipeline wrapper script
# https://github.com/marbl/verkko/blob/master/src/verkko.sh
# https://github.com/GooglingTheCancerGenome/sv-callers/blob/master/run.sh
# Handling command line options

## Collection of example bash scripts
# https://github.com/swoodford/aws/blob/master/vpc-sg-rename-group.sh


## Example python wrapper script
# https://github.com/CVUA-RRW/FooDMe/blob/master/foodme.py
## Python click based CLI
# https://github.com/gymrek-lab/haptools/blob/main/haptools/__main__.py

## Template repo with run wrapper script and utility functions
# https://github.com/fulcrumgenomics/python-snakemake-skeleton
## Bash script templates
# https://github.com/ralish/bash-script-template/blob/main/template.sh
