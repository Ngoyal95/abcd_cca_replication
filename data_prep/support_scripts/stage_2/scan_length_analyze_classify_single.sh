#! /bin/bash

# scan_length_analye_classify_single.sh - scan length crawler/classifier
# NOTE - this script runs on a single subject, and is intended to be run as batch job (SLURM or swarm)
# Created: 6/16/20
# Last edited:
# Written by Nikhil Goyal, National Institute of Mental Health, 2019-2020

# This script will do the following (in this order):
#   1.  Iterates over the scans (raw data) for all subjects, and determines how long their scans are (stores as one file per subject)
#       [generate file: NDARINVxxxxxxx_scan_lengths.txt]
#   2.  Based on a cutoff of 0.75*380=285, it will classify scans as 0 (exclude, scan length < thresh) or 1 (include, scan length >= thresh) 
#       [generate file: NDARINVxxxxxxx_scan_classified.txt]
#   4.  Based on the scan lengths [NDARINVxxxxxxx_scan_lengths.txt] and scan include/exclude [NDARINVxxxxxxx_scans_to_use.txt] clean their censor file
#       (this calls a separate script called clean_censors.py, input is a list of subjects)
#   5.  Generate a file (abcd_cca_replication/data_prep/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/data/icafix_cmds/sub-NDARINVxxxxxxxx.txt)
#       This file contains a string of the proper runs for an ICA+FIX cmd for this subject
#   6.  Detect and report any subjects who need to be excluded because they no longer meet the 600 timepoint minimum requirement.

# Required tools on PATH:
# fsl

# Verbose output (debugging)
set -x

# Check for config
sub=$1
ABCD_CCA_REPLICATION=$2

if [[ -f $ABCD_CCA_REPLICATION/pipeline.config ]]; then
    # config exists, so run it
    # This will load BIDS_PATH, DERIVATIVES_PATH, DATA_PREP variables
    . $ABCD_CCA_REPLICATION/pipeline.config
else
    echo "$ABCD_CCA_REPLICATION/pipeline.config does not exist! Please run create_config.sh."
    exit 1
fi

DATAFOLDER=$DATA_PREP/data/stage_2/scan_length_analyze_classify/
ICAFIX_CMDS=$DATA_PREP/data/stage_2/icafix_cmds/

fsl_exec=$(which fsl)
if [ ! -x "$fsl_exec" ] ; then
    echo "Error - FSL is not on PATH. Exiting"
    exit 1
fi

echo "Fetching scan length data for subject and classifying scans for inclusion/exclusion."

# summary file, all subject ids + scan lengths
echo $sub >> $DATAFOLDER/subs_and_lengths.txt

# Pull scan lengths from all available scans (format sub-NDARINVFL02R0H4_ses-baselineYear1Arm1_task-rest_run-[0-9][0-9]_bold.nii.gz)
# Note, values are written to file in ascending order (i.e. scan 1 length on line one, scan 2 on line 2, etc...)
find $BIDS_PATH/$sub/ses-baselineYear1Arm1/func/ -type f -name "*task-rest_run*[0-9][0-9]_bold.nii.gz" | sort | xargs -L 1 fslnvols | tee -a $DATAFOLDER/subs_and_lengths.txt | tee -a $DATAFOLDER/lengths.txt | tee $DATAFOLDER/${sub}_scan_lengths.txt >/dev/null

# Create classifier file for each subject
# Call external script classify_scans.py
# result = 1 --> subject good to use, has enough time post-censoring
# result = 2 --> subject must be dropped, not enough time post-censoring
# result = 0 --> an error occured, skip over the subject
python $SUPPORT_SCRIPTS/stage_2/classify_scans_get_lens_clean_censors.py ${sub} $DATAFOLDER/${sub}_scan_lengths.txt $CENSOR_FILES/${sub}_censor.txt $DATAFOLDER/${sub}_scans_classified.txt $DATAFOLDER/${sub}_censored_scan_lengths.txt $CENSOR_FILES_CLEAN/${sub}_censor.txt
result=$?

# echo "python $SUPPORT_SCRIPTS/stage_2/classify_scans_get_lens_clean_censors.py ${sub} $DATAFOLDER/${sub}_scan_lengths.txt $CENSOR_FILES/${sub}_censor.txt $DATAFOLDER/${sub}_scans_classified.txt $DATAFOLDER/${sub}_censored_scan_lengths.txt $CENSOR_FILES_CLEAN/${sub}_censor.txt"

# Check that the subject has enough total time based on returned "result"
if [[ $result -eq 2 ]]; then
    # Subject dropped from study, note this
    echo "Dropping subject $sub, has less than 600 seconds of scan time post-censoring."
    echo $sub >> $DATA_PREP/data/stage_2/dropped_post_censor_subjects.txt
elif [[ $result -eq 1 ]]; then
    # subject still eligible, create its task-rest0 string for ICA+FIX cmd
    # add subject to final list of subjects
    echo $sub >> $DATA_PREP/data/stage_2/post_censor_subjects.txt

    # Now create their cmd
    # Keep track of which scan we're looking at
    count=1 
    # total timepoints for valid scans for a subject
    total_tps=0
    cmd_str=""
    while read len
    do
        if [[ $len -ge 285 ]]; then
            # post-censor scan length meets minimum cutoff length to be compatible with ICA+FIX.
            # Aggregate their cmd string
            if [[ $count -eq 1 ]]; then
                # Prepend a 0, remove @ at beginning
                cmd_str=task-rest0$count/task-rest0$count.nii.gz
            elif [[ $count -lt 10 ]]; then
                # Prepend 0 since < 10, but include the @ at beginning
                cmd_str=$cmd_str@task-rest0$count/task-rest0$count.nii.gz
            else
                # No need to prepend 0
                cmd_str=$cmd_str@task-rest$count/task-rest$count.nii.gz
            fi
        elif [[ $len -lt 285 ]]; then
            # Scan too short, skip this (i.e. do nothing)
            :
        else
            # something went wrong
            echo "An error occured while generating ICA+FIX cmd string for $sub scan $count."
        fi
        ((count++))
    done < $DATAFOLDER/${sub}_censored_scan_lengths.txt

    # echo the ICA+FIX cmd to file
    echo $cmd_str >> $ICAFIX_CMDS/$sub.txt

elif [[ $result -eq 0 ]]; then
    # Error handling
    echo "Something went wrong when processing $sub in script classify_scans_get_lens_clean_censors.py. Omitting subject."
else
    # Something else went wrong (maybe not needed?)
    echo "An unknown error occurred while processing $sub"
fi

((debug++))
if [[ $debug -ge 10 ]]; then
    break
fi

echo "WARNING: $subs_dropped subject dropped because they do not meet the timepoint threshold after censoring."

echo "Done cleaning censor and classifying subjects include/exclude based on post-censor total scan time."