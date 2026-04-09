#!/usr/bin/env python3
"""
ECDICT to Goldene ROM Converter
==============================
将 ECDICT 词典数据转换为 goldene SRS 应用的 ROM SQLite 数据库。

用法:
    python convert.py --input ecdict.csv --wordroot wordroot.txt --output wordmemory_rom.db
    python convert.py --mini --output wordmemory_rom.db          # 使用 ecdict.mini.csv

依赖:
    pip install sqlite3 (标准库)

对应文档: 词汇SRS&SDD v2.1 第 2 节

ECDICT CSV 字段:
    word, phonetic, definition, translation, pos, collins, oxford,
    tag, bnc, frq, exchange, detail, audio

goldene Note 表字段 (ROM):
    Concept_UUID, Spelling, Phonetic, Definition,
    Etymology_JSON, Micro_Context_JSON, Content_JSON
"""

import csv
import json
import sqlite3
import os
import re
import sys
import argparse
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from collections import defaultdict
import random
import hashlib


# ============================================================================
# 常量配置
# ============================================================================

# goldene ROM 数据库路径
DEFAULT_OUTPUT = "wordmemory_rom.db"

# 支持的词书标签（对应 ECDICT tag 字段）
BOOK_TAGS = {
    "cet4": ["zk", "cet4"],
    "cet6": ["cet6"],
    "kaoyan": ["ky", "zk", "cet4", "cet6"],
    "toefl": ["toefl"],
    "ielts": ["ielts"],
    "gre": ["gre"],
}

# 词书默认词汇量上限
BOOK_LIMITS = {
    "cet4": 3000,
    "cet6": 2500,
    "kaoyan": 5500,
    "toefl": 8000,
    "ielts": 6000,
    "gre": 10000,
}

# 中英对照词性映射
POS_MAP = {
    "n": "名词", "v": "动词", "adj": "形容词", "adv": "副词",
    "prep": "介词", "conj": "连词", "pron": "代词", "det": "限定词",
    "num": "数词",
}

# 词根文件中的特殊前缀标记
PREFIX_MARKS = ["re-", "pre-", "sub-", "dis-", "in-", "com-", "ex-",
                "ad-", "de-", "trans-", "pro-"]
SUFFIX_MARKS = ["-less", "-ful", "-tion", "-sion", "-ment", "-ness",
                 "-able", "-ible", "-al", "-ly", "-er", "-est"]


# ============================================================================
# UUID 生成工具
# ============================================================================

def generate_uuid(word: str, salt: str = "goldene_v2.1") -> str:
    """根据单词生成稳定的 UUID（MD5 摘要，简单可靠）。"""
    h = hashlib.md5(f"{salt}_{word}".encode("utf-8")).hexdigest()
    return f"note_{h[:16]}"


def root_id_from_name(name: str) -> str:
    """根据词根名称生成稳定的 Root_ID。"""
    clean = re.sub(r'[^a-z]', '', name.lower())
    return f"root_{clean}"


# ============================================================================
# CSV 解析
# ============================================================================

def parse_csv_row(raw: str) -> Dict[str, str]:
    """解析带引号的 CSV 行，处理内部引号和换行符。"""
    result = {}
    reader = csv.reader([raw], quotechar="'", doublequote=False,
                         escapechar="\\", strict=True)
    try:
        fields = next(reader)
        # ECDICT 标准字段顺序
        keys = ["word", "phonetic", "definition", "translation", "pos",
                "collins", "oxford", "tag", "bnc", "frq", "exchange",
                "detail", "audio"]
        for i, val in enumerate(fields):
            if i < len(keys):
                result[keys[i]] = val.strip()
    except Exception:
        pass
    return result


