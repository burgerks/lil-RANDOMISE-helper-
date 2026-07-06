#!/bin/bash

## Set working directory to output location
cd /.../.gfeat/cope1.feat

# Output filename (written in the current working directory)
merged_file="BLAHBLAHBLAH.nii.gz"

# Subject list
subjects=(
sub-001
sub-002...
)

# Initialize the list of cope file paths
cope_list=""

# Reference image for orientation/header checking
ref_file=""
ref_subj=""

# Temporary files for geometry/header comparison
ref_geom="ref_geom.txt"
tmp_geom="tmp_geom.txt"

# Track whether there were any possible problems
n_missing=0
n_header_diff=0
n_dim_diff=0
n_orient_diff=0

echo "========== CHECKING FILES AND ORIENTATION HEADERS =========="

# Collect all available cope files and compare geometry/orientation headers
for subj in "${subjects[@]}"; do

  cope_path="/Volumes/macX/bevel/bevel_fMRI/${subj}/func/Analysis/feat2/feat2_expanded/${subj}.gfeat/cope7.feat/stats/cope1.nii.gz"

  if [ -f "$cope_path" ]; then

    echo "Found: $subj"

    # First valid file becomes reference
    if [ -z "$ref_file" ]; then
      ref_file="$cope_path"
      ref_subj="$subj"

      echo "Using as reference: $ref_subj"
      echo "$ref_file"

      ref_orient=$(fslorient -getorient "$ref_file")
      echo "Reference orientation: $ref_orient"

      # Save reference geometry/orientation info
      fslhd "$ref_file" | grep -E "^dim[1234]|^pixdim[1234]|^qform_code|^sform_code|^qto_xyz|^sto_xyz" > "$ref_geom"

      # Save reference dimensions separately for easier checking
      ref_dims=$(fslinfo "$ref_file" | awk '/^dim[1-4]/ {print $2}' | paste -sd 'x' -)
      ref_pixdims=$(fslinfo "$ref_file" | awk '/^pixdim[1-4]/ {print $2}' | paste -sd 'x' -)
      echo "Reference dims: $ref_dims"
      echo "Reference pixdims: $ref_pixdims"

    else

      current_orient=$(fslorient -getorient "$cope_path")

      # Basic orientation label check: NEUROLOGICAL vs RADIOLOGICAL
      if [ "$current_orient" != "$ref_orient" ]; then
        echo ""
        echo "⚠️  ORIENTATION LABEL MISMATCH: $subj"
        echo "    Reference ($ref_subj): $ref_orient"
        echo "    Current:             $current_orient"
        echo ""
        n_orient_diff=$((n_orient_diff + 1))
      fi

      # Dimension/pixdim check
      current_dims=$(fslinfo "$cope_path" | awk '/^dim[1-4]/ {print $2}' | paste -sd 'x' -)
      current_pixdims=$(fslinfo "$cope_path" | awk '/^pixdim[1-4]/ {print $2}' | paste -sd 'x' -)

      if [ "$current_dims" != "$ref_dims" ] || [ "$current_pixdims" != "$ref_pixdims" ]; then
        echo ""
        echo "⚠️  DIMENSION / VOXEL SIZE MISMATCH: $subj"
        echo "    Reference dims:    $ref_dims"
        echo "    Current dims:      $current_dims"
        echo "    Reference pixdims: $ref_pixdims"
        echo "    Current pixdims:   $current_pixdims"
        echo ""
        n_dim_diff=$((n_dim_diff + 1))
      fi

      # Full qform/sform affine header check
      fslhd "$cope_path" | grep -E "^dim[1234]|^pixdim[1234]|^qform_code|^sform_code|^qto_xyz|^sto_xyz" > "$tmp_geom"

      if ! diff -q "$ref_geom" "$tmp_geom" >/dev/null; then
        echo ""
        echo "⚠️  HEADER / ORIENTATION DIFFERENCE: $subj"
        echo "    Differences relative to $ref_subj:"
        diff "$ref_geom" "$tmp_geom"
        echo ""
        n_header_diff=$((n_header_diff + 1))
      fi

    fi

    cope_list+="${cope_path} "

  else
    echo "⚠️  Missing: $cope_path" >&2
    n_missing=$((n_missing + 1))
  fi
done

# Remove temporary comparison files
rm -f "$ref_geom" "$tmp_geom"

echo ""
echo "========== CHECK SUMMARY =========="
echo "Missing files:                  $n_missing"
echo "Orientation label mismatches:   $n_orient_diff"
echo "Dimension / pixdim mismatches:  $n_dim_diff"
echo "Header / affine differences:    $n_header_diff"

if [ -z "$cope_list" ]; then
  echo "ERROR: No cope files found. Nothing to merge." >&2
  exit 1
fi

echo ""
echo "========== MERGING =========="

# Merge the valid files into one 4D NIfTI
# If FSL still prints an inconsistent-orientation warning, inspect the subjects flagged above.
fslmerge -t "$merged_file" $cope_list

echo ""
echo "Done: $merged_file"
