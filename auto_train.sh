#!/bin/bash
# AutoResearch 自动训练和推送脚本
# 每30分钟运行一次

set -e

cd /home/xj/Desktop/xj_code/autoresearch

# 获取当前时间戳
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="logs/auto_train_${TIMESTAMP}.log"

# 创建日志目录
mkdir -p logs

echo "========================================" | tee -a "$LOG_FILE"
echo "🚀 自动训练开始: $(date)" | tee -a "$LOG_FILE"
echo "========================================" | tee -a "$LOG_FILE"

# 检查是否有训练正在运行
if pgrep -f "train_light.py" > /dev/null; then
    echo "⚠️  已有训练正在运行，跳过本次" | tee -a "$LOG_FILE"
    exit 0
fi

# 激活虚拟环境
echo "📦 激活虚拟环境..." | tee -a "$LOG_FILE"
source .venv_pip/bin/activate

# 运行训练
echo "🧠 开始训练..." | tee -a "$LOG_FILE"
python train_light.py 2>&1 | tee -a "$LOG_FILE"

# 检查训练是否成功
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ 训练完成" | tee -a "$LOG_FILE"
    
    # 提交结果到 git
    echo "📤 提交到 Git..." | tee -a "$LOG_FILE"
    git add -f results.tsv logs/
    git commit -m "Auto train: ${TIMESTAMP} - $(grep 'success' results.tsv | tail -1 | cut -f4-)" 2>/dev/null || true
    
    # 推送到 GitHub
    echo "☁️  推送到 GitHub..." | tee -a "$LOG_FILE"
    git push origin master 2>&1 | tee -a "$LOG_FILE"
    
    echo "✅ 完成: $(date)" | tee -a "$LOG_FILE"
else
    echo "❌ 训练失败: $(date)" | tee -a "$LOG_FILE"
    # 记录失败但继续推送日志
    git add logs/
    git commit -m "Auto train failed: ${TIMESTAMP}" 2>/dev/null || true
    git push origin master 2>/dev/null || true
fi

echo "========================================" | tee -a "$LOG_FILE"
