#!/bin/bash
# AutoResearch Light Mode - 使用 pip + 镜像源（解决下载超时问题）
# 针对 DGX Spark (ARM64 + CUDA 13.0)

set -e

echo "=== AutoResearch Light: 使用 pip 安装（清华镜像）==="
echo ""

# 创建虚拟环境（如果不存在）
if [ ! -d ".venv_pip" ]; then
    echo "[1/3] 创建虚拟环境..."
    python3 -m venv .venv_pip
else
    echo "[1/3] 虚拟环境已存在"
fi

# 激活虚拟环境
source .venv_pip/bin/activate

# 升级 pip
echo "[2/3] 升级 pip..."
pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装 PyTorch（CUDA 12.8，兼容 CUDA 13.0）
echo "[3/3] 安装 PyTorch 和其他依赖..."
echo "（使用清华镜像 + PyTorch 官方源）"
echo ""

# 先安装 PyTorch 相关包
pip install torch==2.9.1 torchvision torchaudio \
    --index-url https://download.pytorch.org/whl/cu128 \
    --timeout 300 --retries 10

# 安装其他依赖
pip install \
    "kernels>=0.11.7" \
    "matplotlib>=3.10.8" \
    "numpy>=2.2.6" \
    "pandas>=2.3.3" \
    "pyarrow>=21.0.0" \
    "requests>=2.32.0" \
    "rustbpe>=0.1.0" \
    "tiktoken>=0.11.0" \
    -i https://pypi.tuna.tsinghua.edu.cn/simple \
    --timeout 300 --retries 10

echo ""
echo "✅ 安装完成！"
echo ""
echo "使用方法:"
echo "  source .venv_pip/bin/activate"
echo "  python prepare_light.py"
