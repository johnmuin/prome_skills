# VIRGO2 通用分析流程

## 文件结构

```
virgo2_analysis/
├── config_template.sh          # 配置文件模板
├── config.sh                   # 你的项目配置（从模板复制修改）
├── step1_merge.sh              # Step 1: 合并reads
├── step2_map_local.sh          # Step 2a: map比对（本地）
├── step2_map_parallel.sh       # Step 2a: map比对（本地并行）
├── step2_map_sge.sh   # Step 2b: map比对（SGE模板）
├── step3_compile.sh            # Step 3: 合并结果
├── step4_taxonomy.sh           # Step 4: 物种分析
├── step5_annotate.sh           # Step 5: 添加注释
├── merge_annotations.py        # 注释合并Python脚本
└── README.md                   # 本文件
```

## 快速开始

### 1. 复制配置文件并修改

```bash
cd virgo2_analysis
cp config_template.sh config.sh
vim config.sh  # 修改项目路径等参数
```

需要修改的关键参数：
```bash
PROJECT_DIR="/your/project/path"        # 项目根目录
INPUT_DIR="${PROJECT_DIR}/quality"      # 输入fastq目录
VIRGO2_OUTDIR="${PROJECT_DIR}/virgo2"   # 输出目录
```

### 2. 运行分析步骤

```bash
# Step 1: 合并reads
bash step1_merge.sh config.sh

# Step 2: map比对（选择一种方式）

# 方式A: 本地运行（适合少量样品）
bash step2_map_local.sh config.sh

# 方式A2: 本地并行运行（适合大量样品）
bash step2_map_parallel.sh config.sh

# 方式B: SGE集群（适合大量样品）
# 先批量提交
ls merged_reads/*.merged.fastq.gz | while read f; do
    sample=$(basename $f .merged.fastq.gz)
    qsub -v SAMPLE=${sample} step2_map_sge.sh
done

# Step 3: 合并所有样品
bash step3_compile.sh config.sh

# Step 4: 物种组成分析
bash step4_taxonomy.sh config.sh

# Step 5: 添加功能注释（可选）
bash step5_annotate.sh config.sh
```

## 配置文件参数说明

### 路径配置
- `VIRGO2_DIR`: VIRGO2安装目录
- `PROJECT_DIR`: 你的项目根目录
- `INPUT_DIR`: 输入fastq文件目录（通常是质控/去宿主后）
- `VIRGO2_OUTDIR`: VIRGO2分析输出目录
- `SAMPLE_LIST`: 可选，指定样品列表文件

### 分析参数
- `THREADS`: 线程数（默认8）
- `MAP_COV`: 1=使用coverage校正，0=不使用
- `MAP_THREADS`: 单个样品 map 使用的线程数
- `MAX_MAP_JOBS`: 本地并发的样品数
- `TAX_BACTERIA`: 1=仅细菌，0=所有域（包括真菌）
- `TAX_FILTER`: 1=过滤低丰度，0=不过滤

### SGE配置
- `SGE_QUEUE`: SGE队列名
- `SGE_VF`: 虚拟内存
- `SGE_P`: CPU数

## 输入文件要求

### 输入文件命名
默认期望的输入格式：
```
${INPUT_DIR}/${sample}.rmhost_R1.fastq.gz
${INPUT_DIR}/${sample}.rmhost_R2.fastq.gz
```

如果命名不同，修改 `config.sh` 中的 `get_samples` 函数。

### 样品列表
如果不想自动扫描，可以创建样品列表文件：
```bash
echo -e "Sample1\nSample2\nSample3" > samples.txt
```
然后在 `config.sh` 中设置：
```bash
SAMPLE_LIST="${PROJECT_DIR}/samples.txt"
```

## 输出文件

### Step 1
- `merged_reads/*.merged.fastq.gz` - 合并后的单端fastq

### Step 2
- `map_results/*.out` - 基因计数结果
- `map_results/*.log` - 运行日志

### Step 3
- `compiled/VIRGO2_compiled.summary.NR.txt` - 合并表达矩阵

### Step 4
- `taxonomy/VIRGO2_taxonomy.relAbund.csv` - 物种组成表

### Step 5
- `annotation/VIRGO2_annotated_all_annotations.csv` - 带注释的表达矩阵

## 故障排除

### 1. 找不到输入文件
检查 `config.sh` 中的 `INPUT_DIR` 是否正确

### 2. conda环境错误
确保 `CONDA_BASE` 指向正确的miniconda安装路径

### 3. SGE提交失败
检查 `SGE_QUEUE` 和 `SGE_VF/P` 是否符合集群配置

## 迁移到新项目

1. 复制整个 `virgo2_analysis` 目录到新项目
2. 修改 `config.sh` 中的路径和参数
3. 运行步骤

不需要修改任何 step*.sh 脚本！
