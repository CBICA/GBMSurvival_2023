#!/usr/bin/env bash

################################## START OF EMBEDDED SGE COMMANDS ##########################
######## Common options ########
#$ -S /bin/bash  #### Default Shell to be Used
#$ -cwd  #### Run in current directory
#$ -N GBMSurvival22  #### Job Name to be listed in qstat
#$ -j y #### merge stdout and stderr to a single file at -o path
#$ -l h_vmem=4G #### How much memory total the job can use. Defaults to 4GB ( qconf -sc | grep h_vmem ) 
#$ -l tmpfree=12G #### How much scratch space the job can use. Defaults to 0GB if not specified by user
############################## END OF DEFAULT EMBEDDED SGE COMMANDS #######################

echoV()
{
    #echo only IF VERBOSE flag is on
    if [ ${VERBOSE} -eq 1 ];
    then
        echo -e $1;
    fi;
}


function Help {
    cat <<EOF

Input:
 (1) registered skull-stripped images and tumor segm

Steps:
 (1) Deformably registser to Jacob atlas. 
          Check of negative intensity. Since greedy deform will fail if intensity<0, shift intensify if negative. (only for getting deformation)
          Feature extration will use
          - TC segm in atlas
          - VT label in SRI

 (2) Extract features
          - check features with respond distribution. print out in table. If outlier, flag and say results may not be reliable.

 (3) Apply respond model

 (4) Print out results to pdf


Options for local debugging purposes
  -p     Don't remove tmpdir (to save intermediate results)
  -S     scriptdir (location of script. Default is /cbica/home/IPP/GBMSurvival22/bin)
  -V     VERBOSE mode on
  -h     Show help

EOF
}



### Default parameters
VERBOSE=0;
keep_tmpdir=0;
brainsizeth=950000;
tcsizeth=40
flag_noTC=0
age=;

### folder for subscripts
#scriptdir=/cbica/projects/brain_tumor_external/IPP_symlink/GBMSurvival22/bin
scriptdir=./

##############################################################################
# user input
##############################################################################

while getopts hn:T:a:t:w:c:f:o:q:m:s:b:d:pS:V option
do
    case "${option}"
    in

        h) Help;    #show help documentation
           exit 0;;

	#### Mandatory

	# experimentName
	n) experimentName=${OPTARG};; 
	
	# age!
	a)  age=${OPTARG};;
	
	# images
	t)  t1=${OPTARG};;  #nii.gz
	w)  t2=${OPTARG};;  #nii.gz
	c)  t1ce=${OPTARG};;        #nii.gz
	f)  flair=${OPTARG};;       #nii.gz
	s)  seg=${OPTARG};       #nii.gz
	    user_seg=1;;

	# output folder -- this is the output folder that gets zipped up. need to provide user dir when testing outside ipp.
	o)  ippoutdir=${OPTARG};;   

	#### Optional
	
	# for testing and debugging outside of IPP
	p)  keep_tmpdir=1;;

	S)  scriptdir=${OPTARG};; # where the scripts are, for local testing.
	
	V)  VERBOSE=1;
	    echo "VERBOSE mode on";;

        ?)  echo "Unrecognized Options. Exiting. " 1>&2;
            Help;
            exit 1;
            ;;	 

    esac
done



##############################################################################
# Initial checks
##############################################################################


echo -e "\n---> Initial checks"

check_sri()
{
    f="$1"
    dim=`fslinfo $f | grep ^dim | awk '{print $2}'`
    dim=`echo $dim`
    if [[ "${dim}" != "240 240 155 1" ]]; then
        echo -e "\nError:"
	echo -e "Input file ($f) must be registered to the SRI atlas."
        echo -e "Exiting."
        exit 1
    fi
}

exit_if_blank()
{
    argument_value="$1";
    argument_name="$2";
    if [ -z "${argument_value}" ];
    then
        echo -e "\nparameter argument (${argument_name}) was not provided. Exiting.";
        exit 1;
    fi;
}

exit_if_not_exist()
{
    file="$1";
    if [ ! -e "${file}" ]; then
        echo -e "\nfile (${file}) does not exist. Exiting.";
        exit 1;
    fi;
}
exit_if_not_exist_dir()
{
    dir="$1";
    if [ ! -d "$dir" ]; then
        echo -e "\nfolder (${dir}) does not exist. Exiting.";
        exit 1;
    fi;
}

