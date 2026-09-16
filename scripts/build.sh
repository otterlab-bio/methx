#!/usr/bin/env bash
# Build methx from source with the static HDF5 dependency configuration.

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

printf '%b\n' "${YELLOW}=== methx Build Script ===${NC}"

if ! command -v cargo >/dev/null 2>&1; then
  printf '%b\n' "${RED}Error: cargo not found. Install Rust before building methx.${NC}" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  printf '%b\n' "${RED}Error: cmake not found. Install CMake before building methx.${NC}" >&2
  exit 1
fi

printf '%b\n' "${GREEN}Building methx with hdf5-metno static linking...${NC}"
cargo build --release

printf '\n%b\n' "${GREEN}=== Build successful! ===${NC}"
printf '%s\n' 'Binary: target/release/methx' 'Runtime HDF5 libraries are not required by the release binary.'
