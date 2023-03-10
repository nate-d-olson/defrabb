#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Author: Nathan Dwarshuis
import sys
from os import stat as os_stat
import pandas as pd
from pybedtools import BedTool
from itertools import accumulate

# usage: subtract_exclusions INPUT_BED OUTPUT_BED EXCLUDED_BEDS ...


def count_bp(bedfile):
    df = bedfile.to_dataframe(names=["chr", "start", "end"])
    ## To avoid error with empty bed files
    if len(df.index) < 1:
        return int(0)
    return int((df["end"] - df["start"]).sum())


def print_summary(after, excluded, exclusion_stats):
    # ASSUME: 'excluded' will have one less than 'after', since 'after' will
    # have the initial bed file before any exclusions were performed
    paths = ["initial"] + [*map(lambda b: b.fn, excluded)]
    bed_lengths = [0] + [*map(count_bp, excluded)]
    after_lengths = [*map(count_bp, after)]
    pd.DataFrame(
        [*zip(paths, bed_lengths, after_lengths)],
        columns=["exclusion", "exclusion_length", "resulting_length"],
    ).to_csv(exclusion_stats, index=False, sep="\t")


def get_excluded(paths):
    non_empty_paths = [i for i in paths if os_stat(i).st_size != 0]
    ## TODO - add warning for empty paths
    return [*map(BedTool, non_empty_paths)]


def exclude_beds(input_bed, excluded_beds):
    after = [
        *accumulate(
            excluded_beds,
            lambda acc, to_exclude: acc.subtract(to_exclude),
            initial=input_bed,
        )
    ]
    return after


def main():
    input_bed = BedTool(sys.argv[1])
    excluded_beds = get_excluded(sys.argv[4:])
    after_exclusions = exclude_beds(input_bed, excluded_beds)
    print_summary(after_exclusions, excluded_beds, sys.argv[3])
    after_exclusions[-1].saveas(sys.argv[2])


main()
