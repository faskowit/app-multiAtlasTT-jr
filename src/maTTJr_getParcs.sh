#!/bin/bash

<<'COMMENT'
josh faskowitz
Indiana University
Computational Cognitive Neurosciene Lab

Copyright (c) 2018 Josh Faskowitz
See LICENSE file for license
COMMENT

####################################################################
####################################################################

help_usage() 
{
cat <<helpusagetext

USAGE: ${0} 
        -d          inputFSDir --> input freesurfer directory
        -o          outputDir ---> output directory, will also write temporary 
        -f          fsVersion ---> freeSurfer version (5p3 or 6p0)
helpusagetext
}

usage() 
{
cat <<usagetext

USAGE: ${0} 
        -d          inputFSDir 
        -o          outputDir
        -f          fsVersion (5p3 or 6p0)
usagetext
}

####################################################################
####################################################################
# define main function here, and then call it at the end

main() 
{

start=`date +%s`

####################################################################
####################################################################

# Check the number of arguments. If none are passed, print help and exit.
NUMARGS=$#
if [ $NUMARGS -lt 3 ]; then
	echo "Not enough args"
	usage &>2 
	exit 1
fi

# read in args
while getopts "a:b:c:d:e:f:g:hi:j:k:l:m:n:o:p:q:s:r:t:u:v:w:x:y:z:" OPTION
do
     case $OPTION in
		d)
			inputFSDir=$OPTARG
			;;
		o)
			outputDir=$OPTARG
            ;;  
        f)
            fsVersion=$OPTARG
            ;;
		h) 
			help_usage >&2
            exit 1
      		;;
		?) # getopts issues an error message
			usage >&2
            exit 1
      		;;
     esac
done

shift "$((OPTIND-1))" # Shift off the options and optional

####################################################################
####################################################################
# check user inputs

# if these two variables are empty, return
if [[ -z ${inputFSDir} ]] || [[ -z ${outputDir} ]]
then
    echo "minimun arguments -d and -o not provided"
	usage >&2
    exit 1
fi

# make full path, add forward slash too
inputFSDir=$(readlink -f ${inputFSDir})/
outputDir=${outputDir}/

# check existence of FS directory
if [[ ! -d ${inputFSDir} ]]
then 
    echo "input FS directory does not exist. exiting"
    exit 1
fi

# add check for fsVersion
if [[ ${fsVersion} != '5p3' ]] && \
    [[ ${fsVersion} != '6p0' ]] 
then
    echo "fsVersion must be set and must be either:"
    echo "5p3 or 6p0"
    exit 1
fi

# check if we can make output dir
mkdir -p ${outputDir}/ || \
    { echo "could not make output dir; exiting" ; exit 1 ; } 

####################################################################
####################################################################

# setup note-taking
OUT=${outputDir}/notes.txt
touch $OUT

# also make this a full path
outputDir=$(readlink -f ${outputDir})/

# set subj variable to fs dir name, as is freesurfer custom
subj=$(basename $inputFSDir)

if [[ -z ${atlasBaseDir} ]]
then
    echo "atlasBaseDir is unset"
    atlasBaseDir=${PWD}/atlas_data/    
    if [[ ! -d ${atlasBaseDir} ]]
    then
        echo "cannot find the atlas_data; please set and retry"
        exit 1
    fi
    echo "will assume this is the right dir: ${atlasBaseDir}"
fi

# if this variable is empty, set it
if [[ -z ${atlasList} ]]
then
    # all the available atlases
    atlasList="fsDK fsDest"
else
    echo "using the atlasList exported to this script"
fi

# check the other scripts too
if [[ -z ${scriptBaseDir} ]] 
then
    scriptBaseDir=${PWD}/
fi

other_scripts="/src/maTT_remap.py /src/maTT_funcs.sh"
for script in ${other_scripts}
do

    if [[ ! -e ${scriptBaseDir}/${script} ]]
    then
        echo "need ${script} for this to work; cannot find"
        exit 1
    fi
done

####################################################################
####################################################################

mkdir -p ${outputDir}/tmpFsDir/${subj}/
tempFSSubj=${outputDir}/tmpFsDir/${subj}/

# copy minimally to speed up
mkdir -p ${tempFSSubj}/mri/

# mri
cp -asv ${inputFSDir}/mri/aparc+aseg.mgz ${tempFSSubj}/mri/
cp -asv ${inputFSDir}/mri/aparc.a2009s+aseg.mgz ${tempFSSubj}/mri/
cp -asv ${inputFSDir}/mri/rawavg.mgz ${tempFSSubj}/mri/