def load_ecdict_csv(path: str, max_rows: Optional[int] = None) -> List[Dict]:
    """
    加载 ECDICT CSV 文件。
    返回 [{word, phonetic, definition, ...}, ...]
    """
    print(f"[ECDICT] 加载 CSV: {path}")
    records = []

    # 手动解析以处理 ECDICT 的特殊引号格式
    with open(path, "r", encoding="utf-8") as f:
        header = f.readline()  # 跳过标题行
        line_num = 1

        buffer = ""
        in_quotes = False
        quote_char = "'"

        while True:
            line = f.readline()
            line_num += 1
            if not line:
                # 处理最后一行
                if buffer:
                    row = parse_csv_row(buffer)
                    if row.get("word"):
                        records.append(row)
                break

            for ch in line:
                if ch == quote_char and not (buffer and buffer[-1] == '\\'):
                    in_quotes = not in_quotes
                buffer += ch

            if not in_quotes:
                # 完整行解析
                row = parse_csv_row(buffer)
                if row.get("word"):
                    records.append(row)
                    if max_rows and len(records) >= max_rows:
                        print(f"[ECDICT] 已加载 {len(records)} 条记录（达到上限）")
                        return records
                buffer = ""
                line_num = 0

            if line_num % 100000 == 0:
                print(f"[ECDICT] 已解析 {len(records)} 行...")

    print(f"[ECDICT] 共加载 {len(records)} 条词汇")
    return records


def load_wordroot(path: str) -> Dict[str, Dict]:
    """加载 wordroot.txt JSON 文件。"""
    print(f"[ECDICT] 加载词根数据: {path}")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # 分类整理
    roots = {}      # key: 词根名 -> {meaning, class, examples}
    prefixes = {}  # 以 re- 等开头的词缀
    suffixes = {}  # 以 -less 等结尾的词缀

    for key, val in data.items():
        entry = {
            "meaning": val.get("meaning", ""),
            "class": val.get("class", ""),
            "examples": val.get("example", []),
            "synonyms": val.get("synonyms", ""),
            "antonyms": val.get("antonyms", ""),
        }

        if key.startswith("-") or key.endswith("-"):
            prefixes[key] = entry
        elif key.startswith("-"):
            suffixes[key] = entry
        else:
            roots[key] = entry

    print(f"[ECDICT] 词根: {len(roots)}, 前缀: {len(prefixes)}, 后缀: {len(suffixes)}")
    return {"roots": roots, "prefixes": prefixes, "suffixes": suffixes}


# ============================================================================
# 数据转换
# ============================================================================

def build_etymology_json(word: str, definition: str, wordroot: Dict,
                          collins: str, exchange: str) -> str:
    """
    根据 ECDICT 数据构建 Etymology_JSON。
    对应 SRS&SDD 字段: Etymology_JSON (词根词缀 JSON)

    格式: {"prefix": "re-", "root": "ced", "suffix": "-less"}
    """
    word_lower = word.lower()
    etymology = {"prefix": "", "root": "", "suffix": ""}

    # 检测前缀（最常见的）
    found_prefix = None
    for prefix in ["re-", "pre-", "sub-", "dis-", "in-", "im-", "un-",
                   "com-", "con-", "ex-", "ad-", "de-", "trans-",
                   "pro-", "per-", "inter-", "over-", "under-"]:
        if word_lower.startswith(prefix.replace("-", "")):
            found_prefix = prefix
            break
        if word_lower.startswith(prefix):
            found_prefix = prefix
            break

    if found_prefix:
        etymology["prefix"] = found_prefix

    # 检测后缀（-tion, -less, -ful, -ment 等）
    found_suffix = None
    for suffix in ["-tion", "-sion", "-ment", "-ness", "-less", "-ful",
                   "-able", "-ible", "-al", "-ly", "-er", "-est", "-ing", "-ed"]:
        if word_lower.endswith(suffix):
            found_suffix = suffix
            break

    if found_suffix:
        etymology["suffix"] = found_suffix

    # 简单词根检测：如果 definition 包含常见词根词
    common_roots = {
        "ced": "ced=go(走)", "gress": "gress=step(步)",
        "duct": "duct=lead(引导)", "scrib": "scrib=write(写)",
        "tract": "tract=draw(拉)", "vert": "vert=turn(转)",
        "port": "port=carry(搬运)", "ject": "ject=throw(投)",
        "dict": "dict=say(说)", "form": "form=shape(形状)",
        "spect": "spect=look(看)", "mit": "mit=send(送)",
    }
    for root_key, root_desc in common_roots.items():
        if root_key in word_lower:
            etymology["root"] = root_desc
            break

    # 如果是交换形式，尝试从 exchange 提取词根
    if not etymology["root"] and exchange:
        # exchange 格式: p:looked/d:looked/i:looking/3:looks/0:look
        match = re.search(r'0:(\w+)', exchange)
        if match:
            lemma = match.group(1)
            for root_key in common_roots:
                if root_key in lemma:
                    etymology["root"] = common_roots[root_key]
                    break

    # 至少返回非空 JSON
    result = {k: v for k, v in etymology.items() if v}
    return json.dumps(result, ensure_ascii=False)


