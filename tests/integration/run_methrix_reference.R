#!/usr/bin/env Rscript

arguments <- commandArgs(trailingOnly = TRUE)
if (length(arguments) != 5L) {
  stop(
    paste(
      "Usage: Rscript tests/integration/run_methrix_reference.R",
      "<methx-assays.h5> <reference.fasta> <coverage-directory>",
      "<methrix-object.rds> <metadata.tsv>"
    ),
    call. = FALSE
  )
}

methx_h5_path <- arguments[[1L]]
reference_fasta_path <- arguments[[2L]]
coverage_directory <- arguments[[3L]]
methrix_rds_path <- arguments[[4L]]
metadata_path <- arguments[[5L]]

required_packages <- c(
  "Biostrings",
  "data.table",
  "methrix",
  "rhdf5",
  "SummarizedExperiment"
)
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

sequence_names <- enc2utf8(as.character(read_h5("/rowData/seqnames")))
start_positions <- as.integer(read_h5("/rowData/start"))
end_positions <- as.integer(read_h5("/rowData/end"))
widths <- as.integer(read_h5("/rowData/width"))
strands <- as.character(read_h5("/rowData/strand"))
genome_name <- enc2utf8(as.character(read_h5("/metadata/genome")))

reference_sequences <- Biostrings::readDNAStringSet(reference_fasta_path)
assert_true(length(reference_sequences) == 1L, "Parity FASTA must contain exactly one contig")
reference_contig <- sub("[[:space:]].*$", "", names(reference_sequences)[[1L]])
reference_matches <- Biostrings::matchPattern("CG", reference_sequences[[1L]])
expected_starts <- as.integer(IRanges::start(reference_matches))
expected_ends <- as.integer(IRanges::end(reference_matches))

assert_true(
  identical(sequence_names, rep(reference_contig, length(expected_starts))),
  "RON-derived CpG chromosome vector differs from the Biostrings oracle"
)
assert_true(
  identical(start_positions, expected_starts) && identical(end_positions, expected_ends),
  "RON-derived CpG coordinates differ from Biostrings::matchPattern('CG')"
)
assert_true(all(widths == 2L), "RON-derived CpG widths must equal two bases")
assert_true(all(strands == "+"), "RON-derived reference CpGs must use the plus strand")

reference_cpgs <- list(
  cpgs = data.table::data.table(
    chr = sequence_names,
    start = as.numeric(start_positions),
    end = as.numeric(end_positions),
    width = as.numeric(widths),
    strand = strands
  ),
  contig_lens = data.table::data.table(
    contig = reference_contig,
    length = Biostrings::width(reference_sequences)[[1L]]
  ),
  release_name = genome_name
)

coverage_files <- sort(list.files(
  coverage_directory,
  pattern = "\\.bismark\\.cov\\.gz$",
  full.names = TRUE
))
assert_true(length(coverage_files) == 2L, "Parity audit requires exactly two coverage files")

methrix_timing <- system.time({
  methrix_object <- methrix::read_bedgraphs(
    files = coverage_files,
    pipeline = "Bismark_cov",
    zero_based = FALSE,
    stranded = TRUE,
    collapse_strands = TRUE,
    ref_cpgs = reference_cpgs,
    ref_build = genome_name,
    contigs = reference_contig,
    n_threads = 4L,
    h5 = FALSE,
    verbose = TRUE
  )
})

saveRDS(methrix_object, methrix_rds_path, compress = FALSE)
metadata <- data.frame(
  metric = c(
    "methrix_version",
    "reference_cpg_count",
    "reference_contig",
    "reference_universe_mismatches",
    "methrix_read_bedgraphs_elapsed_seconds",
    "sample_count"
  ),
  value = c(
    as.character(utils::packageVersion("methrix")),
    as.character(length(expected_starts)),
    reference_contig,
    "0",
    sprintf("%.6f", unname(methrix_timing[["elapsed"]])),
    as.character(ncol(methrix_object))
  ),
  stringsAsFactors = FALSE
)
write.table(metadata, metadata_path, sep = "\t", quote = FALSE, row.names = FALSE)
cat(sprintf(
  "PASS: Methrix %s processed %d reference CpGs and %d samples in %.3f seconds\n",
  utils::packageVersion("methrix"),
  length(expected_starts),
  ncol(methrix_object),
  unname(methrix_timing[["elapsed"]])
))