# reset SUJECTS_DIR to the new inputFSDir
export SUBJECTS_DIR=${outputDir}/tmpFsDir/

####################################################################
####################################################################

# run it
for atlas in ${atlasList}
do
 
    mkdir -p ${outputDir}/${atlas}/

    if [[ ${atlas} == "fsDK" ]] 
    then
        atlasVol=${tempFSSubj}/mri/aparc+aseg.mgz
        cp ${scriptBaseDir}/luts/LUT_fsDK.txt ${outputDir}/${atlas}/
    elif [[ ${atlas} == "fsDest" ]]; 
    then
        atlasVol=${tempFSSubj}/mri/aparc.a2009s+aseg.mgz
        cp ${scriptBaseDir}/luts/LUT_fsDest.txt ${outputDir}/${atlas}/
    else
        echo "atlas choice $atlas not supported. exiting"
        exit 1
    fi

    # convert out of freesurfer space
    cmd="${FREESURFER_HOME}/bin/mri_label2vol \
		    --seg ${atlasVol} \
		    --temp ${tempFSSubj}/mri/rawavg.mgz \
		    --o ${outputDir}/${atlas}/${atlas}.nii.gz \
		    --regheader ${outputDir}/${atlas}/${atlas}.mgz \
		    "
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

done # for atlas in atlasList

####################################################################
####################################################################

subjAparcAseg=${tempFSSubj}/mri/aparc+aseg.mgz

if [[ ! -e ${subjAparcAseg} ]]
then
    echo "problem. could not read subjAparcAseg: ${subjAparcAseg}"
    exit 1
else
    
    # convert out of freesurfer space
    cmd="${FREESURFER_HOME}/bin/mri_label2vol \
            --seg ${subjAparcAseg} \
            --temp ${tempFSSubj}/mri/rawavg.mgz \
            --o ${outputDir}/subj_aparc+aseg.nii.gz \
            --regheader ${subjAparcAseg} \
            "
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    subjAparcAseg=${outputDir}/subj_aparc+aseg.nii.gz
fi

####################################################################
####################################################################
# get gm ribbom if does not exits

if [[ ! -e ${outputDir}/${subj}_cortical_mask.nii.gz ]]
then

    # let's get a lh and rh, get largest component of each
    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${subjAparcAseg} \
            --min 1000 --max 1999 --binval 1 \
            --o ${outputDir}/lh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command
    cmd="${FREESURFER_HOME}/bin/mri_extract_largest_CC \
            -T 1 \
            ${outputDir}/lh.tmp_cort_mask.nii.gz \
            ${outputDir}/lh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${subjAparcAseg} \
            --min 2000 --max 2999 --binval 1 \
            --o ${outputDir}/rh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command
    cmd="${FREESURFER_HOME}/bin/mri_extract_largest_CC \
            -T 1 \
            ${outputDir}/rh.tmp_cort_mask.nii.gz \
            ${outputDir}/rh.tmp_cort_mask.nii.gz \
        "     
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    # write out the combined cortical_mask
    cmd="${FREESURFER_HOME}/bin/mris_calc \
            -o ${outputDir}/${subj}_cortical_mask.nii.gz \
            ${outputDir}/lh.tmp_cort_mask.nii.gz \
            add ${outputDir}/rh.tmp_cort_mask.nii.gz \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # remove the tmp
    ls ${outputDir}/?h.tmp_cort_mask.nii.gz && rm ${outputDir}/?h.tmp_cort_mask.nii.gz

fi

####################################################################
####################################################################
# get subcort if does not exist

if [[ ! -e ${outputDir}/${subj}_subcort_mask.nii.gz ]]
then

    # function inputs:
    #   aparc+aseg
    #   out directory
    #   subj variable, to name output files

    # function output files:
    #   ${subj}_subcort_mask.nii.gz
    #   ${subj}_subcort_mask_binv.nii.gz

    get_subcort_frm_aparcAseg \
        ${subjAparcAseg} \
        ${outputDir} \
        ${subj} 

fi

get_mask_frm_aparcAseg \
    ${subjAparcAseg} \
    ${outputDir} \
    ${subj}

####################################################################
####################################################################
# loop through atlasList again to get rid of extra areas and to add 
# subcortical areas

