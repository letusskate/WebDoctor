#!/bin/bash
# 批量训练指定客服列表的脚本，统一使用一个 settings3.jsonc 文件
# 当前所在位置: /root/siton-data-xinxi/workspace/WeClone/train3.sh

cd /root/siton-data-xinxi/workspace/WeClone

# 统一使用的配置文件名
CONFIG_NAME="settings3.jsonc"

# ==========================================================
# 在这里修改你要训练的客服列表 (空格分隔)
# ==========================================================
WAITERS=("waiter_0" "waiter_1" "waiter_2")

# 如果 settings3.jsonc 不存在，则自动去弄一份过来作为模板
if [ ! -f "$CONFIG_NAME" ]; then
    echo "⚠️ 找不到 $CONFIG_NAME，自动从 settings.jsonc 复制一份为主配置模板..."
    cp settings.jsonc "$CONFIG_NAME"
fi

for WAITER_NAME in "${WAITERS[@]}"; do
    echo "================================================="
    echo "🔥 正在使用 $CONFIG_NAME 训练: $WAITER_NAME"
    echo "================================================="

    if [ ! -f "./dataset/res_csv/sft/sft_${WAITER_NAME}.json" ]; then
        echo "❌ 找不到 ${WAITER_NAME} 的数据集缓存(sft_${WAITER_NAME}.json)！跳过当前人物..."
        continue
    fi

    # 1. 恢复当前循环所需的数据集为系统模型默认要求的名称 sft-my.json
    cp "./dataset/res_csv/sft/sft_${WAITER_NAME}.json" "./dataset/res_csv/sft/sft-my.json"

    # 2. 动态修改 settings3.jsonc 中的 adapter_name_or_path 为当前循环客服专属的输出目录
    # 这样就可以做到多次调用，但仅通过一个统一的 settings3.jsonc 文件来控制其它通用训练超参数
    sed -i -E "s|\"adapter_name_or_path\":.*|\"adapter_name_or_path\": \"./model_output_${WAITER_NAME}\",|g" "$CONFIG_NAME"

    # 3. 指定读取现在的统一配置
    export WECLONE_CONFIG_PATH="$CONFIG_NAME"

    # 4. 开始单独训练
    deepspeed --num_gpus=8 weclone/train/train_sft.py

    echo "✅ $WAITER_NAME 训练任务完成，模型已经保存在 ./model_output_${WAITER_NAME} 中！"
    echo ""
done

echo "🎉 ${WAITERS[*]} 的循环训练流转结束！"