copy_to_ippoutdir()
{
    fin="$1"
    fout="$2"
    dir=`dirname $ippoutdir/$fout`
    fname=`basename $fout`
    mkdir -p $dir
    if [ ! -f $dir/$fname ]; then
	cp $fin $dir/$fname
	checkandexit $? "Couldn't copy `basename $fin` to ippoutdir"
    fi
    
}


# mandatory input
exit_if_blank "$age" "age"
exit_if_blank "$t1" "t1"
exit_if_blank "$t1ce" "t1ce"
exit_if_blank "$t2" "t2"
exit_if_blank "$flair" "flair"
exit_if_blank "$seg" "seg"
exit_if_blank "$ippoutdir" "ippoutdir"

for f in $t1 $t2 $t1ce $flair $seg; do
    exit_if_not_exist $f
done
exit_if_not_exist_dir $ippoutdir

check_sri $t1
check_sri $t1ce
check_sri $t2
check_sri $flair
check_sri $seg


echo -e "\nFinished checks."

## print user input:
echo -e "\n---> User input"

echo -e "user description:\t($experimentName)";
echo -e "age:\t(${age})";
echo -e "t1:\t(`basename ${t1}`)";
echo -e "t1ce:\t(`basename ${t1ce}`)";
echo -e "t2:\t(`basename ${t2}`)";
echo -e "flair:\t(`basename ${flair}`)";
echo -e "user tumor segm:\t(`basename ${seg}`)";

echoV "user tmpdir:\t(${tmpdir})";
echoV "ippoutdir:\t(${ippoutdir})";
echoV "scriptdir:\t($scriptdir)"


### paths
atlas=$scriptdir/data/jakob_atlas/jakob_stripped_with_cere_lps_256256128.nii.gz
atlassegm=$scriptdir/data/jakob_atlas/templateallregions.nii.gz
atlasstaging=$scriptdir/data/model/Atlas_Sur_NatMed.nii.gz
modelmat=$scriptdir/data/model/Trained_ReSPOND_NatMedRev1.mat

pythonexec=$scriptdir/libs/python38_gbmsurvival22/bin/python

###############################################################
# set tmpdir inside ippoutdir
###############################################################

echoV "\nSetup tmpdir"
tmpdir=$ippoutdir/tmpdir
mkdir -p $tmpdir
checkandexit $? "Creation of Temporary Directory Failed"
echoV "tmpdir:$tmpdir"


###############################################################
# check segm TC size (need to be > 40)
###############################################################

echo -e "\n---> Check on TC size."
volnc=`fslstats $seg -l 0.5 -u 1.5 -V | awk '{print $1}'`
volet=`fslstats $seg -l 3.5 -u 4.5 -V | awk '{print $1}'`
voltc=$((volnc+volet))
echo -e "\nTC size:$voltc"
if (( $voltc < $tcsizeth )); then
    echo -e "\nTumor Core size is too small to extract features."
    echo -e "Because our model uses features related to the Tumor Core, we cannot run our model on this subject."
    echo -e "Please check segmentation snapshots in our report as well."
    flag_noTC=1;
fi


#############################
# Register to Jacob atlas
#############################

