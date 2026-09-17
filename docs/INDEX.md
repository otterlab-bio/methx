# methx 文档索引

本文档只索引当前实现支持的契约。已废弃 schema、一次性调试记录、历史
SLURM 任务状态和旧兼容性报告不保留在仓库中。

## 用户文档

| 文档 | 内容 |
| --- | --- |
| [README.md](../README.md) | 项目概述、安装和主要命令 |
| [QUICKSTART.md](QUICKSTART.md) | 从 Bismark coverage 到 HDF5/QC 的快速流程 |
| [BUILD.md](BUILD.md) | 源码构建 |
| [HDF5_DEPENDENCY.md](HDF5_DEPENDENCY.md) | HDF5 构建期与运行时依赖边界 |

## 数据与 R 互操作契约

| 文档 | 内容 |
| --- | --- |
| [HDF5_STRUCTURE_AND_COORDINATES.md](HDF5_STRUCTURE_AND_COORDINATES.md) | `methx.custom-hdf5/1.0.0` datasets、类型和坐标 |
| [R_METHRIX_COMPATIBILITY_GUIDE.md](R_METHRIX_COMPATIBILITY_GUIDE.md) | `rhdf5` 直接读取及原生 Methrix 导出 |
| [`scripts/export_methrix_hdf5.R`](../scripts/export_methrix_hdf5.R) | 自定义 HDF5 到原生 Methrix 目录的唯一用户侧转换脚本 |

## 开发者文档

| 文档 | 内容 |
| --- | --- |
| [API.md](API.md) | Rust API 与 CLI 接口 |
| [DESIGN.md](DESIGN.md) | 架构与模块边界 |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | 当前实现摘要 |
| [ROADMAP.md](ROADMAP.md) | 后续计划；不构成当前功能承诺 |
| [GIT_WORKFLOW.md](GIT_WORKFLOW.md) | 仓库协作流程 |

## 事实来源

1. CLI 参数以 `src/main.rs` 的 Clap 定义为准；
2. HDF5 schema 以 `src/hdf5/se_compat.rs` 及其测试为准；
3. 用户侧原生 Methrix 转换只使用 `scripts/export_methrix_hdf5.R`；
4. roadmap 和开发期脚本不能覆盖上述运行时契约。