def build_micro_context(word: str, detail: str, translation: str) -> str:
    """
    构建 Micro_Context_JSON（例句）。

    对应 SRS&SDD 字段: Micro_Context_JSON
    格式: {"en": "...", "zh": "..."}
    """
    example_en = ""
    example_zh = ""

    # 优先从 detail 字段提取例句
    if detail:
        # detail 可能是 {"syno": [["word", ["syn1", "syn2"]]]}
        # 也可能包含例句文本
        try:
            detail_obj = json.loads(detail)
            # 检查是否有网络例句
            if "网络" in str(detail_obj):
                # 尝试提取
                pass
        except (json.JSONDecodeError, TypeError):
            pass

        # 尝试从 definition 中提取简短例句
        def_lines = definition.split('\n') if 'definition' in dir() else []
        for line in str(detail).split('\n'):
            line = line.strip()
            # 保留简短的第一条解释作为 fallback
            if line and not example_en:
                if 10 < len(line) < 100 and not line.startswith('['):
                    example_en = line
                    example_zh = translation.split('\n')[0] if translation else ""

    if not example_en:
        example_en = f"An example with {word}."
        example_zh = f"一个包含 {word} 的例句。"

    return json.dumps({
        "en": example_en[:200],  # 限制长度
        "zh": example_zh[:100],
    }, ensure_ascii=False)


def build_content_json(word: str, definition: str, translation: str,
                       etymology_json: str) -> str:
    """
    构建 Content_JSON（话题阅读短文）。

    对应 SRS&SDD 字段: Content_JSON
    格式: {"spelling": "", "phonetic": "", "definition": "", ...}
    此字段用于语义阅读场景，存储单词的完整展示数据。
    """
    return json.dumps({
        "spelling": word,
        "definition": definition.split('\n')[0] if definition else "",
        "translation": translation.split('\n')[0] if translation else "",
        "etymology": etymology_json,
    }, ensure_ascii=False)


def filter_by_tag(records: List[Dict], tags: List[str]) -> List[Dict]:
    """根据 tag 字段过滤词汇。"""
    if not tags:
        return records

    filtered = []
    for r in records:
        word_tags = r.get("tag", "")
        if not word_tags:
            continue
        # tag 用空格分隔
        word_tag_list = word_tags.lower().split()
        if any(t in word_tag_list for t in tags):
            filtered.append(r)

    return filtered


def build_note_record(ecdict_row: Dict, wordroot: Dict) -> Optional[Dict]:
    """将一条 ECDICT 记录转换为 goldene Note 记录。"""
    word = ecdict_row.get("word", "").strip()
    if not word:
        return None

    uuid = generate_uuid(word)
    phonetic = ecdict_row.get("phonetic", "").strip()
    definition = ecdict_row.get("definition", "").strip()
    translation = ecdict_row.get("translation", "").strip()
    collins = ecdict_row.get("collins", "0")
    exchange = ecdict_row.get("exchange", "")
    detail = ecdict_row.get("detail", "")
    tag = ecdict_row.get("tag", "")

    etymology_json = build_etymology_json(word, definition, wordroot, collins, exchange)
    micro_context_json = build_micro_context(word, detail, translation)
    content_json = build_content_json(word, definition, translation, etymology_json)

    return {
        "Concept_UUID": uuid,
        "Spelling": word,
        "Phonetic": phonetic,
        "Definition": definition,
        "Etymology_JSON": etymology_json,
        "Micro_Context_JSON": micro_context_json,
        "Content_JSON": content_json,
        # 扩展字段（供未来使用）
        "_collins": collins,
        "_tag": tag,
        "_exchange": exchange,
    }


# ============================================================================
# Tree 数据构建
# ============================================================================