if (( flag_noTC == 0 )); then
    echo -e "\n---> Deformable Registration to Common atlas"
    outdir=$tmpdir/deform
    logdir=$outdir/logs
    mkdir -p $outdir
    checkandexit $? "Creation of deform output dir failed"
    mkdir -p $logdir
    checkandexit $? "Creation of deform log dir failed"

    t=sub 

    ## check that t1 intensity is all positive. Shift if so.
    echo -e  "\nchecking t1 intensity range"
    t1range=`fslstats $t1 -R`
    echo -e "$t1range"
    if [ -z "$(echo $t1range | awk '$1<0')" ]; then
	echoV "all positive values. continuing."
	t1use=$t1
    else
	#shift
	echo -e "shifting intensity to positive values (temporary step for deform registration only)"
	t1use=$outdir/${t}_t1_shifted.nii.gz
	t1min=`echo $t1range | awk '{print $1}'`
	if [ -z "$mask" ]; then
	    tmpmask=$outdir/tmpmask.nii.gz
	    3dcalc -a $t1 -expr 'notzero(a)' -prefix $tmpmask
	else
	    tmpmask=$mask
	fi
	echoV "$link3dcalc -a $t1 -b $tmpmask -expr 'b*(a-('${t1min}'))' -prefix $t1use"
	3dcalc -a $t1 -b $tmpmask -expr 'b*(a-('${t1min}'))' -prefix $t1use
	if [ ! -f $t1use ]; then
	    echo -e "\nshifting intensity failed. Exiting."
	    remove_tmpdir;
	    exit 1;
	fi
	
    fi	
    
    fmat=$outdir/${t}_t1_20toAtlas.mat
    fdeform=$outdir/${t}_t1_20toAtlas_deformfield.nii.gz
    ft1_out=$outdir/${t}_t1_rdAtlas.nii.gz
    ft1ce_out=$outdir/${t}_t1ce_rdAtlas.nii.gz
    fdeforminv=$outdir/${t}_t1_20toAtlas_deformfield_inv.nii.gz

    fseg_out=$outdir/${t}_segm_rdAtlas.nii.gz 
    fseg_outtc=$outdir/${t}_segm_rdAtlas_TC.nii.gz ### TumorRA
    atlassegm_out=$outdir/${t}_atlassegm_rSRI.nii.gz
    atlasVT_out=$outdir/${t}_atlasVT_rSRI.nii.gz  ### Vent_SRI
    Mod=$t1ce

    #todo, remove the holds because no longer needed
    hold_deform1=;
    hold_deform2=;
    echo -e "\nget .mat and deformation field"
    if [[ ! -f $fmat || ! -f $fdeform ]]; then
	logfile=$logdir/greedy_rAtlas_register.log
	cmd="qsub ${qsubenvoption} -terse -j y -o $logfile \
            $greedyscript \
            -i $t1use \
            -r $atlas \
            -m $fmat \
            -d $fdeform \
            -o $ft1_out \
            -V"
	echoV "\n$cmd"
	jid=$($cmd)
	hold_deform1="-hold_jid $jid"
	echoV "jid: $jid"
	while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
	if [[ ! -f $fmat || ! -f $fdeform  ]]; then
	    echo -e "\nGreedy deform to common atlas failed. Exiting."
	    copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
	    remove_tmpdir;	
	    exit 1;
	fi
    fi

    echo -e "\nmove seg to atlas"
    if [ ! -f $fseg_out ]; then
	logfile=$logdir/greedy_rAtlas_moveseg.log
	cmd="qsub ${qsubenvoption} $hold_deform1 -terse -j y -o $logfile \
            $greedyscript \
                 -a \
                 -i $seg \
                 -r $atlas \
                 -m $fmat \
                 -d $fdeform \
                 -o $fseg_out \
                 -p NN \
                 -V"
	echoV "\n$cmd"
	jid=$($cmd)
	hold_deform2="$hold_deform1 -hold_jid $jid"
	echoV "jid: $jid"
	while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
	if [ ! -f $fseg_out ]; then
	    echo -e "\nGreedy deform, moving segm to common atlas failed. Exiting."
	    copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
	    remove_tmpdir;	
	    exit 1;
	fi
    fi

    echo -e "\nget tumor core from seg in atlas"
    if [ ! -f $fseg_outtc ]; then
	logfile=$logdir/tc_3dcalc.log 
	cmd="qsub  $hold_deform2 -terse -j y -b y -o $logfile \
               $link3dcalc -a $fseg_out -expr 'iszero(a-1)+iszero(a-4)' -prefix $fseg_outtc"
	echoV "\n$cmd"
	jid=$($cmd)
	hold_deform2="$hold_deform2 -hold_jid $jid"
	echoV "jid: $jid"
	while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
	if [ ! -f $fseg_outtc ]; then
	    echo -e "\nGreedy deform step, 3dcalc to get TC segm failed. Exiting."
	    copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
	    remove_tmpdir;	
	    exit 1;
	fi
    fi
    echo ""


    echo -e "\nmove atlas segm to patient space (in SRI)" 
    if [[ ! -f $atlassegm_out ]]; then
	logfile=$logdir/greedy_deform_move_atlassegm_to_SRI.log
	cmd="qsub ${qsubenvoption} $hold_deform1 -terse -j y -o $logfile \
               $greedyscript \
                 -a -b \
                 -i $atlassegm \
                 -r $t1 \
                 -m $fmat,-1 \
                 -d $fdeforminv \
                 -o $atlassegm_out \
                 -p NN \
                 -V"

	echoV "\n$cmd"
	jid=$($cmd)
	hold_deform1="$hold_deform1 -hold_jid $jid"
	echoV "jid: $jid"
	while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
	if [ ! -f $atlassegm_out ]; then
	    echo -e "\nGreedy deform step, 3dcalc to get TC segm failed. Exiting."
	    copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
	    remove_tmpdir;	
	    exit 1;
	fi

    fi

    echo -e "get VT segm (from atlas) in patient space (in SRI)"    
    if [ ! -f $atlasVT_out ]; then
	logfile=$outdir/vt_3dcalc.log
	cmd="qsub $hold_deform1 -terse -l h_vmem=4G -b y -j y -o $logfile \
                $link3dcalc \
                -a $atlassegm_out -expr 'iszero(a-3)+iszero(a-8)' \
                -prefix $atlasVT_out"
	echoV "\n$cmd"
	jid=$($cmd)
	hold_deform1="$hold_deform1 -hold_jid $jid"
	echoV "jid: $jid"
	while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
	if [ ! -f $atlasVT_out ]; then
	    echo -e "\nGreedy deform step, 3dcalc to get VT segm failed. Exiting."
	    copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
	    remove_tmpdir;	
	    exit 1;
	fi
    fi

    echo ""

    echo -e "\nFinished deformation to common atlas\n"

    echoV "\n---> Input to feature extraction"
    echoV "Tumor Core in Jacob atlas: $fseg_outtc"
    echoV "Segm in SRI: $seg"
    echoV "Atlas VT segm in SRI: $atlasVT_out"
    echoV "t1ce: $t1ce"


    ########################################
    # Feature extraction and apply model
    ##################################

    echo -e "\n---> Feature Extraction and Prediction"
    outdir=$tmpdir/ML
    mkdir -p $outdir
    checkandexit $? "Creation of FE/ML output dir failed"

    fout=$outdir/results.csv
    if [ ! -f $fout ]; then
	logfile=$outdir/ml.log
	cmd="qsub $hold_deform1 -terse -l h_vmem=12G -j y -o $logfile \
   	  $scriptdir/run_matlabexec_2018a.sh $scriptdir/ML/GBMSurvival_predict \
	  $age \
	  $fseg_outtc \
	  $seg \
	  $atlasVT_out \
	  $t1ce \
	  $atlasstaging \
	  $outdir \
	  $modelmat"
	echoV "\n$cmd"
	jid=$($cmd)
	echoV "jid: $jid"
	while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
    fi
    if [ ! -f $fout ]; then
	echo -e "\nFeature Extraction/ML failed"
	copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
	remove_tmpdir;
	exit 1;
    fi

    copy_to_ippoutdir "$outdir/features.csv" "ML/features.csv"
    cut -d, -f1-2 $outdir/results.csv > $ippoutdir/ML/results.csv 

