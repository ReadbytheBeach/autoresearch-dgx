# 📋 `run_light.sh` 命令详解指南

> AutoResearch Light Mode for DGX Spark (GB10) - 命令工作原理详解

---

## 🔹 命令 1: `./run_light.sh prepare`

### 作用
**一次性数据准备** — 下载训练数据并训练 Tokenizer

### 执行的代码
```bash
uv run prepare_light.py --num-shards 5
```

### 详细流程

| 步骤 | 动作 | 输出 |
|------|------|------|
| **1. 创建缓存目录** | `~/.cache/autoresearch/` | 数据存储位置 |
| **2. 下载数据** | 从 HuggingFace 下载 5 个 shard | `shard_00000.parquet` ~ `shard_00004.parquet` |
| **3. 训练 Tokenizer** | 使用 rustbpe 训练 BPE | `tokenizer.pkl` |
| **4. 构建 lookup** | 创建 token_bytes 映射 | `token_bytes.pt` |

### 数据详情

```python
# 数据来源
BASE_URL = "https://huggingface.co/datasets/karpathy/climbmix-400b-shuffle/resolve/main"

# 下载的文件 (约 1GB each)
shard_00000.parquet
shard_00001.parquet
shard_00002.parquet
shard_00003.parquet
shard_00004.parquet
shard_06542.parquet  # 验证集 (自动下载)

# 轻量版修改参数
MAX_SEQ_LEN = 512        # 序列裁剪到 512 tokens
EVAL_TOKENS = 5M         # 评估只用 500 万 tokens
```

### Tokenizer 训练过程

```
原始文本 → rustbpe 训练 → 8,192 个 token 的词表
            ↓
    ┌─────────────────┐
    │  GPT-4 风格分词  │
    │  - 字母: "Hello" │
    │  - 数字: "42"    │
    │  - 标点在词内    │
    └─────────────────┘
```

### 预期输出

```
=== AutoResearch Light: Data Preparation ===
MAX_SEQ_LEN: 512, Using light config...
Cache directory: /home/xj/.cache/autoresearch

Data: downloading 5 shards (0 already exist)...
  Downloaded shard_00000.parquet
  Downloaded shard_00001.parquet
  Downloaded shard_00002.parquet
  Downloaded shard_00003.parquet
  Downloaded shard_00004.parquet

Tokenizer: training BPE tokenizer...
Tokenizer: trained in 12.5s, saved to ~/.cache/autoresearch/tokenizer/tokenizer.pkl
Tokenizer: saved token_bytes to ~/.cache/autoresearch/tokenizer/token_bytes.pt
Tokenizer: sanity check passed (vocab_size=8192)

Done! Ready to train.
```

### ⚠️ 注意事项

| 注意点 | 说明 |
|--------|------|
| **只需运行一次** | 数据会缓存，重复运行会跳过已下载的文件 |
| **磁盘占用** | 约 6GB（5 个训练 shard + 1 个验证 shard） |
| **网络要求** | 需要访问 HuggingFace（可能需要代理） |
| **时间** | 约 5 分钟（取决于网速） |

---

## 🔹 命令 2: `./run_light.sh train`

### 作用
**运行单次 5 分钟训练实验** — 用于测试配置和获取基线

### 执行的代码
```bash
uv run train_light.py
```

### 执行步骤详解