def build_tree_data(notes: List[Dict], wordroot: Dict) -> Tuple[List[Dict], List[Dict]]:
    """
    根据词根数据构建 Tree_Root 和 Tree_Word 表数据。

    返回: (roots_list, words_list)
    """
    roots_map = {}  # root_id -> root record
    words_list = [] # Tree_Word 记录列表

    # 从 wordroot 构建 Tree_Root
    all_roots = {**wordroot.get("roots", {}), **wordroot.get("prefixes", {})}

    for root_name, root_info in all_roots.items():
        root_id = root_id_from_name(root_name)
        # 判断是前缀还是后缀
        if root_name.startswith("-"):
            root_group = root_name[1].upper() if len(root_name) > 1 else "X"
        elif root_name.startswith("'"):
            root_group = root_name[1].upper() if len(root_name) > 1 else "X"
        else:
            root_group = root_name[0].upper()

        # 提取词根含义
        meaning = root_info.get("meaning", "")

        roots_map[root_id] = {
            "Root_ID": root_id,
            "Root_Name": root_name,
            "Root_Definition": meaning,
            "Root_Group": root_group,
        }

    # 根据 notes 中的 etymology_json 关联词汇到词根
    word_to_uuid = {}
    for note in notes:
        spelling = note.get("Spelling", "").lower()
        word_to_uuid[spelling] = note.get("Concept_UUID")

    sort_order = 0
    for note in notes:
        spelling = note.get("Spelling", "").lower()
        etymology_str = note.get("Etymology_JSON", "{}")
        try:
            etymology = json.loads(etymology_str)
        except (json.JSONDecodeError, TypeError):
            etymology = {}

        prefix = etymology.get("prefix", "")
        root_desc = etymology.get("root", "")
        suffix = etymology.get("suffix", "")

        # 提取词根名（从 root_desc 中提取 "=" 前面的部分）
        root_name_from_desc = ""
        if "=" in root_desc:
            root_name_from_desc = root_desc.split("=")[0]
        elif root_desc:
            root_name_from_desc = root_desc.split(",")[0].strip()

        # 尝试匹配词根
        matched_roots = []

        if prefix:
            for rname in wordroot.get("prefixes", {}).keys():
                if rname in prefix or prefix.replace("-", "") in rname:
                    matched_roots.append(rname)
                    break

        if suffix:
            for rname in wordroot.get("suffixes", {}).keys():
                if rname in suffix:
                    matched_roots.append(rname)
                    break

        if root_name_from_desc:
            for rname in wordroot.get("roots", {}).keys():
                if rname in root_name_from_desc or root_name_from_desc in rname:
                    matched_roots.append(rname)
                    break

        for matched_root in matched_roots:
            root_id = root_id_from_name(matched_root)
            if root_id not in roots_map:
                # 动态创建词根记录
                roots_map[root_id] = {
                    "Root_ID": root_id,
                    "Root_Name": matched_root,
                    "Root_Definition": wordroot.get("roots", {}).get(matched_root, {}).get("meaning", ""),
                    "Root_Group": matched_root[0].upper(),
                }

            compound_form = f"{prefix}{spelling}{suffix}".strip("-")
            uuid = note.get("Concept_UUID", "")

            words_list.append({
                "Root_ID": root_id,
                "Concept_UUID": uuid,
                "Compound_Form": compound_form,
                "Compound_Meaning": etymology_str[:200] if len(etymology_str) > 200 else etymology_str,
                "Final_Meaning": note.get("Definition", "").split('\n')[0][:50],
                "Sort_Order": sort_order,
            })
            sort_order += 1

    roots_list = list(roots_map.values())
    return roots_list, words_list


# ============================================================================
# Topic / Article 数据构建
# ============================================================================

