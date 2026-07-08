#!/bin/bash

# cd to cope1 folder in the 3rd level analyses you are looking to test
# Set working directory
wd="$(pwd)"
echo "Running in directory: $wd"

# Set input image and mask
copefile="BLAHBLAHBLAH.nii.gz"
maskfile="/Volumes/macX/anatomical-masks..path to mask.nii.gz"

# Create output folder
mkdir -p randomise_output

# Run randomise
echo "Running randomise..."
randomise -i "$copefile" -o randomise_output/rnd -m "$maskfile" -d design.mat -t design.con -T -n 10000

# Determine number of tstats from output files
num_contrasts=$(ls randomise_output/rnd_tfce_corrp_tstat*.nii.gz 2>/dev/null | wc -l)

if [ "$num_contrasts" -eq 0 ]; then
  echo "❌ No tstat files found. Exiting."
  exit 1
fi

echo "Found $num_contrasts tstat contrasts to process..."

# Loop through all available tstat outputs
for tstat_file in randomise_output/rnd_tfce_corrp_tstat*.nii.gz; do
  tstat_name=$(basename "$tstat_file" .nii.gz)
  contrast_num=$(echo "$tstat_name" | grep -o '[0-9]*$')

  echo ""
  echo "Processing tstat$contrast_num..."

  # Threshold and apply mask
  fslmaths "$tstat_file" -thr 0.95 -bin randomise_output/tfce_95_tstat_mask${contrast_num}
  fslmaths randomise_output/rnd_tstat${contrast_num} -mas randomise_output/tfce_95_tstat_mask${contrast_num} \
           randomise_output/1_tfce_95_tstat_BOLD${contrast_num}

  # Run cluster
  cluster -i randomise_output/1_tfce_95_tstat_BOLD${contrast_num} -t 0.001 --mm \
    --oindex=randomise_output/cluster_index_tstat${contrast_num} \
    --osize=randomise_output/cluster_size_tstat${contrast_num} \
    --scalarname=T > randomise_output/2_cluster_report_c${contrast_num}.txt

  
done