```
┌─────────────────────────────────────────────────────────────┐
│  1. 环境初始化                                               │
│     - 设置 PyTorch 分配器                                    │
│     - 禁用 HuggingFace 进度条                                 │
│     - 设置随机种子 42                                         │
├─────────────────────────────────────────────────────────────┤
│  2. 加载 Flash Attention 3                                   │
│     - 检测 GPU: GB10 (CC 12.1)                               │
│     - 使用 kernels-community/flash-attn3                     │
├─────────────────────────────────────────────────────────────┤
│  3. 构建模型                                                 │
│     - DEPTH=4 → 4 层 Transformer                             │
│     - model_dim = 4 * 32 = 128                               │
│     - num_heads = 128 / 64 = 2                               │
│     - 参数量: ~23M                                           │
├─────────────────────────────────────────────────────────────┤
│  4. 初始化优化器 (MuonAdamW)                                  │
│     - lm_head:     lr=0.004  (AdamW)                        │
│     - embeddings:  lr=0.6    (AdamW)                        │
│     - matrices:    lr=0.04   (Muon)                         │
│     - scalars:     lr=0.5    (AdamW)                        │
├─────────────────────────────────────────────────────────────┤
│  5. 编译模型                                                 │
│     - torch.compile(dynamic=False)                           │
│     - 生成 CUDA graph 优化                                   │
├─────────────────────────────────────────────────────────────┤
│  6. 训练循环 (5分钟)                                          │
│     while training_time < 300s:                              │
│         - 前向传播 → 反向传播                                 │
│         - 梯度累积 2048 steps                                │
│         - 更新学习率调度                                      │
│         - 打印进度日志                                        │
├─────────────────────────────────────────────────────────────┤
│  7. 最终评估                                                 │
│     - 在验证集上计算 val_bpb                                 │
│     - 输出最终指标                                            │
└─────────────────────────────────────────────────────────────┘
```

### 模型配置（轻量版）

```python
# train_light.py 中的参数
DEPTH = 4                # 4 层
ASPECT_RATIO = 32        # 模型维度系数
HEAD_DIM = 64            # 每头维度 64

# 计算得到的实际配置
sequence_len = 512       # 序列长度
vocab_size = 8192        # 词表大小
n_layer = 4              # 层数
n_head = 2               # 注意力头数 (128/64)
n_embd = 128             # 嵌入维度 (4*32=128, 对齐到 64 的倍数)
```

### 训练进度输出示例

```
Vocab size: 8,192
Model config: {'sequence_len': 512, 'vocab_size': 8192, 'n_layer': 4, 'n_head': 2, ...}
Parameter counts:
  wte                     : 4,194,304
  value_embeds            : 2,097,152
  lm_head                 : 4,194,304
  transformer_matrices    : 12,582,912
  scalars                 : 8
  total                   : 23,068,680
Estimated FLOPs per token: 1.23e+08

step 00000 (0.0%) | loss: 8.9xxxx | lrm: 0.00 | dt: 450ms | tok/sec: 145,000 | mfu: 12.3% | epoch: 1 | remaining: 300s
step 00050 (15.0%) | loss: 6.5xxxx | lrm: 1.00 | dt: 320ms | tok/sec: 203,000 | mfu: 17.2% | epoch: 1 | remaining: 255s
step 00100 (30.0%) | loss: 5.8xxxx | lrm: 1.00 | dt: 315ms | tok/sec: 206,000 | mfu: 17.5% | epoch: 2 | remaining: 210s
...
step 00300 (100.0%) | loss: 4.2xxxx | lrm: 0.50 | dt: 310ms | tok/sec: 210,000 | mfu: 17.8% | epoch: 5 | remaining: 0s

---
val_bpb:          2.456789        ← 关键指标！越低越好
training_seconds: 300.2
total_seconds:    325.5           ← 包含启动和编译时间
peak_vram_mb:     4500.0          ← 峰值显存占用 4.5GB
mfu_percent:      17.85           ← 模型 FLOPs 利用率
total_tokens_M:   19.5            ← 训练了 1950 万 tokens
num_steps:        300
depth:            4
```

### 关键指标解释

| 指标 | 含义 | 好/坏 |
|------|------|-------|
| `val_bpb` | 验证集 Bits Per Byte | **越低越好**（< 2.0 不错）|
| `peak_vram_mb` | 峰值显存占用 | < 24000 安全 |
| `mfu_percent` | GPU 利用率 | > 15% 正常 |
| `tok/sec` | 每秒处理 token 数 | 越高越好 |
| `loss` | 训练损失 | 持续下降说明在学习 |
| `lrm` | 学习率倍数 | warmup→1.0→warmdown |

