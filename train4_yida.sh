#!/bin/bash
# 批量训练 yida 医生数据的脚本
# 对 dataset/csv/doctor_* 中的每个医生，依次执行 make-dataset 和 SFT 训练。
#
# 用法:
#   ./train4_yida.sh [MIN_MESSAGES]
#   可选参数 MIN_MESSAGES: 跳过消息数低于此值的医生（默认 50）
#
# 环境依赖:
#   - WeClone 虚拟环境: .venv
#   - 配置文件模板: settings3.jsonc
#   - 数据已由 scripts/process_yida_data.py 预处理好

set -e

cd /root/siton-data-xinxi/workspace/WeClone

# ── 配置 ──────────────────────────────────────────────────────────────────
CONFIG_TEMPLATE="settings3.jsonc"
CONFIG_NAME="settings_yida.jsonc"
MIN_MSGS="${1:-50}"
DS_CONFIG="ds_config.json"

# ── 激活虚拟环境 ──────────────────────────────────────────────────────────
source .venv/bin/activate

# ── 准备统一配置文件 ──────────────────────────────────────────────────────
if [ ! -f "$CONFIG_NAME" ]; then
    echo "Copying $CONFIG_TEMPLATE to $CONFIG_NAME as training config..."
    cp "$CONFIG_TEMPLATE" "$CONFIG_NAME"
fi

# ── 收集待处理的医生 ──────────────────────────────────────────────────────
DOCTOR_DIRS=()
for d in dataset/csv/doctor_*; do
    [ -d "$d" ] || continue
    DOCTOR_DIRS+=("$d")
done

if [ ${#DOCTOR_DIRS[@]} -eq 0 ]; then
    echo "No doctor directories found under dataset/csv/doctor_*"
    echo "Please run: python scripts/process_yida_data.py first."
    exit 1
fi

# ── 将除第一个医生外的所有医生目录移到 staging 区 ──────────────────────────
# 避免 weclone-cli make-dataset 误处理多个医生的数据
STAGING_DIR="dataset/csv_staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 先移动所有医生目录到 staging
echo "Moving ${#DOCTOR_DIRS[@]} doctor dirs to staging area..."
for DOCTOR_DIR in "${DOCTOR_DIRS[@]}"; do
    DOCTOR_NAME=$(basename "$DOCTOR_DIR")
    mv "$DOCTOR_DIR" "$STAGING_DIR/$DOCTOR_NAME"
done

echo "========================================================="
echo "Found ${#DOCTOR_DIRS[@]} doctor(s) to process"
echo "Minimum message threshold: $MIN_MSGS"
echo "========================================================="

# ── 逐个医生处理 ──────────────────────────────────────────────────────────
PROCESSED=0
SKIPPED=0

for DOCTOR_DIR_STAGED in "$STAGING_DIR"/doctor_*; do
    [ -d "$DOCTOR_DIR_STAGED" ] || continue

    DOCTOR_NAME=$(basename "$DOCTOR_DIR_STAGED")
    DATA_FILE="$DOCTOR_DIR_STAGED/data.csv"

    if [ ! -f "$DATA_FILE" ]; then
        echo "Skipping $DOCTOR_NAME: no data.csv found"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # 检查消息数量
    MSG_COUNT=$(tail -n +2 "$DATA_FILE" | wc -l)
    if [ "$MSG_COUNT" -lt "$MIN_MSGS" ]; then
        echo "Skipping $DOCTOR_NAME: $MSG_COUNT messages (threshold: $MIN_MSGS)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo ""
    echo "========================================================="
    echo "  Doctor: $DOCTOR_NAME  ($MSG_COUNT messages)"
    echo "========================================================="

    # ── 1. 将当前医生目录移回 dataset/csv/ ──────────────────────────────────
    echo "[1/4] Preparing CSV data for make-dataset..."
    mv "$DOCTOR_DIR_STAGED" "dataset/csv/$DOCTOR_NAME"

    # ── 2. 生成 QA 数据集 ─────────────────────────────────────────────────
    echo "[2/4] Running make-dataset..."
    export WECLONE_CONFIG_PATH="$CONFIG_NAME"
    weclone-cli make-dataset

    # ── 3. 缓存生成的 SFT JSON ────────────────────────────────────────────
    echo "[3/4] Caching SFT dataset..."
    mkdir -p ./dataset/res_csv/sft
    cp ./dataset/res_csv/sft/sft-my.json "./dataset/res_csv/sft/sft_${DOCTOR_NAME}.json"

    # ── 4. 开始 SFT 训练 ──────────────────────────────────────────────────
    echo "[4/4] Starting SFT training for $DOCTOR_NAME..."

    cp "./dataset/res_csv/sft/sft_${DOCTOR_NAME}.json" "./dataset/res_csv/sft/sft-my.json"

    sed -i -E "s|\"adapter_name_or_path\":.*|\"adapter_name_or_path\": \"./output/${DOCTOR_NAME}\",|g" "$CONFIG_NAME"

    export WECLONE_CONFIG_PATH="$CONFIG_NAME"
    deepspeed --num_gpus=8 weclone/train/train_sft.py

    echo "Training finished for $DOCTOR_NAME, model saved to ./output/${DOCTOR_NAME}"

    # ── 训练完后移回 staging ──────────────────────────────────────────────
    mv "dataset/csv/$DOCTOR_NAME" "$STAGING_DIR/$DOCTOR_NAME"

    PROCESSED=$((PROCESSED + 1))
done

# ── 清理：将 staging 中的目录移回 dataset/csv/ ──────────────────────────────
echo ""
echo "Restoring doctor dirs from staging..."
mv "$STAGING_DIR"/doctor_* dataset/csv/ 2>/dev/null || true
rmdir "$STAGING_DIR" 2>/dev/null || true

echo ""
echo "========================================================="
echo "All done! Processed: $PROCESSED, Skipped: $SKIPPED"
echo "========================================================="
