#!/usr/bin/env python3
"""
清理 Card 表中以 - 或 ' 开头的脏数据。
用于一次性清理已存在的脏数据，无需重建整个数据库。

用法：python scripts/cleanup_dirty_cards.py
      python scripts/cleanup_dirty_cards.py --db-path assets/ecdict/ecdict.db
"""
import argparse
import os
import sqlite3

def cleanup_dirty_cards(hot_db_path: str):
    """清理 Card 表中以 - 或 ' 开头的脏数据"""
    if not os.path.exists(hot_db_path):
        print(f'[Cleanup] 数据库不存在: {hot_db_path}')
        return

    conn = sqlite3.connect(hot_db_path)
    cur = conn.cursor()

    # 检查 Card 和 Note 表是否存在
    try:
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='Card'")
        if not cur.fetchone():
            print('[Cleanup] Card 表不存在，跳过')
            conn.close()
            return
        cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='Note'")
        if not cur.fetchone():
            print('[Cleanup] Note 表不存在，跳过')
            conn.close()
            return
    except sqlite3.Error as e:
        print(f'[Cleanup] 数据库检查失败: {e}')
        conn.close()
        return

    # 查询脏数据
    cur.execute('''
        SELECT Card.Card_ID, Note.Spelling
        FROM Card
        JOIN Note ON Card.Concept_UUID = Note.Concept_UUID
        WHERE Note.Spelling LIKE '-%' OR Note.Spelling LIKE "'%"
    ''')
    dirty = cur.fetchall()

    if not dirty:
        print('[Cleanup] 无脏数据')
        conn.close()
        return

    card_ids = [r[0] for r in dirty]
    placeholders = ','.join('?' * len(card_ids))
    cur.execute(f'DELETE FROM Card WHERE Card_ID IN ({placeholders})', card_ids)
    conn.commit()
    conn.close()

    print(f'[Cleanup] 已删除 {len(card_ids)} 张脏 Card：')
    for card_id, spelling in dirty[:10]:  # 只打印前10条
        print(f'  - {spelling} (Card_ID: {card_id})')
    if len(dirty) > 10:
        print(f'  ... 及其他 {len(dirty) - 10} 条')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='清理 Card 表中的脏数据')
    parser.add_argument('--db-path', default='assets/ecdict/ecdict.db',
                        help='数据库路径（默认：assets/ecdict/ecdict.db）')
    args = parser.parse_args()

    # 自动转换相对路径为绝对路径
    if not os.path.isabs(args.db_path):
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_dir = os.path.dirname(script_dir)
        args.db_path = os.path.join(project_dir, args.db_path)

    cleanup_dirty_cards(args.db_path)
