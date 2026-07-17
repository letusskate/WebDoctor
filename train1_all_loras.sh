#!/bin/bash

# 确保在 WeClone 目录下执行
cd /root/siton-data-xinxi/workspace/WeClone

# 将所有拆分的客服数据移出原目录，避免全部被合并读取
if [ ! -d "dataset/csv_all" ]; then
    mv dataset/csv dataset/csv_all
    mkdir -p dataset/csv
fi

for WAITER_DIR in dataset/csv_all/waiter_*; do
    WAITER_NAME=$(basename "$WAITER_DIR")
    echo "================================================="
    echo "🚀 开始处理并训练专属客服模型: $WAITER_NAME"
    echo "================================================="
    
    # 1. 独占式放置当前客服数据
    rm -rf dataset/csv/*
    cp -r "dataset/csv_all/$WAITER_NAME" "dataset/csv/"
    
    # 2. 修改 settings.jsonc 中的 adapter_name_or_path (保存 LoRA 权重的路径)
    # 利用 sed 匹配并替换，让其输出到 ./model_output_waiter_x
    sed -i -E "s|\"adapter_name_or_path\":.*|\"adapter_name_or_path\": \"./model_output_${WAITER_NAME}\", // 当前${WAITER_NAME}的模型训练输出目录|g" settings.jsonc
    
    echo "🤖 正在生成 $WAITER_NAME 的微调数据集..."
    weclone-cli make-dataset
    
    echo "🔥 正在开始使用 DeepSpeed 多卡训练 $WAITER_NAME 的 LoRA 权重..."
    # 使用 deepspeed 进行 8 卡训练
    deepspeed --num_gpus=8 weclone/train/train_sft.py
    
    echo "✅ $WAITER_NAME 处理完成！模型将保存在 ./model_output_${WAITER_NAME}"
    echo ""
done
