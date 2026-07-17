import csv
import os
import random
from datetime import datetime, timedelta

def process_chat(input_file, num_waiters=5, output_dir='../dataset/csv'):
    # Group by session_id
    sessions = {}
    with open(input_file, 'r', encoding='utf-8') as f:
        reader = csv.reader(f, delimiter='\t')
        header = next(reader)
        for row in reader:
            if len(row) < 7:
                continue
            session_id = row[0]
            user_id = row[1]
            waiter_send = row[2]
            content = row[-1]
            if not content.strip():
                continue
            
            if session_id not in sessions:
                sessions[session_id] = []
            
            sessions[session_id].append({
                'user_id': user_id,
                'waiter_send': int(waiter_send),
                'content': content
            })

    session_keys = list(sessions.keys())
    waiter_files = {i: [] for i in range(num_waiters)}
    
    # Distribute sessions to waiters
    for i, s_id in enumerate(session_keys):
        waiter_id = i % num_waiters
        waiter_files[waiter_id].extend(sessions[s_id])

    for w_id in range(num_waiters):
        w_dir = os.path.join(output_dir, f'waiter_{w_id}')
        os.makedirs(w_dir, exist_ok=True)
        out_path = os.path.join(w_dir, 'data.csv')
        
        with open(out_path, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['id', 'MsgSvrID', 'type_name', 'is_sender', 'talker', 'room_name', 'msg', 'src', 'CreateTime'])
            
            dt = datetime(2024, 1, 1, 10, 0, 0)
            msg_idx = 1
            prev_talker = None
            for msg in waiter_files[w_id]:
                talker = msg['user_id']
                if prev_talker is not None and talker != prev_talker:
                    # 切换到另一个会话(另一个用户)时，增加30分钟，强制断开上下文
                    dt += timedelta(minutes=30)
                prev_talker = talker

                type_name = "文本"
                is_sender = 1 if msg['waiter_send'] == 1 else 0
                talker = msg['user_id']
                room_name = ""
                content = msg['content']
                src = ""
                create_time = dt.strftime("%Y/%m/%d %H:%M:%S")
                
                writer.writerow([
                    msg_idx, 
                    str(random.randint(1000000000, 9999999999)),
                    type_name,
                    is_sender,
                    talker,
                    room_name,
                    content,
                    src,
                    create_time
                ])
                msg_idx += 1
                dt += timedelta(minutes=1)
            
            # 每处理完一个用户的会话(session)，额外增加30分钟的时间间隔
            # 这样会让 WeClone 认为这是一次全新的对话，从而打断它无休止的上下文拼接
            dt += timedelta(minutes=30)
                
    print(f"✅ 处理完成，数据已按 {num_waiters} 个客服拆分并保存至 {output_dir}")

if __name__ == '__main__':
    # 假设需要分给 3 个客服
    process_chat('../dataset/chat.txt', num_waiters=3)
