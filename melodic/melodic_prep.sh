#! /bin/bash

# Written by Nikhil Goyal, National Institute of Mental Health, 2019-2020
# melodic_setup.sh - a script to prep the resting state timeseries files for MELODIC group-ICA processing

# Run this function within the melodic/ folder it resides inside.

##### Functions
usage()
{
	echo "usage: melodic_setup.sh -d <path/to/main/abcd_bids/> -o </path/to/melodic outputs>"
    echo "NOTE you must provide the ABSOLUTE PATH to the main directory of the ABCD download. for example: /data/ABCD/abcd_bids/bids/"
}

#### Setup stuff
while getopts ":f:d:o:h" arg; do
    case $arg in
        d) 	BIDS_PATH=$OPTARG;;
        o) 	OUT_PATH=$OPTARG;;
        h) 	usage
            exit 1
            ;;
    esac
done

# Make directory for the swarm files
if [ ! -d ./NIFTI ]; then
    mkdir -p ./NIFTI;
fi

if [ ! -d ./groupICA200.gica ]; then
    mkdir -p ./groupICA200.gica;
fi

if [ ! -d ./other ]; then
    mkdir -p ./other;
else
    rm -r ./other;
    mkdir -p ./other;
fi

# Generate a list of all subjects who have files in the derivatives folder(ex. sub-NDARINVZN4F9J96)
ls $BIDS_PATH/derivatives/abcd-hcp-pipeline | grep sub- > other/subject_list.txt

# get list of subject folders in format "ABSPATH/abcd_bids/bids/sub-NDAR<????>"
# find $BIDS_PATH -maxdepth 1 | grep sub-NDAR > other/subject_list.txt

while read sub; do
    # Get absolute path for their sub-<subject_ID>_ses-baselineYear1Arm1_task-rest_bold_desc-filtered_timeseries.dtseries.nii files (CIFTIs)
    fname=${BIDS_PATH}/derivatives/abcd-hcp-pipeline/${sub}/ses-baselineYear1Arm1/func/${sub}_ses-baselineYear1Arm1_task-rest_bold_desc-filtered_timeseries.dtseries.nii 
    if [[ -f "$fname" ]]; then
        echo $fname >> other/CIFTI_files.txt
    else
        echo $fname >> other/missing_CIFTI_files.txt
    fi
    
    # file=$(find $BIDS_PATH/derivatives/abcd-hcp-pipeline/$sub/ses-baselineYear1Arm1/func/ -name "*_ses-baselineYear1Arm1_task-rest_bold_desc-filtered_timeseries.dtseries.nii");
    # echo $file > other/CIFTI_files.txt
done < other/subject_list.txt