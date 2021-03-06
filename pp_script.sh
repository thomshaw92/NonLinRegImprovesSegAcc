#!/bin/bash

#Thomas Shaw 5/4/18 
#skull strip t1/tse, bias correct, normalise, interpolate, then prepare for nlin/lin MC (different script)
#also includes TSE_MEAN from scanner now as run-mean TSE. 

subjName=$1
source ~/.bashrc
export ITK_GLOBAL_DEFAULT_NUMBER_OF_THREADS=4
export NSLOTS=4
echo $TMPDIR
data_dir=/30days/$USER
cp -r $data_dir/${subjName} $TMPDIR/${subjName}
mkdir -p $data_dir/derivatives/preprocessing/${subjName}
mkdir -p $TMPDIR/derivatives/preprocessing/
cp -r $data_dir/derivatives/preprocessing/$subjName $TMPDIR/derivatives/preprocessing/
cp -r $data_dir/$subjName $TMPDIR/
module load singularity/2.4.2
singularity="singularity exec --bind $TMPDIR:/TMPDIR --pwd /TMPDIR/ $data_dir/ants_fsl_robex_20180427.simg"
bidsdir=/TMPDIR
ss="ses-01"
t1w=$bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T1w.nii.gz
tse1=$bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-1_tse.nii.gz
tse2=$bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-2_tse.nii.gz
tse3=$bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-3_tse.nii.gz
tsemean=$bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-mean_tse.nii.gz
deriv=/$bidsdir/derivatives
mkdir -p $data_dir/derivatives/preprocessing/${subjName}/
cd $data_dir/derivatives/preprocessing/${subjName}/
echo $subjName
echo $t1w

#initial skull strip
$singularity runROBEX.sh $t1w $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brain_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz
#bias correct t1
$singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $t1w -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz --verbose 1 -s 2
if [[ ! -e $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz ]] ; then
    $singularity CopyImageHeaderInformation $t1w $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz
    $singularity fslcpgeom $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz $t1w
    $singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $t1w -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz --verbose 1 -s 2
fi
#normalise t1
t1bc=$deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_preproc.nii.gz
$singularity ~/scripts/niifti_normalise.sh -i $t1bc -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_norm_preproc.nii.gz
#skull strip new Bias corrected T1
$singularity runROBEX.sh $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_norm_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_N4corrected_norm_brain_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz


######TSE#####
#apply mask to tse - resample like tse - this is just for BC
$singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $tse1 -applyxfm -usesqform -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-1_brainmask.nii.gz
$singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $tse2 -applyxfm -usesqform -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-2_brainmask.nii.gz
$singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $tse3 -applyxfm -usesqform -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-3_brainmask.nii.gz
$singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $tsemean -applyxfm -usesqform -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-mean_brainmask.nii.gz
#Bias correction - use mask created - 
for x in "1" "2" "3" "mean" ; do
    
#N4
    $singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_preproc.nii.gz --verbose 1 -s 2 
    if [[ ! -e $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_preproc.nii.gz ]] ; then
    #copy header info to make sure bc works
	$singularity CopyImageHeaderInformation $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz
	$singularity fslcpgeom $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz
	$singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_preproc.nii.gz --verbose 1 -s 2
    fi   
    #second pass just in case - mask -to - tse
    if [[ ! -e $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_preproc.nii.gz ]] ; then
    #copy header info to make sure bc works 
	$singularity CopyImageHeaderInformation $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz  $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz  $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz
	$singularity N4BiasFieldCorrection -d 3 -b [1x1x1,3] -c '[50x50x40x30,0.00000001]' -i $bidsdir/$subjName/$ss/anat/${subjName}_${ss}_T2w_run-${x}_tse.nii.gz -x $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz -r 1 -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_preproc.nii.gz --verbose 1 -s 2
    fi 
#normalise intensities of the BC'd tses
    t2bc=$deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_preproc.nii.gz
    $singularity ~/scripts/niifti_normalise.sh -i $t2bc -o $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_norm_preproc.nii.gz
    #interpolation of TSEs -bring all into the same space while minimising interpolation write steps.
    $singularity flirt -v -applyisoxfm 0.3 -interp sinc -sincwidth 8 -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_norm_preproc.nii.gz -ref $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_norm_preproc.nii.gz -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz
    #create new brainmask and brain images. 
    $singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T1w_brainmask.nii.gz -ref $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz
    rm $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_N4corrected_norm_preproc.nii.gz 
done


for x in "1" "2" "3" "mean"; do
#mask the preprocessed TSE.
    $singularity fslmaths $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz -mul $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_brain_preproc.nii.gz
if [[ ! -e  $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_brain_preproc.nii.gz ]] ; then 
	$singularity flirt -v -in $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz -ref $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz -applyxfm -usesqform -out $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz
	$singularity CopyImageHeaderInformation $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz
	$singularity fslcpgeom $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz
	$singularity fslmaths $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_preproc.nii.gz -mul $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_brainmask.nii.gz $deriv/preprocessing/$subjName/${subjName}_${ss}_T2w_run-${x}_res-iso.3_N4corrected_norm_brain_preproc.nii.gz
fi
done

#move back out of TMPDIR...
cp -r $TMPDIR/$subjName $data_dir/
cp -r $TMPDIR/derivatives/preprocessing/* $data_dir/derivatives/preprocessing/
echo "done PP for $subjName"
