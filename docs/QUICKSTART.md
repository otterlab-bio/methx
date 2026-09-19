# methx - Quick Start Guide

## Overview

methx is a Rust command-line tool for processing Bismark bisulfite sequencing
data into the versioned `methx.custom-hdf5` schema.

## Key Features

- **Standalone processing** — producing custom HDF5 and QC outputs does not
  require an R runtime.
- **Parallel processing** — `--threads` controls the Rayon worker pool.
- **Explicit schema** — `/beta`, `/cov`, row/column metadata, coordinates, and
  loader compatibility are versioned and validated before publication.
- **Native Methrix export** — R and Bioconductor are required only when
  converting the custom HDF5 file with `scripts/export_methrix_hdf5.R`.

## Quick Start

### 1. Install

```bash
# From methrix repository
cd methx
cargo build --release

# Binary is at: target/release/methx
```

### 2. Basic Usage

```bash
# Process Bismark output files
./methx process \
  --input bismark_output/ \
  --output results/ \
  --genome hg19.fa \
  --threads 8
```

### 3. Use in R

```r
# The generated file is a custom HDF5 schema, NOT a native methrix directory.
# Convert it first with the official exporter, then load:
source("scripts/export_methrix_hdf5.R")
export_methx_h5_to_methrix(
  methx_h5_path    = "results/assays.h5",
  output_directory = "results/methrix_h5",
  validate         = TRUE
)

library(methrix)
m <- load_HDF5_methrix("results/methrix_h5")

# Use all standard methrix functions
get_stats(m)
plot_coverage(m)
```

## Workflow

### Option 1: Direct from FASTA

```bash
# 1. Process with FASTA (CpG extraction happens on-the-fly)
methx process \
  --input bismark_output/ \
  --output results/ \
  --genome /path/to/hg19.fa \
  --threads 8
```

### Option 2: Pre-extract CpGs (faster for multiple runs)

```bash
# 1. Extract CpGs once
methx extract-cpgs \
  --genome /path/to/hg19.fa \
  --output hg19_cpgs.ron

# 2. Process multiple datasets using pre-extracted CpGs
methx process --input batch1/ --output out1/ --genome hg19_cpgs.ron
methx process --input batch2/ --output out2/ --genome hg19_cpgs.ron
```

### Option 3: Download built-in genome

```bash
# 1. Download genome
methx download-genome --genome hg19 --output genomes/

# 2. Process
methx process \
  --input bismark_output/ \
  --output results/ \
  --genome genomes/hg19.fa
```

## Commands Reference

### `methx process`

Main command to process Bismark files.

```bash
methx process [OPTIONS]

Required:
  -i, --input <DIR>      Directory with *.bismark.cov.gz files
  -o, --output <DIR>     Output directory
  -g, --genome <GENOME>  FASTA file or pre-extracted .ron file

Optional:
  -t, --threads <N>      Number of threads [default: CPU count]
      --min-coverage <N>  Minimum coverage threshold [default: 1]
      --remove-uncovered Remove uncovered loci [default: true]
  -v, --verbose          Enable debug logging
```

### `methx extract-cpgs`

Extract CpG sites from reference genome (optional optimization).

```bash
methx extract-cpgs [OPTIONS]

Required:
  -g, --genome <GENOME>  FASTA file
  -o, --output <FILE>    Output RON file

Optional:
      --contigs <LIST>   Specific contigs to include
  -v, --verbose          Enable debug logging
```

### `methx download-genome`

Download reference genomes from UCSC.

```bash
methx download-genome [OPTIONS]

Required:
  -g, --genome <GENOME>  Genome name: hg19, hg38, mm10, mm39
  -o, --output <DIR>     Output directory
```

### `methx qc-report`

Generate QC report from existing H5 file.

```bash
methx qc-report [OPTIONS]

Required:
  -i, --input <DIR>      Directory with methrix H5 file
  -o, --output <FILE>    Output Excel file
```

## Output Files

### 1. Methrix H5 File

**Location**: `{output}/methrix_data.h5`

**Structure** (R-compatible):
```
methrix_data.h5
├── assays/
│   ├── beta          # Methylation values (0-1)
│   └── cov           # Coverage counts
├── rowData/
│   ├── chr           # Chromosome
│   ├── start         # 0-based position
│   ├── end           # End position
│   └── strand        # Strand (+)
├── colData/
│   └── sample_id     # Sample names
└── metadata/
    ├── genome        # Reference genome
    └── is_h5         # Format flag
```

### 2. QC Report

**Location**: `{output}/CpG_coverage.xlsx`

**Content**:
- Sample names
- Total CpGs
- Covered CpGs
- Coverage distribution (1X, 2X, 3X, 4X, 5X, 10X)

## Performance

### Benchmarks

Processing 100 samples (~10M CpGs each):

| Implementation | Time | Memory |
|----------------|------|--------|
| R script | ~45 min | ~8 GB |
| methx | ~5 min | ~4 GB |

### Optimization Tips

1. **Use pre-extracted CpGs**: Extract once, reuse many times
2. **Increase threads**: More threads = faster (up to a point)
3. **Use SSD**: H5 benefits from fast I/O
4. **Filter early**: Remove low-coverage samples to reduce data size

## Troubleshooting

### "CpG data not found"

**Solution**: Provide a valid genome reference:
```bash
# Option A: FASTA file
--genome /path/to/hg19.fa

# Option B: Pre-extracted
--genome hg19_cpgs.ron
```

### "No Bismark files found"

**Solution**: Ensure input directory has `*.bismark.cov.gz` or `*.cov.gz` files.

### H5 loading error in R

**Solution**: The custom H5 file cannot be loaded with `load_HDF5_methrix()`
directly. Convert it first:
```r
source("scripts/export_methrix_hdf5.R")
export_methx_h5_to_methrix("assays.h5", "methrix_h5", validate = TRUE)
m <- methrix::load_HDF5_methrix("methrix_h5")
```

## Examples

### Example 1: Small dataset

```bash
methx process \
  --input small_project/bismark/ \
  --output small_project/results/ \
  --genome hg19.fa \
  --threads 4
```

### Example 2: Large dataset with optimization

```bash
# Step 1: Extract CpGs (once)
methx extract-cpgs \
  --genome hg38.fa \
  --output hg38_cpgs.ron

# Step 2: Process
methx process \
  --input large_bismark/ \
  --output results/ \
  --genome hg38_cpgs.ron \
  --threads 16 \
  --min-coverage 5 \
  --remove-uncovered
```

### Example 3: Generate QC report only

```bash
methx qc-report \
  --input existing_results/ \
  --output qc_report.xlsx
```

## Next Steps

After processing, use R methrix for analysis:

```r
# Convert the custom H5 output to a native methrix directory first
source("scripts/export_methrix_hdf5.R")
export_methx_h5_to_methrix("results/assays.h5", "results/methrix_h5", validate = TRUE)

library(methrix)
m <- load_HDF5_methrix("results/methrix_h5")

# QC
get_stats(m)
plot_coverage(m)

# Analysis
methrix_pca(m)
region_summary <- get_region_summary(m, regions = promoters)
```

## Support

- **Issues**: https://github.com/otterlab-bio/methx/issues
- **Documentation**: See `docs/` directory
