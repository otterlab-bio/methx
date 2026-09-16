# methx Build Instructions

## Building from Source

### Prerequisites

1. **Rust toolchain** (1.75+):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   source $HOME/.cargo/env
   ```

2. **Native build tools for static HDF5 compilation**:

   Linux:
   ```bash
   sudo apt-get update
   sudo apt-get install -y build-essential cmake pkg-config
   ```

   macOS:
   ```bash
   brew install cmake pkg-config
   ```

   The release binary does not require a system HDF5 runtime. These packages are needed only when compiling `methx` from source.

### Build Steps

```bash
# Clone the repository (if in methrix root)
cd methx

# Build release version (optimized)
cargo build --release

# The binary will be at:
#   Linux/macOS: target/release/methx
#   Windows: target/release/methx.exe

# Optional: Install to system path
sudo cp target/release/methx /usr/local/bin/
```

### Development Build

```bash
# Build with debug symbols
cargo build

# Run tests
cargo test

# Run specific test
cargo test test_cpg_extraction

# Run with debug logging
RUST_LOG=debug cargo run -- process --help
```

### Cross-compilation

#### Linux to Windows

```bash
cargo install cross
cross build --target x86_64-pc-windows-gnu --release
```

#### Linux to macOS

```bash
cross build --target x86_64-apple-darwin --release
```

## Running the Binary

```bash
# Show help
./target/release/methx --help

# Process Bismark files
./target/release/methx process \
  --input bismark_output/ \
  --output results/ \
  --genome hg19.fa \
  --threads 8

# Extract CpGs
./target/release/methx extract-cpgs \
  --genome hg19.fa \
  --output hg19_cpgs.ron

# Generate QC report
./target/release/methx qc-report \
  --input results/ \
  --output qc.xlsx
```

## Docker Build

### Dockerfile

```dockerfile
FROM rust:1.75-slim as builder

RUN apt-get update && \
    apt-get install -y \
        build-essential \
        cmake \
        pkg-config \
        ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y ca-certificates && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/methx /usr/local/bin/
ENTRYPOINT ["methx"]
```

### Build and run

```bash
# Build
docker build -t methx .

# Run
docker run -v $(pwd)/data:/data methx \
  process --input /data/bismark --output /data/results --genome /data/hg19.fa
```

## Installation Packages

### Debian Package

```bash
# Install cargo-deb
cargo install cargo-deb

# Build package
cargo deb --no-build

# Install
sudo dpkg -i target/debian/methx*.deb
```

### RPM Package

```bash
# Install cargo-generate-rpm
cargo install cargo-generate-rpm

# Build package
cargo generate-rpm

# Install
sudo rpm -i target/generate-rpm/methx*.rpm
```

## Verification

### Test installation

```bash
# Check version
methx --version

# Run help
methx --help

# Test basic functionality
methx extract-cpgs --help
methx process --help
methx qc-report --help
```

### Test with sample data

```bash
# (If sample data is available)
methx process \
  --input tests/data/bismark/ \
  --output /tmp/test_output/ \
  --genome tests/data/hg19.fa \
  --threads 2
```

## Troubleshooting Build Issues

### Build/linking failure

Install the native build tools listed above and retry the release build. A deployed release binary should not require `libhdf5` at runtime.

### Linking error on Windows

Use a supported Rust target and ensure the native build toolchain is available. Runtime HDF5 environment variables are not part of the release installation contract.

### "needletail compilation error"

**Solution**: Update Rust and dependencies:
```bash
cargo update
cargo clean
cargo build
```

### macOS native build failure

Install the native build tools listed in Prerequisites, clean the Cargo target, and retry:

```bash
brew install cmake pkg-config
cargo clean
cargo build --release
```

## Advanced Build Options

### Static HDF5 runtime

Static linking is enabled by the dependency declaration and is not a Cargo feature named `static`:

```bash
cargo build --release
```

### Custom features

```bash
# Build with download feature
cargo build --release --features download

# Build with all features
cargo build --release --all-features
```

### Optimized for your CPU

```bash
# Native CPU optimizations
RUSTFLAGS="-C target-cpu=native" cargo build --release
```

## Continuous Integration

### GitHub Actions

```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      - name: Install native build tools
        run: sudo apt-get install -y build-essential cmake pkg-config
      - name: Build
        run: cargo build --release --all-features
      - name: Test
        run: cargo test --all-features
      - name: Upload binary
        uses: actions/upload-artifact@v3
        with:
          name: methx
          path: target/release/methx
```
