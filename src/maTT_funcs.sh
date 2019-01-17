#!/bin/bash

##########################################################
##########################################################
# FUNCTIONS

log() 
{
    local msg="$*"
    local dateTime=`date`
    echo "# "$dateTime "-" $log_toolName "-" "$msg"
    echo "$msg"
    echo 
}

##########################################################

get_mask_frm_aparcAseg()
{
    # inputs
    local iAparcAseg=$1
    local oDir=$2
    local subj=$3

    ## add whole brain mask based on aseg.mgz
    #mri_binarize --i ${tempFSSubj}/mri/aseg.mgz --match 2 3 7 8 10 11 12 13 16 17 18 24 26 28 30 31 41 42 46 47 49 50 51 52 53 54 58 60 62 63 77 85 251 252 253 254 255 --o ${outputDir}/mask.nii.gz

    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${iAparcAseg} \
            --match 2 3 7 8 10 11 12 13 16 17 18 24 26 28 30 31 41 42 46 47 49 50 51 52 53 54 58 60 62 63 77 85 251 252 253 254 255 \
            --o ${oDir}/bmask.nii.gz \
        "    
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

}

get_subcort_frm_aparcAseg()
{
    # inputs
    local iAparcAseg=$1
    local oDir=$2
    local subj=$3

    ## now add the subcort 
    # the fs_lables correspond to labes in the image FS outputs
    local fsLabels=( 10 11 12 13 17 18 26 49 50 51 52 53 54 58 )
    # 10: Left-Thalamus-Proper
    # 11: Left-Caudate 
    # 12: Left-Putamen
    # 13: Left-Pallidum 
    # 17: Left-Hippocampus
    # 18: Left-Amygdala
    # 26: Left-Accumbens-area
    # 49: Right-Thalamus-Proper
    # 50: Right-Caudate 
    # 51: Right-Putamen
    # 52: Right-Pallidum 
    # 53: Right-Hippocampus
    # 54: Right-Amygdala
    # 58: Right-Accumbens-area

    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${iAparcAseg} \
            --match ${fsLabels[@]} --binval 1 --binvalnot 0 \
            --o ${oDir}/${subj}temp_subcort_mask1.nii.gz \
        "        
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    # make inverse while we're at it
    cmd="${FREESURFER_HOME}/bin/mri_binarize \
            --i ${iAparcAseg} \
            --match ${fsLabels[@]} --binval 0 --binvalnot 1 \
            --o ${oDir}/${subj}_subcort_mask_binv.nii.gz \
        "        
    echo $cmd #state the command
    log $cmd >> $OUT
    eval $cmd #execute the command

    cmd="${FREESURFER_HOME}/bin/mri_mask \
            ${iAparcAseg} \
            ${oDir}/${subj}temp_subcort_mask1.nii.gz \
            ${oDir}/${subj}temp_subcort_mask2.nii.gz \
        "    
    echo $cmd
    eval $cmd

    #replaceStr=''
    > ${oDir}/${subj}temp_remap_list.txt

    # could use freesurfer func to speed this up lots
    local newIndex=( 1 2 3 4 5 6 7 8 9 10 11 12 13 14 )
    for (( x=0 ; x<14; x++ ))
    do

        getLabel=${fsLabels[x]}
        getIndex=${newIndex[x]}
        #replaceStr="${replaceStr} --replace ${getLabel} ${getIndex}"
        echo "$getLabel FreeSurferAsegRegion${getLabel}" >> ${oDir}/${subj}temp_remap_list.txt

    done

    # --replace is only in freesurfer 6.0... so lets not use it.
    #cmd="${FREESURFER_HOME}/bin/mri_binarize \
    #        --i ${oDir}/${subj}temp_subcort_mask2.nii.gz \
    #        ${replaceStr} \
    #        --o ${oDir}/${subj}_subcort_mask.nii.gz \
    #    "        
    #echo $cmd #state the command
    #log $cmd >> $OUT
    #eval $cmd #execute the command

    # instead, just remap
    # inputs to python script -->
    #  i_file = str(argv[1])
    #  o_file = str(argv[2])
    #  labs_file = str(argv[3])
    cmd="python2.7 ${scriptBaseDir}/src/maTT_remap.py \
            ${oDir}/${subj}temp_subcort_mask2.nii.gz \
            ${oDir}/${subj}_subcort_mask.nii.gz \
            ${oDir}/${subj}temp_remap_list.txt \
        "
    echo $cmd
    log $cmd >> $OUT
    eval $cmd        

    # remove flotsum
    ls ${oDir}/${subj}temp* && rm ${oDir}/${subj}temp*

}

##########################################################
