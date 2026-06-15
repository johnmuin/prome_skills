# Kraken2 通用分析流程

分步式 Kraken2 分类 → Bracken 丰度重加权 → L1~L8 层级丰度表。
参考 [VIRGO2/virgo2_analysis](../../VIRGO2/virgo2_analysis) 的 step + config 模式,可复用到不同项目与不同 Kraken2 库。

## 文件结构

```
kraken2_flow/
├── config_template.sh          # 配置文件模板(拷为 config.sh 再改)
├── mpa2levels_standalone.py    # mpa → L1~L8 拆表(Python 版, 无 R 依赖)
├── step0_trim.sh               # 截断 / 软链
├── step1_kraken2.sh            # kraken2 分类(支持本地并发)
├── step2_bracken.sh            # bracken 丰度重加权
├── step3_kreport2mpa.sh        # kreport -> mpa
├── step4_mpa2levels.sh         # mpa -> L1~L8 (per sample)
├── step5_combine.sh            # 合并多样本 -> L1~L8
├── run_all.sh                  # 一键跑全
└── README.md
```

## 快速开始

### 1. 复制配置并修改

```bash
cd /Users/dreamingxu/apps/kraken2_flow
cp config_template.sh config.sh
vim config.sh   # 改 KRAKEN2_DB / PROJECT_DIR / INPUT_DIR 等
```

必须改的 3 项:

```bash
export KRAKEN2_DB="/path/to/your/kraken2_db"     # 库根目录
export BRACKEN_READ_LEN="100"                    # 跟库内 database*mers.kmer_distrib 对齐
export PROJECT_DIR="/path/to/your/project"       # 项目根
export INPUT_DIR="${PROJECT_DIR}/quality"        # 含 *.rmhost_R{1,2}.fastq.gz
```

### 2. 准备样品列表(可选)

留空 `SAMPLE_LIST` 时,自动扫 `INPUT_DIR` 下所有 `*.rmhost_R1.fastq.gz`。
若要指定子集:

```bash
export SAMPLE_LIST="${PROJECT_DIR}/samples.txt"
```

### 3. 跑

```bash
# 一键跑全
bash run_all.sh config.sh

# 或分步(可重跑已完成的样品, 会自动 skip)
bash step0_trim.sh       config.sh
bash step1_kraken2.sh    config.sh
bash step2_bracken.sh    config.sh
bash step3_kreport2mpa.sh config.sh
bash step4_mpa2levels.sh config.sh
bash step5_combine.sh    config.sh
```

## 关键参数

| 参数 | 默认 | 含义 |
|---|---|---|
| `KRAKEN2_DB` | 必填 | 库根目录, 含 `hash.k2d` `taxo.k2d` `opts.k2d` `database*mers.kmer_distrib` |
| `BRACKEN_READ_LEN` | 必填 | 必须与库内 `database*mers.kmer_distrib` 的 mers 一致 |
| `TRIM_LEN` | 100 | 截断长度, 0=跳过截断 |
| `TRIM_REGION` | `1:${TRIM_LEN}` | seqkit region 语法 |
| `BRACKEN_LEVEL` | S | S/G/F/O/C/P/D |
| `BRACKEN_THRESHOLD` | 10 | bracken 最低 read 数阈值 |
| `MAX_PARALLEL` | 4 | step1 本地并发样品数, 1=串行 |
| `THREADS` | 16 | 每个样品的 kraken2 线程 |
| `KRAKEN2_USE_MM` | 1 | 1=--memory-mapping (大库友好) |
| `KRAKEN2_USE_NAMES` | 1 | 1=--use-names (kreport 显示完整 lineage) |
| `KRAKEN2_CONFIDENCE` | 0.1 | kraken2 分类置信度 |

## 切换到其他 kraken2 库(常见场景)

例如换 NCBI nt 库(假设已有 nt 的 kmer distribution):

```bash
# 1. 复制 config.sh(项目相关)
cp config.sh config_nt.sh

# 2. 改 3 处
export KRAKEN2_DB="/path/to/nt_db"
export BRACKEN_READ_LEN="150"   # 跟 nt 的 database150mers.kmer_distrib 对齐
export TRIM_LEN="150"            # 如果 reads 是 150bp 可不截; 或按需

# 3. 换输出目录, 避免与原库混
export OUTDIR="${PROJECT_DIR}/kraken2_nt"

# 4. 跑
bash run_all.sh config_nt.sh
```

## conda 环境

最小依赖: `kraken2 / bracken / seqkit / python(>=3.8) / KrakenTools(kreport2mpa.py + combine_mpa.py)`

```bash
mamba create -n kraken2.1.2 -c bioconda -c conda-forge \
    kraken2 bracken seqkit python
```

## 输出结构

```
${OUTDIR}/
├── trim${TRIM_LEN}/                    # Step 0: 截断/软链后的 fastq
├── kraken2/                            # Step 1: kraken2 输出
│   ├── ${sample}.kraken2
│   └── ${sample}.kreport2
├── bracken/                            # Step 2
│   ├── ${sample}.bracken
│   └── ${sample}.bracken.kreport
├── mpa/                                # Step 3
│   └── ${sample}.mpa
├── profile/${sample}/                  # Step 4
│   └── L{1..8}.txt
├── combined/                           # Step 5
│   ├── bracken.mpa                     # 所有样品的 mpa 合并
│   └── profile/L{1..8}.txt             # 所有样品并列的层级表
└── logs/
    └── ${sample}.{trim,kraken2,bracken,kreport2mpa,mpa2levels}.log
```

## 故障排除

### 1. 缺 `database${BRACKEN_READ_LEN}mers.kmer_distrib`

库与 BRACKEN_READ_LEN 不匹配。

```bash
ls ${KRAKEN2_DB}/database*mers.kmer_distrib
# 选对应的数字
```

### 2. Step 0 报 fastq 找不到

`get_samples()` 默认扫 `*.rmhost_R1.fastq.gz`。命名不是这个, 就写 `SAMPLE_LIST`。

### 3. Step 1 报 hash.k2d 找不到

库目录写错;或 `KRAKEN2_DB` 应该是目录不是 `*.k2d` 自身。

### 4. step5_combine 报 0 个 mpa

step3 没跑 / 全失败, 检查 `${OUTDIR}/mpa/`。
