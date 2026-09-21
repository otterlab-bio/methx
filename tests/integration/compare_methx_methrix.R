#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 4L) {
  stop(
    paste(
      "Usage: Rscript tests/integration/compare_methx_methrix.R",
      "<methx-assays.h5> <methrix-object.rds> <metadata.tsv> <report.json>"
    ),
    call. = FALSE
  )
}

methx_h5_path <- arguments[[1L]]
methrix_rds_path <- arguments[[2L]]
metadata_path <- arguments[[3L]]
report_path <- arguments[[4L]]

required_packages <- c("jsonlite", "methrix", "rhdf5", "SummarizedExperiment")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0L) {
  stop(
    sprintf("Missing required R packages: %s", paste(missing_packages, collapse = ", ")),
    call. = FALSE
  )
}

assert_true <- function(condition, message) {
  if (!isTRUE(condition)) {
    stop(message, call. = FALSE)
  }
}

read_h5 <- function(path) {
  tryCatch(
    rhdf5::h5read(methx_h5_path, path),
    error = function(error) {
      stop(
        sprintf("Unable to read %s from %s: %s", path, methx_h5_path, conditionMessage(error)),
        call. = FALSE
      )
    }
  )
}

normalize_assay <- function(values, cpg_count, sample_count, assay_name) {
  dimensions <- as.integer(dim(values))
  if (identical(dimensions, c(cpg_count, sample_count))) {
    return(values)
  }
  if (identical(dimensions, c(sample_count, cpg_count))) {
    return(t(values))
  }
  stop(
    sprintf(
      "%s dimensions %s do not match %d CpGs x %d samples",
      assay_name,
      paste(dimensions, collapse = " x "),
      cpg_count,
      sample_count
    ),
    call. = FALSE
  )
}

sequence_names <- enc2utf8(as.character(read_h5("/rowData/seqnames")))
start_positions <- as.integer(read_h5("/rowData/start"))
sample_names <- enc2utf8(as.character(read_h5("/colData/sample_name")))
cpg_count <- length(sequence_names)
sample_count <- length(sample_names)
methx_beta <- normalize_assay(read_h5("/beta"), cpg_count, sample_count, "methx beta")
methx_coverage <- normalize_assay(read_h5("/cov"), cpg_count, sample_count, "methx coverage")

methrix_object <- readRDS(methrix_rds_path)
assert_true(methods::is(methrix_object, "methrix"), "Reference R object is not a methrix object")
methrix_row_data <- as.data.frame(
  SummarizedExperiment::rowData(methrix_object),
  stringsAsFactors = FALSE
)
assert_true(
  all(c("chr", "start") %in% names(methrix_row_data)),
  "Methrix rowData is missing chr/start coordinates"
)

methrix_beta <- as.matrix(SummarizedExperiment::assay(methrix_object, "beta"))
methrix_coverage <- as.matrix(SummarizedExperiment::assay(methrix_object, "cov"))
methrix_sample_names <- colnames(methrix_object)
assert_true(
  setequal(methrix_sample_names, sample_names),
  sprintf(
    "Sample names differ: methx=%s; methrix=%s",
    paste(sample_names, collapse = ","),
    paste(methrix_sample_names, collapse = ",")
  )
)
sample_order <- match(sample_names, methrix_sample_names)
methrix_beta <- methrix_beta[, sample_order, drop = FALSE]
methrix_coverage <- methrix_coverage[, sample_order, drop = FALSE]

methx_keys <- paste(sequence_names, start_positions, sep = ":")
methrix_keys <- paste(
  as.character(methrix_row_data$chr),
  as.integer(methrix_row_data$start),
  sep = ":"
)
assert_true(!anyDuplicated(methx_keys), "Methx CpG keys are duplicated")
assert_true(!anyDuplicated(methrix_keys), "Methrix CpG keys are duplicated")
assert_true(setequal(methx_keys, methrix_keys), "Full CpG universes differ")
row_order <- match(methx_keys, methrix_keys)
methrix_beta <- methrix_beta[row_order, , drop = FALSE]
methrix_coverage <- methrix_coverage[row_order, , drop = FALSE]

methrix_coverage[is.na(methrix_coverage) | is.nan(methrix_coverage)] <- 0
methx_covered <- rowSums(methx_coverage > 0) > 0
methrix_covered <- rowSums(methrix_coverage > 0) > 0
covered_set_mismatches <- sum(xor(methx_covered, methrix_covered))
covered_indices <- which(methx_covered | methrix_covered)

