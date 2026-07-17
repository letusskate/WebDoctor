#!/usr/bin/env python3
"""
处理 yida_data 目录下的医患聊天数据，拆分为 WeClone 格式的按医生分组的 CSV 文件。

数据源: dataset/yida_data/all_dialogues_with_dept.csv
输出:   dataset/csv/doctor_{sanitized_name}/data.csv

WeClone CSV 格式:
    id,MsgSvrID,type_name,is_sender,talker,room_name,msg,src,CreateTime
"""

import csv
import hashlib
import os
import random
from collections import defaultdict
from datetime import datetime, timedelta

# ── 路径配置 ──────────────────────────────────────────────────────────────
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INPUT_CSV = os.path.join(PROJECT_ROOT, "dataset", "yida_data", "all_dialogues_with_dept.csv")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "dataset", "csv")

# ── 配置 ──────────────────────────────────────────────────────────────────
MIN_MESSAGES_PER_DOCTOR = 10
CONVERSATION_GAP_MINUTES = 30


def sanitize_name(name: str) -> str:
    """将医生名转为安全的目录名，避免文件系统问题。"""
    h = hashlib.md5(name.encode("utf-8")).hexdigest()[:8]
    safe = "".join(c if c.isalnum() or "\u4e00" <= c <= "\u9fff" else "_" for c in name)
    return f"{safe}_{h}"


def parse_datetime(dt_str: str) -> datetime:
    """解析消息时间字符串，兼容多种常见格式。"""
    if not dt_str or not dt_str.strip():
        return datetime(2024, 1, 1)
    for fmt in (
        "%Y-%m-%d %H:%M:%S",
        "%Y/%m/%d %H:%M:%S",
        "%m/%d/%Y %H:%M:%S",
        "%m/%d/%Y %H:%M",
    ):
        try:
            return datetime.strptime(dt_str.strip(), fmt)
        except ValueError:
            continue
    return datetime(2024, 1, 1)


def main():
    print(f"Reading data from: {INPUT_CSV}")

    # 按医生分组原始消息
    doctor_msgs: dict[str, list[dict]] = defaultdict(list)

    with open(INPUT_CSV, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            doctor = row.get("doctor_name", "").strip()
            content = row.get("content", "").strip()
            if not doctor or not content:
                continue
            doctor_msgs[doctor].append({
                "patient_name": row.get("patient_name", "").strip(),
                "message_time": row.get("message_time", "").strip(),
                "sender_name": row.get("sender_name", "").strip(),
                "content": content,
            })

    print(f"Total doctors found: {len(doctor_msgs)}")

    # 过滤消息数过少的医生
    doctors_to_process = {
        d: msgs for d, msgs in doctor_msgs.items()
        if len(msgs) >= MIN_MESSAGES_PER_DOCTOR
    }
    skipped = len(doctor_msgs) - len(doctors_to_process)
    if skipped:
        print(f"Skipped {skipped} doctors (messages < {MIN_MESSAGES_PER_DOCTOR})")
    print(f"Will process {len(doctors_to_process)} doctors")

    # 为每位医生生成 WeClone 格式 CSV
    for doctor_name, messages in sorted(doctors_to_process.items()):
        safe_name = sanitize_name(doctor_name)
        doctor_dir = os.path.join(OUTPUT_DIR, f"doctor_{safe_name}")
        os.makedirs(doctor_dir, exist_ok=True)

        out_path = os.path.join(doctor_dir, "data.csv")

        messages.sort(key=lambda m: (m["patient_name"], parse_datetime(m["message_time"])))

        with open(out_path, "w", encoding="utf-8", newline="") as f:
            writer = csv.writer(f)
            writer.writerow(["id", "MsgSvrID", "type_name", "is_sender",
                             "talker", "room_name", "msg", "src", "CreateTime"])

            msg_idx = 1
            base_time = datetime(2024, 1, 1, 10, 0, 0)
            prev_patient = None

            for msg in messages:
                patient = msg["patient_name"]
                sender = msg["sender_name"]
                content = msg["content"]

                if prev_patient is not None and patient != prev_patient:
                    base_time += timedelta(minutes=CONVERSATION_GAP_MINUTES)
                prev_patient = patient

                is_sender = 1 if sender == doctor_name else 0
                create_time = base_time.strftime("%Y/%m/%d %H:%M:%S")

                writer.writerow([
                    msg_idx,
                    str(random.randint(1000000000, 9999999999)),
                    "文本",
                    is_sender,
                    patient,
                    "",
                    content,
                    "",
                    create_time,
                ])
                msg_idx += 1
                base_time += timedelta(minutes=1)

    print(f"Done! Output directory: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
