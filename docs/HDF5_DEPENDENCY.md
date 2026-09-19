# HDF5 依赖说明

## 当前构建模型

`methx` 使用 `hdf5-metno` Rust API，并启用 `static` 与 `zlib` 特性。release 二进制将 HDF5 运行库编入自身，服务器运行时不需要安装系统 HDF5，也不需要设置 `HDF5_DIR`、`HDF5_LIB_DIR` 或 `LD_LIBRARY_PATH`。

源码构建仍需要 Rust/Cargo、CMake、C 编译器和构建所需的压缩库工具链，因为 `hdf5-metno` 会在构建阶段编译 native HDF5 依赖。

## Cargo.toml 配置

```toml
hdf5 = { package = "hdf5-metno", version = "0.13", features = ["static", "zlib"] }
```

## 验证 release binary

```bash
methx --version
file "$(command -v methx)"
ldd "$(command -v methx)" | grep -E 'hdf5|not found' || true
```

预期结果是没有 `libhdf5.so` 或 `libhdf5.dylib` 依赖；Linux 二进制通常仍会依赖系统的 `libc`、`libm` 和 `libgcc_s` 等基础运行库。

## Source build

```bash
cargo build --release
cargo test
```

如果构建系统未自动发现 native build tools，再根据平台安装 CMake、C 编译器和 pkg-config。不要把这些构建变量写入 Otter 用户 shell 配置；它们属于源码构建环境，不属于 release 安装器职责。

## HDF5 与 Methrix

HDF5 linking 与 HDF5 schema 是两个独立问题：静态链接只解决 `methx` 的运行时库依赖，不会把自定义 `methx.custom-hdf5` 文件自动变成原生 Methrix 对象。需要原生 Methrix 加载时，使用 `scripts/export_methrix_hdf5.R` 导出，并遵循对应兼容性报告。

相关文档：

- [BUILD.md](BUILD.md)
- [HDF5_STRUCTURE_AND_COORDINATES.md](HDF5_STRUCTURE_AND_COORDINATES.md)
- [R_METHRIX_COMPATIBILITY_GUIDE.md](R_METHRIX_COMPATIBILITY_GUIDE.md)
