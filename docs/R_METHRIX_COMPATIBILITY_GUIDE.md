# methx 自定义 HDF5 与 R methrix 的互操作指南

> 本文以 `src/hdf5/se_compat.rs` 为唯一 schema 事实来源，只描述当前支持契约。

## 兼容性契约（当前实现）

- methx 生成的 `assays.h5`（别名 `methrix_data.h5`）是**自定义 schema**：
  - `schema_name = methx.custom-hdf5`，`schema_version = 1.0.0`
  - `loader_compatibility = "rhdf5 direct schema access only; not compatible with
    HDF5Array::loadHDF5SummarizedExperiment or methrix::load_HDF5_methrix"`
- 它可以用 R 包 `rhdf5` **直接按 dataset 路径读取**；
- 它**不是** `methrix::load_HDF5_methrix()` 可加载的原生 Methrix 目录，
  也**不生成** `se.rds`。

## 直接读取（rhdf5）

```r
library(rhdf5)

beta  <- h5read("results/assays.h5", "/beta")
cov   <- h5read("results/assays.h5", "/cov")
chr   <- h5read("results/assays.h5", "/rowData/chr")
start <- h5read("results/assays.h5", "/rowData/start")  # 1-based closed
end   <- h5read("results/assays.h5", "/rowData/end")
sid   <- h5read("results/assays.h5", "/colData/sample_id")
```

完整的结构与坐标契约见
[HDF5_STRUCTURE_AND_COORDINATES.md](HDF5_STRUCTURE_AND_COORDINATES.md)。

## 转换为原生 Methrix（官方路径）

需要原生 `methrix` 对象时，使用仓库提供的标准转换脚本
[`scripts/export_methrix_hdf5.R`](../scripts/export_methrix_hdf5.R)：

```r
source("scripts/export_methrix_hdf5.R")

export_methx_h5_to_methrix(
  methx_h5_path    = "results/assays.h5",
  output_directory = "results/methrix_h5",
  validate         = TRUE
)

methrix_object <- methrix::load_HDF5_methrix("results/methrix_h5")
```

脚本内部调用 `methrix::save_HDF5_methrix()`，默认会重新加载导出结果，
校验坐标、样本元数据、coverage、beta 值与未覆盖位点掩码。

依赖的 R 包：`rhdf5`、`methrix`（及其依赖 `SummarizedExperiment`、
`GenomicRanges`、`HDF5Array`）。

## Supported path

用户侧原生 Methrix 转换只支持 `scripts/export_methrix_hdf5.R`。