methx_coverage_covered <- methx_coverage[covered_indices, , drop = FALSE]
methrix_coverage_covered <- methrix_coverage[covered_indices, , drop = FALSE]
methx_beta_covered <- methx_beta[covered_indices, , drop = FALSE]
methrix_beta_covered <- methrix_beta[covered_indices, , drop = FALSE]

coverage_cell_mismatches <- sum(methx_coverage_covered != methrix_coverage_covered)
methx_missing <- is.na(methx_beta_covered) | is.nan(methx_beta_covered)
methrix_missing <- is.na(methrix_beta_covered) | is.nan(methrix_beta_covered)
beta_missing_mask_mismatches <- sum(methx_missing != methrix_missing)
comparable <- !methx_missing & !methrix_missing
beta_differences <- abs(methx_beta_covered[comparable] - methrix_beta_covered[comparable])
maximum_beta_absolute_difference <- if (length(beta_differences) == 0L) {
  0
} else {
  max(beta_differences)
}
beta_mismatches_over_1e_6 <- sum(beta_differences > 1e-6)

cell_mismatches <- methx_coverage_covered != methrix_coverage_covered
cell_mismatches <- cell_mismatches | (methx_missing != methrix_missing)
beta_comparable_mismatches <- matrix(FALSE, nrow = nrow(cell_mismatches), ncol = ncol(cell_mismatches))
beta_comparable_mismatches[comparable] <- beta_differences > 1e-6
cell_mismatches <- cell_mismatches | beta_comparable_mismatches
matrix_mismatch_cells <- sum(cell_mismatches)

metadata_table <- read.delim(metadata_path, stringsAsFactors = FALSE, check.names = FALSE)
metadata <- stats::setNames(as.character(metadata_table$value), metadata_table$metric)
report <- list(
  schema_version = "otter.methx-methrix-parity/v1",
  scope = list(
    reference = "hg19 chr21",
    samples = sample_names,
    pipeline = "Bismark_cov",
    zero_based = FALSE,
    stranded = TRUE,
    collapse_strands = TRUE,
    threads = 4L,
    remove_uncovered_comparison = TRUE
  ),
  software = list(
    methrix_version = unname(metadata[["methrix_version"]])
  ),
  reference = list(
    source = "RON-derived complete methx HDF5 rowData",
    cpg_count = cpg_count,
    biostrings_universe_mismatches = as.integer(metadata[["reference_universe_mismatches"]]),
    full_universe_key_mismatches = 0L
  ),
  matrix = list(
    covered_cpg_count = length(covered_indices),
    covered_set_mismatches = covered_set_mismatches,
    coverage_value_mismatches = coverage_cell_mismatches,
    beta_missing_mask_mismatches = beta_missing_mask_mismatches,
    beta_mismatches_over_1e_6 = beta_mismatches_over_1e_6,
    maximum_beta_absolute_difference = maximum_beta_absolute_difference,
    matrix_mismatch_cells = matrix_mismatch_cells
  ),
  timing = list(
    methrix_read_bedgraphs_elapsed_seconds = as.numeric(
      metadata[["methrix_read_bedgraphs_elapsed_seconds"]]
    )
  ),
  equal = covered_set_mismatches == 0L &&
    coverage_cell_mismatches == 0L &&
    beta_missing_mask_mismatches == 0L &&
    beta_mismatches_over_1e_6 == 0L &&
    matrix_mismatch_cells == 0L
)

assert_true(report$reference$biostrings_universe_mismatches == 0L, "Biostrings universe mismatch")
assert_true(report$matrix$covered_set_mismatches == 0L, "Covered CpG sets differ")
assert_true(report$matrix$coverage_value_mismatches == 0L, "Coverage values differ")
assert_true(report$matrix$beta_missing_mask_mismatches == 0L, "Beta missing-value masks differ")
assert_true(report$matrix$beta_mismatches_over_1e_6 == 0L, "Beta values differ beyond 1e-6")
assert_true(report$matrix$matrix_mismatch_cells == 0L, "Final matrix cells differ")

jsonlite::write_json(report, report_path, auto_unbox = TRUE, pretty = TRUE, digits = 16)
cat(sprintf(
  paste0(
    "PASS: compared %d covered CpGs across %d samples; ",
    "coverage mismatches=%d, beta mismatches >1e-6=%d, max beta difference=%.12g\n"
  ),
  report$matrix$covered_cpg_count,
  sample_count,
  report$matrix$coverage_value_mismatches,
  report$matrix$beta_mismatches_over_1e_6,
  report$matrix$maximum_beta_absolute_difference
))
