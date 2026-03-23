# 🚀 AutoResearch on DGX Spark (GB10) - 轻量级指南

## 你的硬件配置

| 组件 | 规格 |
|------|------|
| GPU | NVIDIA GB10 (Blackwell, CC 12.1) |
| 显存 | 24GB 统一内存 |
| 系统内存 | 128GB LPDDR5x |
| CUDA | 12.8 |

## 对比：原版 vs 轻量版

| 参数 | 原版 (H100) | 轻量版 (GB10) | 说明 |
|------|-------------|---------------|------|
| `MAX_SEQ_LEN` | 2048 | **512** | 序列长度减少到 1/4 |
| `DEPTH` | 8 | **4** | 模型层数减半 |
| `ASPECT_RATIO` | 64 | **32** | 模型维度减半 |
| `HEAD_DIM` | 128 | **64** | 注意力头维度减半 |
| `TOTAL_BATCH_SIZE` | ~524K | **~65K** | batch 减少到 1/8 |
| `DEVICE_BATCH_SIZE` | 128 | **32** | 每设备 batch 减少 |
| `WINDOW_PATTERN` | "SSSL" | **"L"** | 更简单的注意力模式 |
| `EVAL_TOKENS` | ~21M | **~5M** | 评估数据减少 |
| **模型参数量** | ~50M | **~6M** | 约 1/8 参数 |
| **显存占用** | ~45GB | **~6GB** | 适合 24GB 显存 |
| **训练速度** | 基准 | **更慢但可行** | GB10 算力低于 H100 |

## 快速开始

### 1. 环境准备

```bash
cd /home/xj/Desktop/xj_code/autoresearch

# 安装 uv (如果还没有)
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc

# 安装依赖
uv sync
```

### 2. 数据准备（轻量版）

```bash
./run_light.sh prepare
```

这会下载 5 个数据 shard（约 5GB）并训练 tokenizer。

### 3. 单次测试运行

```bash
./run_light.sh train
```

预期输出：
```
Vocab size: 8,192
Model config: {'sequence_len': 512, 'vocab_size': 8192, 'n_layer': 4, ...}
Parameter counts:
  wte                     : 4,194,304
  value_embeds            : 2,097,152
  lm_head                 : 4,194,304
  transformer_matrices    : 12,582,912
  scalars                 : 8
  total                   : 23,068,680  (~23M 参数)
...
step 00100 (30.0%) | loss: 6.5xxxx | ...
---
val_bpb:          2.xxxxxx
training_seconds: 300.x
peak_vram_mb:     4500.0
...
```

### 4. 启动自主研究

```bash
# 设置实验分支
./run_light.sh experiment

# 启动你的 AI Agent (Claude/Cursor/Continue)
# 然后输入：
# "Read program.md and let's start experimenting with train_light.py!"
```

## 手动运行实验循环

如果你想手动测试：

```bash
# 1. 创建分支
git checkout -b autoresearch/gb10-test

# 2. 初始化结果表
echo -e "commit\tval_bpb\tmemory_gb\tstatus\tdescription" > results.tsv

# 3. 修改 train_light.py（尝试某个想法）
# 比如：改学习率、改激活函数等

# 4. 提交修改
git add train_light.py
git commit -m "尝试增加学习率"

# 5. 运行实验
uv run train_light.py > run.log 2>&1

# 6. 检查结果
grep "^val_bpb:" run.log
# 或者看完整输出
tail -20 run.log

# 7. 记录结果到 results.tsv
# 格式: commit_hash  val_bpb  memory_gb  status  description
# 例: a1b2c3d  2.345678  4.5  keep  增加学习率到 0.05

# 8. 如果结果好，保留；否则回滚
# git reset --hard HEAD~1  # 丢弃
# 或者继续下一步实验
```

## 参数调整建议

### 如果遇到 OOM（显存不足）

进一步减小这些参数：

```python
# train_light.py
DEVICE_BATCH_SIZE = 16   # 从 32 降到 16
# 或
DEPTH = 3                # 从 4 降到 3
```

### 如果想更快训练

减小时间预算（用于快速测试）：

```python
# prepare_light.py
TIME_BUDGET = 60  # 1分钟（仅测试用）
```

### 如果想训练更大的模型

GB10 可以支持到约 100M 参数：

```python
# 尝试这些配置
DEPTH = 6
ASPECT_RATIO = 48
MAX_SEQ_LEN = 1024
```

## 使用 TinyStories 数据集（可选）

如果你想用更简单的数据集（Karpathy 推荐用于小模型）：

修改 `prepare_light.py`：

```python
# 第 41 行左右
BASE_URL = "https://huggingface.co/datasets/karpathy/tinystories-gpt4-clean/resolve/main"
MAX_SHARD = 100  # TinyStories 数据更少
```

## 常见问题

### Q: GB10 比 H100 慢多少？
A: GB10 是桌面级芯片，算力约为 H100 的 1/10~1/20。但实验理念相同，只是跑得慢一些。

### Q: 可以运行原版配置吗？
A: 不可以，原版需要 45GB+ 显存，GB10 只有 24GB。必须用轻量版。

### Q: 实验结果能和 H100 对比吗？
A: 不能直接对比。Karpathy 设计的就是**固定时间预算**，不同硬件的结果只在自己平台上可比。

### Q: 一晚上能跑多少个实验？
A: GB10  slower，可能 6-8 个实验/小时，一晚约 50-60 个（H100 约 100 个）。

## 下一步

1. 运行 `./run_light.sh prepare` 准备数据
2. 运行 `./run_light.sh train` 测试单次训练
3. 启动 AI Agent 开始自主研究！

祝你研究愉快！🔬