---

## 🔹 命令 3: `./run_light.sh experiment`

### 作用
**设置自主研究环境** — 创建 Git 分支和结果记录表，为 AI Agent 实验做准备

### 执行步骤详解

#### 步骤 1: 创建 Git 分支

```bash
# 实际执行的命令
git checkout -b "autoresearch/light-$(date +%m%d)" 2>/dev/null || git checkout "autoresearch/light-$(date +%m%d)"
```

| 动作 | 说明 |
|------|------|
| `git checkout -b` | 创建并切换到新分支 |
| `autoresearch/light-0323` | 分支名格式：`autoresearch/<月日>`，例如 `autoresearch/light-0323` |
| `2>/dev/null` | 如果分支已存在，suppress 错误信息 |
| `|| git checkout` | 如果创建失败（分支已存在），则直接切换到已有分支 |

**分支命名规则**：
- `autoresearch/` 前缀 — 表明是实验分支
- `light-0323` — 轻量版 + 日期（3月23日）
- 可自定义添加 GPU 编号：`light-0323-gpu0`

#### 步骤 2: 初始化结果表

```bash
# 如果 results.tsv 不存在则创建
if [ ! -f results.tsv ]; then
  echo -e "commit\tval_bpb\tmemory_gb\tstatus\tdescription" > results.tsv
fi
```

创建 `results.tsv` 文件（Tab-Separated Values，制表符分隔）：

```
commit    val_bpb     memory_gb    status    description
a1b2c3d   2.456789    4.5          keep      baseline
b2c3d4e   2.398765    4.6          keep      increase LR to 0.05
c3d4e5f   2.567890    4.5          discard   change activation to GELU
d4e5f6g   0.000000    0.0          crash     OOM when depth=16
```

**各列含义**：

| 列名 | 内容 | 示例 | 说明 |
|------|------|------|------|
| `commit` | Git commit hash (短，7字符) | `a1b2c3d` | 实验代码版本 |
| `val_bpb` | 验证指标 | `2.456789` | Bits Per Byte，越低越好 |
| `memory_gb` | 峰值显存 (GB) | `4.5` | 峰值显存占用 |
| `status` | 实验结果 | `keep`/`discard`/`crash` | 是否保留修改 |
| `description` | 实验描述 | `increase LR to 0.05` | 人类可读的修改说明 |

### AI Agent 实验工作流（启动后）

```
┌─────────────────────────────────────────────────────────────────┐
│                    AI Agent 自主实验循环                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. 读取 program.md 和当前 train_light.py                      │
│      ↓                                                          │
│   2. 提出假设（如："增加学习率可能提升收敛"）                      │
│      ↓                                                          │
│   3. 修改代码（如：EMBEDDING_LR = 0.6 → 0.8）                    │
│      ↓                                                          │
│   4. git commit -m "increase embedding LR to 0.8"               │
│      ↓                                                          │
│   5. uv run train_light.py > run.log 2>&1                       │
│      ↓                                                          │
│   6. 解析结果                                                   │
│      - grep "^val_bpb:" run.log                                 │
│      - grep "^peak_vram_mb:" run.log                            │
│      ↓                                                          │
│   7. 记录到 results.tsv                                         │
│      例: abc1234  2.345  4.5  keep  increase embedding LR        │
│      ↓                                                          │
│   8. 决策                                                       │
│      ├─ val_bpb 降低 → 保留 (继续在此分支迭代)                   │
│      └─ val_bpb 升高 → 丢弃 (git reset --hard HEAD~1)           │
│      ↓                                                          │
│   9. 重复步骤 2-8（永不停止，直到人类干预）                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 预期输出

```
=== AutoResearch Light: Start Experiment Loop ===
Create branch: autoresearch/light-0323
Switched to a new branch 'autoresearch/light-0323'

