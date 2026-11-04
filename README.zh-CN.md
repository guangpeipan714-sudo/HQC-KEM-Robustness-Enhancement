# HQC-KEM 随机源退化鲁棒性研究

[English README](README.md)

本仓库配套《面向随机源退化的HQC-KEM多源随机材料融合与密钥上下文绑定方法》。研究使用缩减规模的 SageMath 原型，比较直接 SHAKE256 融合和加入 Q64 定点 Logistic 预扩散的路径在模拟偏置、序列相关性和小支持输入下的表现。

独立副输入承担主源退化时的条件不可预测性前提。Q64 是确定性非线性预扩散，SHAKE256 融合随机材料，公开转录本提供密钥上下文绑定。安全分析采用经典随机预言机模型和文中列出的碰撞界前提。实证结果适用于所测原型和输入模型，两条融合路径的相对表现随输入分布变化。

## 目录与历史版本

| 目录 | 内容 |
|---|---|
| `src/`、`experiments/` | 已发布的 SageMath 核心实现及历史实验入口 |
| `matlab/`、`results/` | 历史数据、统计及绘图脚本 |
| `data/` | 现稿数据、出处和校验值 |
| `scripts/reproduction/` | 已有数据核验和英文图导出 |
| `docs/` | 环境、出处及复现说明 |

当前稿的图 6 使用五批配对数据。图 11、12 来自历史 MAT 文件，经 CSV 逐值核对。历史 release 数据按原版本保存，具体区别见[历史版本说明](RELEASE_NOTES_v1.2.0.md)。

## 用已有数据复现

在 Python 3.13 环境运行：

```sh
python -m pip install -r requirements.txt
python scripts/reproduction/reproduce.py --output-dir repro-output
```

输出目录须为新目录。命令校验归档文件的 SHA-256，导出图 4、6、11、12 的 PDF、SVG 和 PNG，并从存档输出重算 Markov pilot 统计。数据出处和复现范围见[数据说明](docs/data_provenance.md)。历史 Sage 入口和 MATLAB 绘图另见[环境说明](docs/environment.md)和[复现文档](docs/reproducibility.md)。

## 引用和许可

引用信息见 [CITATION.cff](CITATION.cff)，已发布软件的版本记录见 [Zenodo](https://doi.org/10.5281/zenodo.23309601)。原仓库保留 [MIT 许可证](LICENSE)。
