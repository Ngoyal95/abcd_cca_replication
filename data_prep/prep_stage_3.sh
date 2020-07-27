#! /bin/bash

# prep_stage_3.sh
# Created: 6/21/20 (pipeline_version_1.3)
# Updated: (rewritten) 7/24/20 pipeline_version_1.5

# Written by Nikhil Goyal, National Institute of Mental Health, 2019-2020

# Expected tools on PATH:
# None.

# Example usage:
#   ./prep_stage_3.sh

# Check for and load config
ABCD_CCA_REPLICATION="$(dirname "$PWD")"
if [[ -f $ABCD_CCA_REPLICATION/pipeline.config ]]; then
    # config exists, so run it
    # This will load BIDS_PATH, DERIVATIVES_PATH, DATA_PREP variables
    . $ABCD_CCA_REPLICATION/pipeline.config
else
    echo "$ABCD_CCA_REPLICATION/pipeline.config does not exist! Please run create_config.sh."
    exit 1
fi

# Check if the following folders/files exist
if [[ -d $STAGE_3_OUT ]]; then
    rm $STAGE_3_OUT/*.txt
    rm $STAGE_3_OUT/*.Rds
    :
else
    mkdir -p $STAGE_3_OUT
    mkdir -p $STAGE_3_OUT/swarm_logs/icafix/
    mkdir -p $STAGE_3_OUT/swarm_logs/censor_and_truncate/
    mkdir -p $STAGE_3_OUT/NIFTI/
fi

echo "--- PREP_STAGE_3 ---"
echo "PREP STAGE 3 Requires a number of steps to be performed manually. A number of scripts will be run to generate batch commands (designed for the NIH Biowulf) along with instructions on how to use the commands."
echo "If you are not using the NIH Biowulf, you will need to adapt these commands to your own HPC."

echo "STEP 1: ICA+FIX"
echo "For the ICA+FIX runs, we recommend using our included fix_multi_run.sh script, with ICA+FIX 1.06.15 and HPC pipeline 4.1.3"
echo "You will need to properly configure the ICA+FIX settings.sh file for your system."
echo "Example ICA+FIX command: "
echo "  cd /path/to/subject/folder/MNINonLinear/Results/ /path/to/fix_multi_run.sh task-rest01/task-rest01.nii.gz@task-rest02/task-rest02.nii.gz 2000 fix_proc/task-rest_concat TRUE"
echo "NOTE, if you want to change the SWARM commands, you need to manually change the code in this script."
while read subject; do
    icafix=$(cat $STAGE_1_OUT/icafix_cmds/$FD_THRESH/$SCAN_FD_THRESH_1/$subject.txt)
    echo "export MCR_CACHE_ROOT=/lscratch/\$SLURM_JOB_ID && module load R fsl connectome-workbench && cd /data/ABCD_MBDU/abcd_bids/bids/derivatives/dcan_reproc/$subject/ses-baselineYear1Arm1/files/MNINonLinear/Results && /data/ABCD_MBDU/goyaln2/fix/fix_multi_run.sh $icafix 2000 fix_proc/task-rest_concat TRUE /data/ABCD_MBDU/goyaln2/fix/training_files/HCP_Style_Single_Multirun_Dedrift.RData" >> $STAGE_3_OUT/icafix.swarm
done < $STAGE_2_OUT/stage_2_final_subjects.txt
echo "ICA+FIX SWARM file generated! Located in $STAGE_3_OUT/icafix.swarm."
echo "Run the swarm as follows:"
echo "  swarm -f icafix.swarm -g 32 --gres=lscratch:50 --time 24:00:00 --logdir $STAGE_3_OUT/swarm_logs/icafix/ --job-name icafix"


echo "STEP 2: Get final subject list (based on presence of task-rest_concat_hp2000_clean.nii.gz)"
echo "STEP 3: Generate censor+truncate commands)"
echo "To perform steps 2 & 3, run the script $SUPPORT_SCRIPTS/prep_stage_3_steps2and3.sh (no arguments required)."
echo "NOTE, Step 3 will require manually submitting/running a SWARM job to do censor+truncate."


echo "STEP 4: MELODIC Group-ICA"
echo "Run MELODIC using the script: $SUPPORT_SCRIPTS/run_melodic.sh"

echo "STEP 5: dual_regression"
echo "Run dual_regression as follows (NOTE, on the NIH Biowulf this command will be automatically submnitted to the cluster):"
echo " ABCD_CCA_REPLICATION="$(dirname "$PWD")" && . $ABCD_CCA_REPLICATION/pipeline.config && dual_regression && export FSL_MEM=32 && dual_regression $GICA/melodic_IC 1 -1 0 $DR `cat $FINAL_SUBJECTS`"


echo "STEP 6: slices_summary"
echo "Run slices_summary as follows:"
echo "  ABCD_CCA_REPLICATION="$(dirname "$PWD")" && . $ABCD_CCA_REPLICATION/pipeline.config && slices_summary $GICA/melodic_IC 4 /usr/local/apps/fsl/6.0.1/data/standard/MNI152_T1_2mm $GICA/melodic_IC.sum -1"