fi

#############################
# Write report
#############################

echo -e "\n---> Output report"

outdir=$tmpdir/Report
mkdir -p $outdir
checkandexit $? "Creation of Report output dir failed"

if (( user_brainmask == 0 && inputtype == 2 )); then
    maskoption=""
else
    t1=$ippoutdir/images/T1/T1_to_SRI.nii.gz
    t1ce=$ippoutdir/images/T1CE/T1CE_to_SRI.nii.gz
    t2=$ippoutdir/images/T2/T2_to_SRI.nii.gz
    flair=$ippoutdir/images/FL/FL_to_SRI.nii.gz
    maskoption="-m $mask"
fi

if (( user_seg == 1 )); then
    segtype="0"  #user
elif (( use_deepmedic == 1 )); then
    segtype="1"  #DM
else
    segtype="2"  #FeTS
fi


if (( flag_noTC == 0 )); then
    reportoption="-a 0 -e $ippoutdir/ML/features.csv -r $ippoutdir/ML/results.csv --tcinatlas $fseg_outtc"
else
    reportoption="-a 1"
fi

fout=$outdir/report.pdf
if [ ! -f $fout ]; then
    logfile=$outdir/report.log
    cmd="qsub -terse -j y -o $logfile -b y -l h_vmem=8G\
            $pythonexec $scriptdir/GBMsurvival_report.py \
            -n '$experimentName' \
	    -t $t1 \
            -c $t1ce \
    	    -w $t2 \
    	    -f $flair \
	    $maskoption \
	    -s $seg \
            --segtype $segtype \
	    $reportoption \
            --modeldir $scriptdir/data/model \
	    -o $outdir"
    echoV "\n$cmd"
    jid=$($cmd)
    echoV "jid: $jid"
    while [ -n "`qstat | grep $jid`" ]; do sleep 2m; done
fi
if [ ! -f $fout ]; then
    echo -e "\nWriting report failed"
    copy_to_ippoutdir $logfile "Logs/`basename $logfile`"
    remove_tmpdir;
    exit 1;
fi

copy_to_ippoutdir "$outdir/report.pdf" "report.pdf"
remove_tmpdir;
echo -e "\nFinished."

