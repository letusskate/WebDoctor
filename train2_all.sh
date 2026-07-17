#!/bin/bash

# 保存所有的待训练客服文件夹
mv WeClone/dataset/csv WeClone/dataset/csv_all
mkdir -p WeClone/dataset/csv

cd WeClone

for WAITER_DIR in dataset/csv_all/waiter_*; do
    WAITER_NAME=$(basename $WAITER_DIR)
    echo "=========================================="
    echo "开始处理并训练 $WAITER_NAME ..."
    echo "=========================================="
    
    # 清空并只放置当前客服的数据
    rm -rf dataset/csv/*
    cp -r ../WeClone/$WAITER_DIR dataset/csv/
    
    # 修改 settings.jsonc 中的 adapter_name_or_path (输出目录)
    # 替换 "./model_output" 为 "./model_output_waiter_x"
    sed -i "s|.*\"adapter_name_or_path\".*|\"adapter_name_or_path\": \"./model_output_${WAITER_NAME}\", //同时做为train_sft_args的output_dir|g" settings.jsonc
    
    # 构建当前客服的数据集
    weclone-cli make-dataset
    
    # 训练当前客服的模型
    # weclone-cli train-sft # 等你确认后再跑，免得GPU占满
    echo "$WAITER_NAME 处理完成！输出保存在 ./model_output_${WAITER_NAME}"
done

echo "所有客服洛拉模型训练脚本已准备好！"
