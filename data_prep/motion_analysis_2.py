# Written by Nikhil Goyal, National Institute of Mental Health, 2019-2020
# This script takes the motion summary (generated by fd_analysis.py) and:
#   1. Filters out bad subjects
#   2. Plots a histogram of ABCD (motion/outlier filtered) vs HCP500 data
#   3. Generates a lists of filtered subjects

import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats
from matplotlib import colors
from matplotlib.ticker import PercentFormatter
import os
import datetime

def find_anomalies(random_data):
    # Function to Detection Outlier on one-dimentional datasets.
    # cut off the top and bottom 0.25% of subjects (as recommended in the ABCD 2.0.1 documentation)
    anomalies=[]
    cutoff = 2.80703    # z score corresponds to top and bottom 0.25% of data
    # Set upper and lower limit to 3 standard deviation
    random_data_std = np.std(random_data)
    random_data_mean = np.mean(random_data)
    anomaly_cut_off = random_data_std * cutoff
    
    lower_limit  = random_data_mean - anomaly_cut_off 
    upper_limit = random_data_mean + anomaly_cut_off
    # print(lower_limit)

    # Generate list of outliers
    for outlier in random_data:
        if outlier > upper_limit or outlier < lower_limit:
            anomalies.append(outlier)
    return anomalies

def plot_hist(l1,l2,titlestr):
    bins=50
    fig, ax = plt.subplots()

    # Call the sns.set() function 
    sns.set()
    sns.distplot(l1,bins=bins,norm_hist=True,label='hcp',fit=stats.gamma,kde=False,color=sns.xkcd_rgb["pale red"])
    sns.distplot(l2,bins=bins,norm_hist=True,label='abcd',fit=stats.gamma,kde=False,color=sns.xkcd_rgb["denim blue"])

    # plt.axvline(np.median(hcp), linestyle='--',color=sns.xkcd_rgb["pale red"])
    # plt.axvline(np.median(abcd), linestyle='--',color=sns.xkcd_rgb["denim blue"])

    plt.legend(loc='upper right', bbox_to_anchor=(0.95, 0.99),fontsize=12)

    ax.set_xlabel('Frame displacement (mm)')
    ax.set_ylabel('Probability density')
    ax.set_title(titlestr)

    textstr1 = '\n'.join((
        r'$n=%d$' % (len(l1), ),
        r'$\mu=%.4f$' % (np.mean(l1), ),
        r'$\mathrm{median}=%.4f$' % (np.median(l1), ),
        r'$\sigma=%.4f$' % (np.std(l1), )))

    textstr2 = '\n'.join((
        r'$n=%d$' % (len(l2), ),
        r'$\mu=%.4f$' % (np.mean(l2), ),
        r'$\mathrm{median}=%.4f$' % (np.median(l2), ),
        r'$\sigma=%.4f$' % (np.std(l2), )))

    props1 = dict(boxstyle='round', facecolor=sns.xkcd_rgb["pale red"], alpha=0.5)
    props2 = dict(boxstyle='round', facecolor=sns.xkcd_rgb["denim blue"], alpha=0.5)

    # place a text box in upper left in axes coords
    ax.text(0.95, 0.7, textstr1, transform=ax.transAxes, fontsize=10,
            verticalalignment='top', horizontalalignment='right', bbox=props1)
    # place a text box in upper left in axes coords
    ax.text(0.95, 0.4, textstr2, transform=ax.transAxes, fontsize=10,
            verticalalignment='top', horizontalalignment='right', bbox=props2)

    # Tweak spacing to prevent clipping of ylabel
    fig.tight_layout()
    plt.show()
    fig.savefig(os.path.join(cwd,'data/hcp_abcd_FD_histogram.png'),dpi=600)

##################################################################################
#   PART 1 - Load data, drop NaNs, and do prelim comparison of FD distributions. #
##################################################################################
cwd = os.getcwd()
fp = os.path.join(cwd,'data/HCP500_rfMRI_motion.txt')
hcp=np.loadtxt(fp)
fp = os.path.join(cwd,'data/mean_FDs.txt')
abcd=np.loadtxt(fp)

# Logging file
fp = os.path.join(cwd,'log.txt')
f_log = open(fp, 'a')
f_log.write("--- RESULTS OF motion_analysis_2.py ---\n")
f_log.write('%s\n' % datetime.datetime.now())

# print("# subjects before dropping NaNs:{}\n".format(len(abcd)))
# for ABCD, if nan (meaning they had no remaining timepoints, so drop them)
# abcd = abcd[~np.isnan(abcd)]
# print("# subjects AFTER dropping NaNs:{}\n".format(len(abcd)))

# plot_hist(hcp,abcd,'Histogram of FD, HCP & ABCD (all subjects available)')
# stats.ks_2samp(hcp, abcd)
# The above statistical test concludes that the distributions ARE DIFFERENT --> we cannot use all subjects from each.
# The above distribution was drawn with ALL ABCD subjects with available timeseries, regardless of how much "good" scan time they have. We will be using >10min scan time as the cutoff.


#############################################################
#   PART 2 - Find how many subjects have >=10min scan time. #
#############################################################
# Lets find out how many subjects have >10min scan time.
fp = os.path.join(cwd,'data/motion_summary_data.csv')

# note that msd means 'motion_summary_data'
msd = pd.read_csv(fp, sep=',')

f_log.write("Initial number of subjects under consideration:\t{}\n".format(msd.shape[0]))

# Drop any subjects with nan in their remainig_frame_mean_FD
msd['remaining_frame_mean_FD'] = pd.to_numeric(msd['remaining_frame_mean_FD'], errors='coerce')
msd=msd[~np.isnan(msd['remaining_frame_mean_FD'])]
# msd=msd[~pd.isnull(msd['remaining_frame_mean_FD'])]
# msd.dropna(axis=0,subset=['remaining_frame_mean_FD'],inplace=True)
f_log.write("Number number of subjects after dropping those missing remaining_frame_mean_FD value:\t{}\n".format(msd.shape[0]))