for atlas in ${atlasList}
do

    atlasOutputDir=${outputDir}/${atlas}/

    # extract only the cortex, based on the LUT table
    minVal=$(cat ${atlasOutputDir}/LUT_${atlas}.txt | awk '{print int($1)}' | head -n1)
    maxVal=$(cat ${atlasOutputDir}/LUT_${atlas}.txt | awk '{print int($1)}' | tail -n1)

    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${atlasOutputDir}/${atlas}.nii.gz \
            --min ${minVal} \
            --o ${outputDir}/tmp_mask1.nii.gz \
        "    
    echo $cmd
    log $cmd >> $OUT
    eval $cmd
    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${atlasOutputDir}/${atlas}.nii.gz \
            --min $(( ${maxVal} + 1 )) --inv \
            --o ${outputDir}/tmp_mask2.nii.gz \
        "    
    echo $cmd
    log $cmd >> $OUT
    eval $cmd
    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${outputDir}/tmp_mask1.nii.gz \
            ${outputDir}/tmp_mask2.nii.gz \
            ${outputDir}/tmp_mask3.nii.gz \
        "    
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${atlasOutputDir}/${atlas}.nii.gz \
            ${outputDir}/tmp_mask3.nii.gz \
            ${atlasOutputDir}/${atlas}.nii.gz \
        "    
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    ls ${outputDir}/tmp_mask?.nii.gz && rm ${outputDir}/tmp_mask?.nii.gz

    # look at only cortical
    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${atlasOutputDir}/${atlas}.nii.gz \
            ${outputDir}/${subj}_cortical_mask.nii.gz \
            ${atlasOutputDir}/${atlas}.nii.gz \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    ##################    
    #do a quick remap#
    ##################
    # remaps lables to start at 1-(n labels), assumes the LUT is the 
    # simple LUT produced by make_fs_stuff script

    # inputs to python script -->
    #  i_file = str(argv[1])
    #  o_file = str(argv[2])
    #  labs_file = str(argv[3])
    cmd="python ${scriptBaseDir}/src/maTT_remap.py \
            ${atlasOutputDir}/${atlas}.nii.gz \
            ${atlasOutputDir}/${atlas}_remap.nii.gz \
            ${atlasOutputDir}/LUT_${atlas}.txt \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # if remap is not main, exit 1
    if [[ ! -e ${atlasOutputDir}/${atlas}_remap.nii.gz ]]
    then
        echo "remap output not made"
        exit 1
    fi

    ########################################
    #add the subcortical areas relabled way#
    ########################################

    cmd="${FREESURFER_HOME}/bin/mri_mask \
        ${atlasOutputDir}/${atlas}_remap.nii.gz \
        ${outputDir}/${subj}_subcort_mask_binv.nii.gz \
        ${atlasOutputDir}/${atlas}_remap.nii.gz \
    "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # get the max value from cortical atlas image
    # maxCortical=$(fslstats ${atlasOutputDir}/${atlas}_remap.nii.gz -R | awk '{print int($2)}')
    ${FREESURFER_HOME}/bin/mris_calc -o ${outputDir}/max_tmp.txt ${atlasOutputDir}/${atlas}_remap.nii.gz max
    maxCortical=$( cat ${outputDir}/max_tmp.txt | awk '{print int($1)}')
    ls ${outputDir}/max_tmp.txt && rm ${outputDir}/max_tmp.txt

    cmd="${FREESURFER_HOME}/bin/mris_calc \
            -o ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz \
            ${outputDir}/${subj}_subcort_mask.nii.gz \
            add ${maxCortical} \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    cmd="${FREESURFER_HOME}/bin/mri_threshold \
            ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz \
            $(( ${maxCortical} + 1 )) \
            ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz  \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    cmd="${FREESURFER_HOME}/bin/mris_calc \
        -o ${atlasOutputDir}/${atlas}_remap.nii.gz \
        ${atlasOutputDir}/${atlas}_remap.nii.gz \
        add ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz  \
    "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd

    # remove temp files
    ls ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz && rm ${atlasOutputDir}/${subj}_subcort_mask_${atlas}tmp.nii.gz 

done

cmd="${FREESURFER_HOME}/bin/mri_binarize \
        --i ${outputDir}/bmask.nii.gz \
        --min 1 --merge ${outputDir}/output_cortical_mask.nii.gz \
        --o ${outputDir}/mask.nii.gz \
    "
echo $cmd
log $cmd >> $OUT
eval $cmd

# delete extra stuff
# the temp fsDirectory we setup at very beginning
ls -d ${outputDir}/tmpFsDir/ && rm -r ${outputDir}/tmpFsDir/

} # main

# source the funcs
source ${scriptBaseDir}/src/maTT_funcs.sh

####################################################################
####################################################################

# run main with input args from shell script call
main "$@"