def build_topic_article_data(notes: List[Dict]) -> Tuple[List[Dict], List[Dict]]:
    """
    构建 Topic 和 Article 表数据。

    按词义领域分类生成话题短文。
    这里使用简化策略：按前两个字母分组生成伪话题。
    """
    topics = []
    articles = []

    # 定义话题域
    topic_defs = {
        "tech": {"id": "topic_tech", "name": "科技词汇", "name_en": "Technology", "keywords": ["tech", "net", "data", "digital"]},
        "daily": {"id": "topic_daily", "name": "日常词汇", "name_en": "Daily Life", "keywords": ["life", "home", "food", "work"]},
        "social": {"id": "topic_social", "name": "社交词汇", "name_en": "Social", "keywords": ["people", "friend", "family", "talk"]},
        "business": {"id": "topic_business", "name": "商务词汇", "name_en": "Business", "keywords": ["money", "market", "company", "trade"]},
        "study": {"id": "topic_study", "name": "学习词汇", "name_en": "Study", "keywords": ["learn", "read", "book", "write"]},
        "nature": {"id": "topic_nature", "name": "自然词汇", "name_en": "Nature", "keywords": ["tree", "water", "earth", "sky"]},
    }

    for key, topic_def in topic_defs.items():
        topics.append({
            "Topic_ID": topic_def["id"],
            "Topic_Name": topic_def["name"],
            "Topic_Name_EN": topic_def["name_en"],
            "Word_Count": 8,  # 每篇短文目标词汇数
        })

    # 为每个 Topic 生成一篇文章
    for topic in topics:
        topic_id = topic["Topic_ID"]
        keywords = topic_defs.get(topic_id.split("_")[1], {}).get("keywords", [])

        # 找出匹配的词汇
        matched_notes = []
        for note in notes:
            defn = note.get("Definition", "").lower()
            if any(kw in defn for kw in keywords):
                matched_notes.append(note)
                if len(matched_notes) >= 8:
                    break

        if len(matched_notes) < 3:
            # 兜底：用前几个词汇
            matched_notes = notes[:8]

        # 构建 Content_JSON 段落
        segments = []
        text_buffer = ""

        for note in matched_notes[:8]:
            spelling = note.get("Spelling", "")
            uuid = note.get("Concept_UUID", "")

            if text_buffer:
                segments.append({"t": text_buffer + " ", "c": 0, "u": None})
                text_buffer = ""

            segments.append({"t": spelling, "c": 1, "u": uuid})
            text_buffer = ""

        if text_buffer:
            segments.append({"t": text_buffer, "c": 0, "u": None})

        article_id = f"article_{topic_id.split('_')[1]}_auto"

        articles.append({
            "Article_ID": article_id,
            "Topic_ID": topic_id,
            "Content_JSON": json.dumps(segments, ensure_ascii=False),
            "Word_Count": len([s for s in segments if s["c"] == 1]),
        })

    return topics, articles


# ============================================================================
# 数据库写入
# ============================================================================

