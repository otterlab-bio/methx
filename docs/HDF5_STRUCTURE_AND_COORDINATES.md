# HDF5 文件结构与 CpG 坐标契约

> 本文以 `src/hdf5/se_compat.rs`（writer 与测试）为唯一事实来源。
> 已废弃的旧 schema 不属于当前支持契约。

## 目录结构（当前 schema：methx.custom-hdf5 / 1.0.0）

```
assays.h5  （别名 methrix_data.h5，内容相同）
├── /beta                  FLOAT  [n_cpg x n_sample]  beta 矩阵（甲基化比例）
├── /cov                   UINT32 [n_cpg x n_sample]  coverage 矩阵
├── /rowData/
│   ├── chr                STRING [n_cpg]   染色体
│   ├── seqnames           STRING [n_cpg]   染色体（GRanges 兼容别名）
│   ├── start              UINT32 [n_cpg]   起始位置（1-based, closed）
│   ├── end                UINT32 [n_cpg]   结束位置（1-based, closed）
│   ├── width              UINT32 [n_cpg]   区间宽度 = end - start + 1
│   └── strand             STRING [n_cpg]   链（+/-）
├── /colData/
│   ├── sample_id          STRING [n_sample]
│   └── sample_name        STRING [n_sample]
└── /metadata/
    ├── genome             STRING  参考基因组名称（如 "hg19"）
    ├── schema_name        STRING  "methx.custom-hdf5"
    ├── schema_version     STRING  "1.0.0"
    ├── loader_compatibility STRING 兼容性声明（rhdf5 直接读取；
    │                              非 load_HDF5_methrix 目录）
    └── is_h5              BOOL    HDF5 格式标志
```

矩阵按 1 MiB 目标块大小分块并做 GZIP 压缩；写出采用临时文件 + 原子替换。

## 坐标契约

- 内部 CpG 提取与对齐使用 0-based 坐标；
- **写入 HDF5 时转换为 1-based closed**（`start = 内部 start + 1`，
  见 `write_rowdata` 中的 `checked_add(1)`）；
- 因此 R 中 `h5read(..., "/rowData/start")` 得到的即为 R/GRanges 习惯的
  1-based 坐标，**无需再 +1**。

| 阶段 | 坐标系 |
| --- | --- |
| FASTA CpG 提取、内部处理 | 0-based |
| Bismark `.cov` 输入 | 1-based（读取时转为内部 0-based） |
| **HDF5 存储（本文件）** | **1-based closed** |
| R 读取 | 1-based（原样使用） |

## CpG 唯一 ID

文件不包含专门的 `cpg_id` 字段；可用坐标构造：

```r
cpg_id <- paste0(chr, ":", start, "-", end)
```

## R 读取与转换

- 直接读取：`rhdf5::h5read()` 按上表 dataset 路径访问。
- 原生 Methrix：使用 `scripts/export_methrix_hdf5.R`，见
  [R_METHRIX_COMPATIBILITY_GUIDE.md](R_METHRIX_COMPATIBILITY_GUIDE.md)。
