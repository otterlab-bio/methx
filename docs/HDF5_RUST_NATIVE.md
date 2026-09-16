# methx HDF5 native build

`methx` uses the `hdf5-metno` Rust API with static linking enabled:

```toml
hdf5 = { package = "hdf5-metno", version = "0.13", features = ["static", "zlib"] }
```

This means release binaries include the HDF5 runtime and do not require `libhdf5` on the target server. The release installer therefore does not configure `HDF5_DIR`, `HDF5_LIB_DIR`, `PKG_CONFIG_PATH`, or `LD_LIBRARY_PATH`.

Source builds still require Rust/Cargo, CMake, a C compiler, and the native build dependencies used while compiling HDF5. Those are build-host requirements, not runtime requirements.

Validate a release binary with:

```bash
methx --version
ldd "$(command -v methx)" | grep -E 'hdf5|not found' || true
```

The custom `methx.custom-hdf5` schema is separate from linking. Use `scripts/export_methrix_hdf5.R` when a native Methrix-compatible export is required.
