% abcd_netmats.m
% Created: 7/28/20 pipeline_version_1.5
% Updated

% Written by Nikhil Goyal, National Institute of Mental Health, 2019-2020

% subs_folder    =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/ica_500_test/'
% gica_path      =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/ica_500_test/groupICA200_50subs.gica/';
% dr_folder_path =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/ica_500_test/grot';

% subs_folder    =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/1000_subjects/'
% gica_path      =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/1000_subjects_masked.gica/';
% dr_folder_path =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/1000_subjects_masked.dr';
% abcd_cca_dir   =  '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/';
% FSLDIR         =  '/usr/local/apps/fsl/6.0.1';
% n_subs_in=500;

% function gen_netmats(gica_path, dr_folder_path, abcd_cca_dir, n_subs_in)
%    if nargin<4
%       sprintf("ERROR, not enough arguments.")
%       sprintf("Example: gen_netmats('/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/1000_subjects_masked.gica/', '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/data_prep/1000_subjects_masked.dr', '/data/ABCD_MBDU/goyaln2/abcd_cca_replication/', 1000)")
%       return
%  end

function abcd_netmats(stage_4_out, gica_path, dr_path, abcd_cca_dir, n_subs_in)
    if nargin<6
        sprintf("ERROR, not enough arguments.")
        sprintf("Example: abcd_netmats()")
        return
	end
	
    if ~isdeployed
        addpath(genpath(sprintf('%s/dependencies/', abcd_cca_dir)));
        addpath(genpath(sprintf('%s/dependencies/FSLNets', abcd_cca_dir)));
        addpath(genpath(sprintf('%s/dependencies/L1precision', abcd_cca_dir)));    % L1precision toolbox
        addpath(genpath(sprintf('%s/dependencies/pwling', abcd_cca_dir)));         % pairwise causality toolbox
        addpath(sprintf('%s/etc/matlab', getenv('FSLDIR')));
        % addpath(sprintf('%s/etc/matlab',FSLDIR));
        addpath(genpath(sprintf('%s/data/', abcd_cca_dir)));

        group_maps  =  sprintf('%s/melodic_IC_path',gica_path);  % spatial maps 4D NIFTI file, e.g. from group-ICA
        ts_dir      =  dr_path;   % dual regression output directory, containing all subjects' timeseries
        n_subs      =  n_subs_in;
    elseif isdeployed
        % When compiled matlab, it reads the command line args all as strings so we need to convert
        n_subs  =   str2num(n_subs_in);
    end

    % Load timeseries data from the dual regression output directory
    % arg2 is the TR (in seconds)
    % arg3 controls variance normalisation: 0=none, 1=normalise whole subject stddev, 2=normalise each separate timeseries from each subject
    ts=nets_load(ts_dir,0.8,1);

    % have a look at mean timeseries spectra
    % ts_spectra=nets_spectra(ts);

    %%% cleanup and remove bad nodes' timeseries (whichever is not listed in ts.DD is *BAD*).

    % bad_components = [198 197 194 190 186 183 181 174 172 169 159 155 154 151 150 148 146 145 143 141 138 128 127 119 107 103 102 101 100 99 96 94 92 91 90 85 77 76 73 64 63 61 56 49 46 10];

    % Get the different elements between 1:200 and bad_components (i.e. generate list of GOOD components)
    % ts.DD = setdiff([1:200], bad_components);

    % ts.DD = [1 2 3 4 5 6 7 8 9 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 31 33 34 35 36 37 38 40 41 42 43 44 45 47 48 51 52 53 54 55 57 59 62 65 66 67 68 69 71 74 75 79 80 83 84 86 87 88 89 93 110 111 112 113 114 115 116 121 122 123 126 129 130 131 132 137 142 147 149 156 166 167 173 184 188 189];

    % ts.DD is the list of GOOD components (we assume all are good for 200-dimension) (counting starts at 1, not 0)
    ts.DD= 1:200;
    % ts.UNK=[10];  optionally setup a list of unknown components (where you're unsure of good vs bad)

    ts=nets_tsclean(ts,1);  % regress the bad nodes out of the good, and then remove the bad nodes' timeseries (1=aggressive, 0=unaggressive (just delete bad)).
                            % For partial-correlation netmats, if you are going to do nets_tsclean, then it *probably* makes sense to:
                            %    a) do the cleanup aggressively,
                            %    b) denote any "unknown" nodes as bad nodes - i.e. list them in ts.DD and not in ts.UNK
                            %    (for discussion on this, see Griffanti NeuroImage 2014.)

    % nets_nodepics(ts,group_maps);           % quick views of the good and bad components
    % ts_spectra=nets_spectra(ts);             % have a look at mean spectra after this cleanup


    %%% create various kinds of network matrices and optionally convert correlations to z-stats.
    %%% here's various examples - you might only generate/use one of these.
    %%% the output has one row per subject; within each row, the net matrix is unwrapped into 1D.
    %%% the r2z transformation estimates an empirical correction for autocorrelation in the data.
    % netmats0=  nets_netmats(ts,0,'cov');        % covariance (with variances on diagonal)
    % netmats0a= nets_netmats(ts,0,'amp');        % amplitudes only - no correlations (just the diagonal)
    % netmats1=  nets_netmats(ts,1,'corr');       % full correlation (normalised covariances)
    % netmats2=  nets_netmats(ts,1,'icov');       % partial correlation
    % netmats3=  nets_netmats(ts,1,'icov',10);    % L1-regularised partial, with lambda=10
    % netmats5=  nets_netmats(ts,1,'ridgep');     % Ridge Regression partial, with rho=0.1
    % netmats11= nets_netmats(ts,0,'pwling');     % Hyvarinen's pairwise causality measure

    % Calculate subject-wise netmats
    netmats1 =  nets_netmats(ts,1,'corr');       % full correlation (normalised covariances)
    netmats5_001 =  nets_netmats(ts,1,'ridgep',0.01);     % Ridge Regression partial, with rho=0.01
    % netmats5_01 =  nets_netmats(ts,1,'ridgep',0.1);     % Ridge Regression partial, with rho=0.1

    %%% view of consistency of netmats across subjects; returns t-test Z values as a network matrix
    %%% second argument (0 or 1) determines whether to display the Z matrix and a consistency scatter plot
    %%% third argument (optional) groups runs together; e.g. setting this to 4 means each group of 4 runs were from the same subject

    [Znet1,Mnet1]  =  nets_groupmean(netmats1,0,1);   % test whichever netmat you're interested in; returns Z values from one-group t-test and group-mean netmat
    [Znet2,Mnet2]  =  nets_groupmean(netmats5_001,0,1);   % test whichever netmat you're interested in; returns Z values from one-group t-test and group-mean netmat

    save(sprintf('%s/%d_fslnets.mat',stage_4_out,n_subs_in))

    %%% view hierarchical clustering of nodes
    %%% arg1 is shown below the diagonal (and drives the clustering/hierarchy); arg2 is shown above diagonal
    % SUMPICS  = sprintf('%s/melodic_IC_sum',gica_path);
    % [hier,linkages] = nets_hierarchy(Znet1, Znet5,ts.DD,SUMPICS);
    % set(gcf,'PaperPositionMode','auto','Position',[1 1 46*(ts.Nnodes+1) 1574 ]);

    % nets_hierarchy(Znet1,Znet5,ts.DD,group_maps);

    % writematrix(netmats5_01, sprintf('%s/raw_netmats_01.txt',subs_folder))
    writematrix(netmats5_001, sprintf('%s/%d_raw_netmats_001.txt',stage_4_out,n_subs_in))



    % UNUSED CODE:
    %%% view interactive netmat web-based display
    % nets_netweb(Znet1,Znet5,ts.DD,group_maps,'netweb');


    %%% cross-subject GLM, with inference in randomise (assuming you already have the GLM design.mat and design.con files).
    %%% arg4 determines whether to view the corrected-p-values, with non-significant entries removed above the diagonal.
    % [p_uncorrected,p_corrected]=nets_glm(netmats1,'design.mat','design.con',1);  % returns matrices of 1-p
    %%% OR - GLM, but with pre-masking that tests only the connections that are strong on average across all subjects.
    %%% change the "8" to a different tstat threshold to make this sparser or less sparse.
    %netmats=netmats3;  [grotH,grotP,grotCI,grotSTATS]=ttest(netmats);  netmats(:,abs(grotSTATS.tstat)<8)=0;
    %[p_uncorrected,p_corrected]=nets_glm(netmats,'design.mat','design.con',1);

    %%% view 6 most significant edges from this GLM
    % nets_edgepics(ts,group_maps,Znet1,reshape(p_corrected(1,:),ts.Nnodes,ts.Nnodes),6);


    %%% simple cross-subject multivariate discriminant analyses, for just two-group cases.
    %%% arg1 is whichever netmats you want to test.
    %%% arg2 is the size of first group of subjects; set to 0 if you have two groups with paired subjects.
    %%% arg3 determines which LDA method to use (help nets_lda to see list of options)
    % [lda_percentages]=nets_lda(netmats3,36,1)


    %%% create boxplots for the two groups for a network-matrix-element of interest (e.g., selected from GLM output)
    %%% arg3 = matrix row number,    i.e. the first  component of interest (from the DD list)
    %%% arg4 = matrix column number, i.e. the second component of interest (from the DD list)
    %%% arg5 = size of the first group (set to -1 for paired groups)
    % nets_boxplots(ts,netmats3,1,7,36);
    %print('-depsc',sprintf('boxplot-%d-%d.eps',IC1,IC2));  % example syntax for printing to file

end