def create_database(output_path: str, notes: List[Dict],
                   roots: List[Dict], tree_words: List[Dict],
                   topics: List[Dict], articles: List[Dict]) -> None:
    """创建 goldene ROM SQLite 数据库。"""

    # 删除已存在的数据库
    if os.path.exists(output_path):
        os.remove(output_path)
        print(f"[DB] 已删除旧数据库: {output_path}")

    conn = sqlite3.connect(output_path)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA encoding='UTF-8'")

    cursor = conn.cursor()

    # 创建 Note 表
    cursor.execute('''
        CREATE TABLE Note (
            Concept_UUID TEXT PRIMARY KEY,
            Spelling TEXT NOT NULL,
            Phonetic TEXT NOT NULL,
            Definition TEXT NOT NULL,
            Etymology_JSON TEXT,
            Micro_Context_JSON TEXT NOT NULL,
            Content_JSON TEXT NOT NULL
        ) STRICT;
    ''')

    # 创建 Tree_Root 表
    cursor.execute('''
        CREATE TABLE Tree_Root (
            Root_ID TEXT PRIMARY KEY,
            Root_Name TEXT NOT NULL,
            Root_Definition TEXT NOT NULL,
            Root_Group TEXT NOT NULL
        ) STRICT;
    ''')

    # 创建 Tree_Word 表
    cursor.execute('''
        CREATE TABLE Tree_Word (
            Tree_Word_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            Root_ID TEXT NOT NULL,
            Concept_UUID TEXT NOT NULL,
            Compound_Form TEXT NOT NULL,
            Compound_Meaning TEXT NOT NULL,
            Final_Meaning TEXT NOT NULL,
            Sort_Order INTEGER DEFAULT 0,
            FOREIGN KEY (Root_ID) REFERENCES Tree_Root(Root_ID),
            FOREIGN KEY (Concept_UUID) REFERENCES Note(Concept_UUID)
        ) STRICT;
    ''')

    # 创建 Topic 表
    cursor.execute('''
        CREATE TABLE Topic (
            Topic_ID TEXT PRIMARY KEY,
            Topic_Name TEXT NOT NULL,
            Topic_Name_EN TEXT NOT NULL,
            Word_Count INTEGER NOT NULL
        ) STRICT;
    ''')

    # 创建 Article 表
    cursor.execute('''
        CREATE TABLE Article (
            Article_ID TEXT PRIMARY KEY,
            Topic_ID TEXT NOT NULL,
            Content_JSON TEXT NOT NULL,
            Word_Count INTEGER NOT NULL,
            FOREIGN KEY (Topic_ID) REFERENCES Topic(Topic_ID)
        ) STRICT;
    ''')

    # 创建索引
    cursor.execute('CREATE INDEX idx_note_spelling ON Note(Spelling);')
    cursor.execute('CREATE INDEX idx_tree_word_root ON Tree_Word(Root_ID);')
    cursor.execute('CREATE INDEX idx_tree_word_uuid ON Tree_Word(Concept_UUID);')
    cursor.execute('CREATE INDEX idx_article_topic ON Article(Topic_ID);')

    # 写入 Note 数据
    print(f"[DB] 写入 {len(notes)} 条 Note 记录...")
    for note in notes:
        cursor.execute('''
            INSERT INTO Note (Concept_UUID, Spelling, Phonetic, Definition,
                              Etymology_JSON, Micro_Context_JSON, Content_JSON)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', [
            note["Concept_UUID"],
            note["Spelling"],
            note["Phonetic"],
            note["Definition"],
            note.get("Etymology_JSON", ""),
            note["Micro_Context_JSON"],
            note["Content_JSON"],
        ])

    # 写入 Tree_Root 数据
    print(f"[DB] 写入 {len(roots)} 条 Tree_Root 记录...")
    for root in roots:
        cursor.execute('''
            INSERT INTO Tree_Root (Root_ID, Root_Name, Root_Definition, Root_Group)
            VALUES (?, ?, ?, ?)
        ''', [
            root["Root_ID"],
            root["Root_Name"],
            root["Root_Definition"],
            root["Root_Group"],
        ])

    # 写入 Tree_Word 数据
    print(f"[DB] 写入 {len(tree_words)} 条 Tree_Word 记录...")
    for word in tree_words:
        cursor.execute('''
            INSERT INTO Tree_Word (Root_ID, Concept_UUID, Compound_Form,
                                  Compound_Meaning, Final_Meaning, Sort_Order)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', [
            word["Root_ID"],
            word["Concept_UUID"],
            word["Compound_Form"],
            word["Compound_Meaning"],
            word["Final_Meaning"],
            word["Sort_Order"],
        ])

    # 写入 Topic 数据
    print(f"[DB] 写入 {len(topics)} 条 Topic 记录...")
    for topic in topics:
        cursor.execute('''
            INSERT INTO Topic (Topic_ID, Topic_Name, Topic_Name_EN, Word_Count)
            VALUES (?, ?, ?, ?)
        ''', [
            topic["Topic_ID"],
            topic["Topic_Name"],
            topic["Topic_Name_EN"],
            topic["Word_Count"],
        ])

    # 写入 Article 数据
    print(f"[DB] 写入 {len(articles)} 条 Article 记录...")
    for article in articles:
        cursor.execute('''
            INSERT INTO Article (Article_ID, Topic_ID, Content_JSON, Word_Count)
            VALUES (?, ?, ?, ?)
        ''', [
            article["Article_ID"],
            article["Topic_ID"],
            article["Content_JSON"],
            article["Word_Count"],
        ])

    conn.commit()

    # 验证数据
    for table in ["Note", "Tree_Root", "Tree_Word", "Topic", "Article"]:
        count = cursor.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        print(f"[DB] {table}: {count} 条记录")

    conn.close()
    print(f"[DB] 数据库创建完成: {output_path}")