# print(len(msd[msd['remaining_seconds'].ge(600)]))
# print(len(msd['sub']))
# print(len(msd[(msd['remaining_seconds'].ge(600))])/len(msd['sub']))

# Now, lets recreate the histograms for analysis
# msd_rt_filt means "motion_summary_data_remainingtime_filtered" 
msd_rt_filt=msd[(msd['remaining_seconds'].astype('int')>=600)]
abcd = msd_rt_filt['remaining_frame_mean_FD'].tolist()

f_log.write("Number of subjects with >600seconds good scan time:\t{}\n".format(len(abcd)))

# plot_hist(hcp,abcd,'Histogram of FD, HCP & ABCD (>10min filtered)')
# stats.ks_2samp(hcp, abcd)

############################################################################################################################
#   PART 3 - Outlier detection and removal (top and bottom 0.25%), and filter with MRI QC metrics from ABCD 2.0.1 release  #
############################################################################################################################
# Visualize outliers
# sns.boxplot(x=abcd)

# Finally, lets remove the outliers seen in the boxplot
anoms=find_anomalies(abcd)
msd_rt_anom_filt = msd_rt_filt[~msd_rt_filt['remaining_frame_mean_FD'].isin(anoms)]
abcd=msd_rt_anom_filt['remaining_frame_mean_FD'].tolist()

f_log.write("Number of subjects after anomalies removed:\t{}\n".format(len(abcd)))

# Now, let's plot the distribution without these outliers:
# plot_hist(hcp,abcd,'Histogram of FD, HCP vs. ABCD (>10min & outliers removed')
# stats.ks_2samp(hcp, abcd)

# Now that we've removed subjects based on amount of "good" scan time & removed outliers, let's pull the mri QC metrics from the 2.0.1 release file (mriqcrp102.txt)
# This can be obtained via the shared package 144683 on NDA, ABCDFixRelease
# please note that the END USER MUST PLACE THE mriqcrp102.txt into data_prep/data/ MANUALLY!
fp = os.path.join(cwd,'data/mriqcrp102.txt')
mriqc = pd.read_csv(fp,sep='\t')

# drop the first row (its a bunch of strings we dont need)
mriqc=mriqc.drop(mriqc.index[0])

# Now, we need to change the format of the subject key by removing the underscore (ex. NDAR_INVX8CRJYVP	 --> NDARINVX8CRJYVP)
mriqc['subjectkey'] = mriqc['subjectkey'].str.replace('_','')

qc = mriqc[['subjectkey','iqc_t1_ok_ser','iqc_t1_good_ser','iqc_rsfmri_ok_ser','iqc_rsfmri_good_ser']]
subs = msd_rt_anom_filt['sub'].tolist()
qc=qc[qc['subjectkey'].isin(subs)]

# We will exclude the subjects whose data is missing from the qc file (they have NaN is any one of the fields in dataframe 'qc')
# Now drop any rows with NaNs
qc.dropna(inplace=True)
qc.shape
# qc.isna()
# qc[(qc['iqc_t1_ok_ser'].isnull() | qc['iqc_rsfmri_ok_ser'].isnull())].index.tolist()


# Final processing step, apply these inclusion criteria
# 1. iqc_t1_good_ser > 0
# 2. iqc_rsfmri_good_ser >= 2 (for 10 mins)

# Make sure the data are numeric
numeric = ['iqc_t1_ok_ser','iqc_t1_good_ser','iqc_rsfmri_ok_ser','iqc_rsfmri_good_ser']
qc[numeric] = qc[numeric].apply(pd.to_numeric, errors='coerce')

# qc2 is a less strict drop criteria (ignoring protocol compliance check for the t1 and rsfMRI scans)
# qc3 is stricter (requires protocol compliance for both t1 and rsfMRI scans)
# Doesn't make big difference in num of subjects, so we use qc3
qc2 = qc.drop(qc[ ~( (qc['iqc_t1_ok_ser'] > 0) & (qc['iqc_rsfmri_ok_ser'] > 1) ) ].index)
qc3 = qc.drop(qc[ ~( (qc['iqc_t1_good_ser'] > 0) & (qc['iqc_rsfmri_good_ser'] > 1) ) ].index)

# print("qc2 shape {}".format(qc2.shape))
print("qc3 shape {}".format(qc3.shape))
print("Final number of subjects:\t{}\n".format(qc3.shape[0]))

# Now create final dataframe (which has undergone: removal of subjects with missing data, removal of subjects with <10min, removal of outliers, and application of 2 filtering criteria)
final_subs = qc3['subjectkey'].tolist()
msd_final = msd_rt_anom_filt[msd_rt_anom_filt['sub'].isin(final_subs)]
abcd=msd_final['remaining_frame_mean_FD'].tolist()

f_log.write("Number of subjects after QC drop\t{}\n\n".format(len(abcd)))

# Let's make one final plot of the histograms
plot_hist(hcp,abcd,'Histogram of FD, HCP vs. ABCD (Filtered subset)')

# Output a final list of subjects to be included in the group-ICA
# Write it to two folders: the abcd_cca_replication/motion/data/, and abcd_cca_replication/data/
f1=open('data/motion_filtered_subjects.txt','w')
f2=open('data/motion_filtered_subjects_R.txt','w')

for ele in final_subs:
    ele2 = "NDAR_" + ele.split("NDAR")[1]
    f1.write(ele+'\n')
    f2.write(ele2+'\n')

f1.close()
f2.close()
f_log.close()