Setup complete! Now start your AI Agent with:
  'Read program.md and start experimenting with train_light.py'

To run manually: uv run train_light.py
```

### ⚠️ 重要注意事项

| 注意点 | 说明 |
|--------|------|
| **不要 commit results.tsv** | 这个文件应该保持 untracked（不被 Git 跟踪） |
| **分支是实验历史** | 每个 `keep` 的 commit 都是有效改进，形成改进链 |
| **可以并行多分支** | 尝试不同方向：`light-lr`, `light-arch`, `light-optim` |
| **定时检查** | 即使让 AI 自主运行，也要定期查看 results.tsv |
| **永不停止** | AI Agent 会一直运行，直到你手动停止 |

---

## 📊 三命令关系图

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    prepare      │────▶│     train       │────▶│    experiment   │
│   (一次性准备)   │     │   (测试基线)     │     │  (启动自主研究)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
  下载数据 shard             运行 5 分钟              创建 Git 分支
  训练 Tokenizer            获取 val_bpb             初始化 results.tsv
  构建数据缓存              验证配置可行              准备 AI Agent 环境

  耗时: ~5 分钟             耗时: ~5 分钟            耗时: <1 秒
  频率: 仅一次              频率: 可多次              频率: 每轮实验系列一次
  必须性: 必需              必须性: 可选              必须性: 自主研究必需
```

---

## 🎯 实际使用示例

```bash
# 第 1 步：准备数据（只需一次）
./run_light.sh prepare
# 输出: Done! Ready to train.

# 第 2 步：测试运行（可选，验证配置）
./run_light.sh train
# 输出: val_bpb: 2.456789 ...

# 第 3 步：启动实验环境
./run_light.sh experiment
# 输出: Setup complete! ...

# 第 4 步：启动 AI Agent（在 VS Code/Cursor/Claude Code 中）
# 输入提示词: "Read program.md and let's start experimenting!"
```

---

## 📁 生成的文件结构

运行所有命令后，目录结构如下：

```
/home/xj/Desktop/xj_code/autoresearch/
├── prepare_light.py          # 轻量数据准备脚本
├── train_light.py            # 轻量训练脚本
├── run_light.sh              # 启动脚本
├── results.tsv               # 实验记录表（自动生成）
├── run.log                   # 最近一次运行日志（自动生成）
├── DGX_SPARK_GUIDE.md        # DGX Spark 使用指南
├── RUN_LIGHT_COMMANDS_GUIDE.md  # 本文件
│
└── ~/.cache/autoresearch/    # 数据缓存目录
    ├── data/
    │   ├── shard_00000.parquet
    │   ├── shard_00001.parquet
    │   ├── ...
    │   └── shard_06542.parquet  # 验证集
    └── tokenizer/
        ├── tokenizer.pkl
        └── token_bytes.pt
```

---

## 🔧 故障排除

### prepare 失败

| 问题 | 解决 |
|------|------|
| 下载超时 | 检查网络，或尝试使用代理 |
| 磁盘空间不足 | 确保有 10GB+ 可用空间 |
| rustbpe 错误 | 确保 uv sync 成功安装所有依赖 |

### train 失败

| 问题 | 解决 |
|------|------|
| OOM (显存不足) | 进一步减小 DEVICE_BATCH_SIZE 到 16 或 8 |
| CUDA 错误 | 检查 nvidia-smi，确保 GPU 可用 |
| 编译卡住 | torch.compile 首次较慢，耐心等待 |

### experiment 失败

| 问题 | 解决 |
|------|------|
| 分支已存在 | 这是正常的，脚本会自动切换 |
| git 错误 | 确保目录是 git 仓库：`git init` |
| 权限错误 | 确保对目录有写权限 |

---

> 祝你在 DGX Spark 上研究愉快！🔬
