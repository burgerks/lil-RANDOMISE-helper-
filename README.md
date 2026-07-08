# FSL Group-Level COPE Merge and Permutation Inference

Two Bash scripts for running a group-level (3rd-level) fMRI analysis in FSL from
per-subject lower-level contrast estimates. The first assembles a single 4D input
after checking that subjects are geometrically consistent; the second runs
nonparametric permutation inference (`randomise` with TFCE) and turns the corrected
maps into cluster reports.

The intended order is:

1. `_merge_copes.sh` &rarr; produces one 4D COPE file (subjects concatenated along time).
2. `_run_RANDOMISE.sh` &rarr; runs `randomise` on that file, then thresholds and clusters the output.

---

## Requirements

- **FSL** (tested against FSL 6.x) with the following on `$PATH`:
  `fslmerge`, `fslmaths`, `fslinfo`, `fslhd`, `fslorient`, `randomise`, `cluster`.
- Per-subject lower-level `cope*.nii.gz` files already registered to a common space
  (e.g. MNI), typically from FEAT / gFEAT output.
- A **group design** for `randomise`: `design.mat` and `design.con` (create with the
  FSL GLM GUI, or from text with `Text2Vest`).
- A **group mask** in the same space and resolution as the COPEs.

---

## Repository contents

| Script | Purpose |
| --- | --- |
| `_merge_copes.sh` | Gathers per-subject COPEs, checks orientation / dimensions / affine against a reference subject, and merges valid files into one 4D NIfTI. |
| `_run_RANDOMISE.sh` | Runs `randomise` (TFCE, 10,000 permutations) on the merged file, then thresholds the corrected maps and generates cluster tables. |

---

## `_merge_copes.sh`

Loops over a subject list, resolves each subject's COPE path from a template, and
compares every subject to the first valid one before concatenating. The header checks
are there to catch the silent failure mode where `fslmerge` stacks images with
mismatched orientation or voxel geometry without erroring out.

### What it checks

For the first subject found, it records a reference: orientation label
(`fslorient -getorient`), image/voxel dimensions (`fslinfo`), and the affine-relevant
header fields (`dim*`, `pixdim*`, `qform_code`, `sform_code`, `qto_xyz`, `sto_xyz` via
`fslhd`). Each later subject is compared against that reference, and three counters are
tracked and reported: orientation-label mismatches, dimension/pixdim mismatches, and
full header/affine differences. Missing files are counted separately and skipped.

### Before running, edit

- `cd` line at the top &rarr; the folder where the merged file should be written.
- `merged_file` &rarr; the output name (default is a `BLAHBLAHBLAH.nii.gz` placeholder).
- `subjects=( ... )` &rarr; your subject IDs (the list currently ends in `sub-002...`).
- `cope_path` template inside the loop &rarr; your actual COPE location.

> **Path check:** the `cope_path` template inside the loop
> (`.../copeXXX.feat/stats/copeX.nii.gz`) is a placeholder. Only this in-loop template
> is used, not the `cd` comment at the top, so make sure it points at the specific COPE
> you intend to analyze.

### Run

```bash
bash _merge_copes.sh
```

The script prints a `CHECK SUMMARY` block. Any nonzero mismatch count means the flagged
subjects should be inspected before you trust the merged file. It aborts if no COPEs are
found.

---

## `_run_RANDOMISE.sh`

Run this from the folder containing the merged 4D file, `design.mat`, and `design.con`.

### What it does

Runs `randomise` with TFCE enabled (`-T`) and 10,000 permutations (`-n 10000`), writing
outputs under `randomise_output/` with prefix `rnd`. It then counts the produced
`rnd_tfce_corrp_tstat*` maps and, for each contrast:

1. Thresholds the TFCE corrected-*p* map at `0.95` and binarizes it. Because `randomise`
   writes corrected maps as `1 - p`, this keeps voxels at corrected *p* < 0.05.
2. Masks the raw `rnd_tstat*` map with that binary mask, leaving *t* values only where
   the corrected threshold survived.
3. Runs `cluster` (`--mm`) on the masked *t* map to write a cluster index volume, a
   cluster size volume, and a text report (`2_cluster_report_c*.txt`).

The `cluster` step uses a very low `-t 0.001` on the already-masked map, so it functions
as connected-component labeling of the surviving voxels rather than a second statistical
threshold.

### Before running, edit

- `copefile` &rarr; the merged 4D file from step 1 (default is the same placeholder name).
- `maskfile` &rarr; absolute path to your group mask.
- Confirm `design.mat` and `design.con` are present in the working directory.

### Run

```bash
bash _run_RANDOMISE.sh
```

### Outputs (under `randomise_output/`)

- `rnd_tstat*` &ndash; raw *t*-statistic maps per contrast.
- `rnd_tfce_corrp_tstat*` &ndash; TFCE corrected `1 - p` maps.
- `tfce_95_tstat_mask*` &ndash; binary mask of voxels at corrected *p* < 0.05.
- `1_tfce_95_tstat_BOLD*` &ndash; raw *t* values restricted to surviving voxels.
- `cluster_index_tstat*`, `cluster_size_tstat*` &ndash; labeled cluster volumes.
- `2_cluster_report_c*.txt` &ndash; per-cluster coordinates and sizes (mm).

---

## Notes

- **Placeholders:** both scripts ship with `BLAHBLAHBLAH.nii.gz`, `/.../`, and `path to
  mask` placeholders that must be replaced before use.
- **Design centering / contrasts:** `randomise` uses `design.mat` and `design.con` as
  given. Covariate centering and contrast specification are set upstream when you build
  those files, not here.
- **Space consistency:** the mask, the COPEs, and the design must all correspond to the
  same subjects, order, and image space. The merge script checks image geometry but not
  whether subject order in the 4D file matches the row order in `design.mat`.
