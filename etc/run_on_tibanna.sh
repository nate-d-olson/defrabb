#!/usr/bin/zsh
## Wrapper script for running Asm benchmarking pipeline using GIAB team tibanna

## Input parameters will convert to script arguments
## Number of jobs to run
JOBS=5
RUNDIR="defrabb-test"
DISKMB=50000
DRYRUN=""
#DRYRUN="--dryrun"
ANALYSES="config/analyses.tsv"

#### Personal
PROFILE="default"
UNICORN="tibanna_unicorn_giab_v1"

## Setting Tibanna Unicorn
export TIBANNA_DEFAULT_STEP_FUNCTION_NAME=${UNICORN}

## Running Snakemake
time \
	snakemake \
		--use-conda -j${JOBS} -p --verbose ${DRYRUN} --config analyses=${ANALYSES} \
		--tibanna \
		--tibanna-config \
			subnet=subnet-083080d579317ad61 \
			log_bucket=giab-tibanna-logs \
			root_ebs_size=32 \
		--precommand "cat etc/nist_dns.txt >> /etc/resolv.conf; cat /etc/resolv.conf" \
		--default-remote-provider S3 \
		--default-remote-prefix=giab-tibanna-runs/${RUNDIR} \
		--default-resources disk_mb=50000 \
		--keep-going
