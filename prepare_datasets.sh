#!/bin/bash
# 保存为 /root/siton-data-xinxi/workspace/WeClone/prepare_datasets.sh

cd /root/siton-data-xinxi/workspace/WeClone

# 1. 首先执行你自定义的原始 txt 转 csv 分割逻辑
python scripts/process_data.py

# 把新生成的按客服名切分的目录移入 csv_all 统一管理
mkdir -p dataset/csv_all
mv dataset/csv/waiter_* dataset/csv_all/ 2>/dev/null

for WAITER_DIR in dataset/csv_all/waiter_*; do
    WAITER_NAME=$(basename "$WAITER_DIR")
    echo "================================================="
    echo "🤖 正在生成并缓存数据集: $WAITER_NAME"
    echo "================================================="
    
    # 准备环境：独占式存放该客服的原始 csv
    rm -rf dataset/csv/*
    cp -r "$WAITER_DIR" "dataset/csv/"
    
    # 为当前客服克隆并创建一个专属的配置文件，以后如果改动只需编辑这个特定文件
    CONFIG_NAME="settings_${WAITER_NAME}.jsonc"
    if [ ! -f "$CONFIG_NAME" ]; then
        cp settings.jsonc "$CONFIG_NAME"
        # 顺便把输出路径帮它填好
        sed -i -E "s|\"adapter_name_or_path\":.*|\"adapter_name_or_path\": \"./model_output_${WAITER_NAME}\",|g" "$CONFIG_NAME"
    fi
    
    # 注入环境变量，告知 WeClone 这次使用当前专属配置文件来跑数据
    export WECLONE_CONFIG_PATH="$CONFIG_NAME"
    
    weclone-cli make-dataset
    
    # 重要：原版工具由于写死了输出叫 sft-my.json，我们在这里执行完立刻把它另存(缓存)为一个带有不同名称的 json
    cp ./dataset/res_csv/sft/sft-my.json ./dataset/res_csv/sft/sft_${WAITER_NAME}.json
    
    echo "✅ $WAITER_NAME 的 QA 缓存切片成功存放为 sft_${WAITER_NAME}.json"
done

echo "🎉 所有数据集预生成完毕并已缓存下多份 json！"