# ============================================================================
# 主流程
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="ECDICT to Goldene ROM Converter",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  python convert.py --input ecdict.csv --wordroot wordroot.txt --output wordmemory_rom.db
  python convert.py --mini --output wordmemory_rom_mini.db
  python convert.py --input ecdict.csv --wordroot wordroot.txt --book cet6 --limit 2500
        """
    )
    parser.add_argument("--input", "-i", default="ecdict.csv",
                        help="ECDICT CSV 文件路径 (默认: ecdict.csv)")
    parser.add_argument("--wordroot", "-w", default="wordroot.txt",
                        help="wordroot.txt 文件路径 (默认: wordroot.txt)")
    parser.add_argument("--output", "-o", default=DEFAULT_OUTPUT,
                        help=f"输出 SQLite 文件路径 (默认: {DEFAULT_OUTPUT})")
    parser.add_argument("--mini", action="store_true",
                        help="使用 ecdict.mini.csv (精简版约4万词)")
    parser.add_argument("--book", "-b", default=None,
                        choices=list(BOOK_TAGS.keys()),
                        help="按词书标签过滤 (cet4/cet6/kaoyan/toefl/ielts/gre)")
    parser.add_argument("--limit", "-l", type=int, default=None,
                        help=f"词汇数量上限 (默认: 根据词书自动设置)")
    parser.add_argument("--max-rows", "-m", type=int, default=None,
                        help="最大读取行数 (用于测试)")

    args = parser.parse_args()

    # 确定输入文件
    if args.mini:
        input_path = "ecdict.mini.csv"
    else:
        input_path = args.input

    if not os.path.exists(input_path):
        print(f"[ERROR] 输入文件不存在: {input_path}")
        sys.exit(1)

    wordroot_path = args.wordroot
    if not os.path.exists(wordroot_path):
        print(f"[WARN] 词根文件不存在（将跳过词根数据生成）: {wordroot_path}")
        wordroot_data = {"roots": {}, "prefixes": {}, "suffixes": {}}
    else:
        wordroot_data = load_wordroot(wordroot_path)

    # 加载 ECDICT 数据
    records = load_ecdict_csv(input_path, max_rows=args.max_rows)
    if not records:
        print("[ERROR] CSV 文件为空或无法解析")
        sys.exit(1)

    # 按词书过滤
    if args.book:
        tags = BOOK_TAGS[args.book]
        print(f"[FILTER] 按词书 '{args.book}' 过滤，标签: {tags}")
        records = filter_by_tag(records, tags)
        print(f"[FILTER] 过滤后剩余 {len(records)} 条词汇")

    # 限制数量
    limit = args.limit or (BOOK_LIMITS.get(args.book) if args.book else None)
    if limit and len(records) > limit:
        print(f"[LIMIT] 限制为前 {limit} 条")
        records = records[:limit]

    # 转换为 goldene 格式
    print(f"[CONVERT] 转换 {len(records)} 条记录为 goldene Note 格式...")
    notes = []
    skipped = 0
    for i, rec in enumerate(records):
        note = build_note_record(rec, wordroot_data)
        if note:
            notes.append(note)
        else:
            skipped += 1
        if (i + 1) % 50000 == 0:
            print(f"[CONVERT] 已处理 {i + 1} 条...")

    print(f"[CONVERT] 完成: {len(notes)} 条有效记录，{skipped} 条跳过")

    # 构建 Tree 数据
    print("[CONVERT] 构建词根树数据...")
    roots, tree_words = build_tree_data(notes, wordroot_data)
    print(f"[CONVERT] Tree_Root: {len(roots)}, Tree_Word: {len(tree_words)}")

    # 构建 Topic/Article 数据
    print("[CONVERT] 构建话题阅读数据...")
    topics, articles = build_topic_article_data(notes)
    print(f"[CONVERT] Topic: {len(topics)}, Article: {len(articles)}")

    # 生成数据库
    print(f"[BUILD] 生成 ROM 数据库: {args.output}")
    create_database(args.output, notes, roots, tree_words, topics, articles)

    # 输出统计
    print("\n=== 转换完成 ===")
    print(f"输入文件: {input_path}")
    print(f"输出文件: {args.output}")
    print(f"词汇数量: {len(notes)}")
    print(f"词根数量: {len(roots)}")
    print(f"派生词数量: {len(tree_words)}")
    print(f"话题数量: {len(topics)}")
    print(f"文章数量: {len(articles)}")

    if args.book:
        print(f"词书: {args.book} (标签: {BOOK_TAGS[args.book]})")


if __name__ == "__main__":
    main()
