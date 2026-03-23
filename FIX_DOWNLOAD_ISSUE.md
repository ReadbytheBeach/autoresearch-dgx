# 🔧 DGX Spark 下载超时问题修复指南

## 问题原因

在 ARM64 (aarch64) 架构的 DGX Spark 上，`uv` 下载 NVIDIA CUDA 包时出现超时：
- `nvidia_cusolver_cu12` 等包体积较大 (~100MB+)
- PyPI 官方源对 ARM64 支持较慢
- 网络连接不稳定

---

## ✅ 解决方案 1：使用 pip + 清华镜像（推荐）

```bash
cd /home/xj/Desktop/xj_code/autoresearch

# 使用新添加的命令
./run_light.sh prepare-pip
```

这会：
1. 创建 `.venv_pip` 虚拟环境
2. 使用清华镜像下载 Python 包
3. 从 PyTorch 官网下载 CUDA 12.8 版本的 PyTorch

---

## ✅ 解决方案 2：手动下载安装

如果自动下载仍然失败，可以手动下载：

```bash
# 1. 创建虚拟环境
python3 -m venv .venv_manual
source .venv_manual/bin/activate

# 2. 先安装不需要 CUDA 的包
pip install matplotlib numpy pandas pyarrow requests rustbpe tiktoken -i https://pypi.tuna.tsinghua.edu.cn/simple

# 3. 单独安装 PyTorch（使用官方源）
pip install torch==2.9.1 --index-url https://download.pytorch.org/whl/cu128

# 4. 安装 kernels（flash attention）
pip install kernels
```

---

## ✅ 解决方案 3：使用 conda（如果已安装）

```bash
# 如果你安装了 conda/Miniforge（ARM64 版本）
conda create -n autoresearch python=3.10
conda activate autoresearch

# 安装 PyTorch
conda install pytorch torchvision torchaudio pytorch-cuda=12.8 -c pytorch -c nvidia

# 安装其他依赖
pip install kernels matplotlib numpy pandas pyarrow requests rustbpe tiktoken
```

---

## ✅ 解决方案 4：增加超时时间（继续使用 uv）

```bash
# 设置环境变量增加超时
export UV_HTTP_TIMEOUT=300
export UV_PIP_TIMEOUT=300

# 然后重试
./run_light.sh prepare
```

---

## 📝 关于 CUDA 版本说明

你的系统：
- **CUDA 13.0** (nvidia-smi 显示)
- **ARM64/aarch64** 架构

PyTorch 安装：
- `cu128` = CUDA 12.8 版本
- **CUDA 向后兼容**：CUDA 12.x 可以在 CUDA 13.0 驱动上运行
- 这是正确的配置！

---

## 🚀 快速修复步骤

### 步骤 1：清理失败的环境
```bash
cd /home/xj/Desktop/xj_code/autoresearch
rm -rf .venv  # 删除失败的 uv 环境
```

### 步骤 2：使用 pip 方案
```bash
./run_light.sh prepare-pip
```

### 步骤 3：激活环境并运行
```bash
source .venv_pip/bin/activate
python prepare_light.py --num-shards 5
```

---

## ⚠️ 如果所有方案都失败

### 检查网络连接
```bash
# 测试网络
curl -I https://pypi.tuna.tsinghua.edu.cn/simple

# 测试 PyTorch 源
curl -I https://download.pytorch.org/whl/cu128/torch/
```

### 使用代理（如果需要）
```bash
export HTTP_PROXY=http://your-proxy:port
export HTTPS_PROXY=http://your-proxy:port
./run_light.sh prepare-pip
```

### 离线安装（最终方案）
1. 在其他机器下载 `.whl` 文件
2. 拷贝到 DGX Spark
3. `pip install xxx.whl`

---

## 💡 建议

对于 DGX Spark (ARM64)：**推荐方案 1 或 3**

ARM64 架构的 PyTorch 预编译包较大，使用国内镜像或 conda 可以显著改善下载体验。
