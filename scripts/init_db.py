#!/usr/bin/env python3
"""
ECDICT 预生成脚本：将 ecdict.csv + wordroot.txt + resemble.txt
一次性生成 assets/ecdict/ 下所有文件：
  - ecdict.db                 桌面端 SQLite 数据库
  - ecdict_book_counts.json   词书统计 {"cet4": 3000, ...}
  - ecdict_notes_p*.json      Note 分卷（Web 用，每卷 50000 条）
  - ecdict_notes_manifest.json Note 分卷索引
  - ecdict_resemble.json      近义词辨析
  - ecdict_tree_root.json     词根目录
  - ecdict_tree_word_p*.json  Tree_Word 分卷
  - ecdict_tree_word_manifest.json Tree_Word 分卷索引

运行：python scripts/init_db.py
"""

import os
import json
import csv
import sqlite3
import argparse
import re

# ============================================================================
# 路径配置
# ============================================================================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)
ASSETS_DIR = os.path.join(PROJECT_DIR, 'assets', 'ecdict')

# ECDICT 源文件（用户桌面）
ECDICT_SOURCE_DIR = r'C:\Users\joss1\Desktop\ECDICT-master'

BATCH_SIZE = 10000

# ============================================================================
# 短前缀黑名单（易被误匹配的短前缀，需特殊处理）
# ============================================================================
SHORT_PREFIX_BLACKLIST = {'i-', 'a-', 'e-', 'o-', 'u-'}

# ============================================================================
# 全局变量（由 load_wordroot 填充，供 etymology 关联用）
# ============================================================================

wordroot_roots: dict = {}
wordroot_prefixes: dict = {}
wordroot_suffixes: dict = {}

# ============================================================================
# 工具函数
# ============================================================================

def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def _is_variant_form(word: str) -> bool:
    """判断一个词是否为'变体引用'，需在写入 Tree_Word 前过滤。

    变体引用格式：词根 + -数字后缀
    例如："a-1"（前缀 a 的第1个语义分类）、"an-2"（前缀 an 的第2个语义分类）
    数字后缀不是词根的一部分，而是语义分类标记，不应作为独立单词处理。

    判断依据：匹配正则 r'-\\d+$'（末尾是 -数字 形式）
    - "a-1"    → True  变体引用，过滤掉
    - "homage"  → False 真实单词，保留
    - "in-2"   → True  变体引用（in- 第2个语义），过滤掉
    - "inward"  → False 真实单词，保留
    """
    return bool(re.search(r'-\d+$', word))

# ============================================================================
# Exchange 解析
# ============================================================================

def parse_exchange(s: str) -> dict:
    result = {
        'past_tense': None, 'past_participle': None, 'present_participle': None,
        'third_person': None, 'comparative': None, 'superlative': None,
        'plural': None, 'lemma': None, 'lemma_variant': None
    }
    if not s:
        return result
    type_map = {
        'p': 'past_tense', 'd': 'past_participle', 'i': 'present_participle',
        '3': 'third_person', 'r': 'comparative', 't': 'superlative',
        's': 'plural', '0': 'lemma', '1': 'lemma_variant'
    }
    for item in s.split('/'):
        item = item.strip()
        if len(item) < 2:
            continue
        key, val = item[0], item[2:].strip()
        if key in type_map:
            result[type_map[key]] = val
    return result

# ============================================================================
# Etymology 构建（与 wordroot.txt 关联）
# ============================================================================

def build_etymology(word: str) -> dict:
    """
    根据 wordroot.txt 数据构建词根词缀 JSON。
    返回形如 {'prefix': 're-', 'prefixMeaning': 'again, back', ...}

    匹配策略（方向A）：
      1. 前缀：要求 word 以 prefix_clean 开头（严格前缀匹配）
      2. 后缀：要求 word 以 suffix_clean 结尾（严格后缀匹配）
      3. 词根：在 prefix 和 suffix 之间的区间内查找（避免子串误匹配）
      4. 短前缀特殊处理：i-/a-/e-/o-/u- 只匹配独立形式（后接非字母时）
    """
    result = {}
    word_lower = word.lower()

    # --- 前缀匹配：要求严格匹配到单词开头 ---
    matched_prefix = None
    matched_prefix_meaning = None
    for pf in sorted(wordroot_prefixes.keys(), key=len, reverse=True):
        pf_clean = pf.rstrip('-')
        if word_lower.startswith(pf_clean):
            # 短前缀黑名单：只匹配后面是非字母的情况（避免 in- 被 i- 匹配）
            if pf in SHORT_PREFIX_BLACKLIST:
                rest = word_lower[len(pf_clean):]
                if rest and rest[0].isalpha():
                    continue  # 跳过，如 "in-" 不会被 "i-" 匹配
            matched_prefix = pf
            matched_prefix_meaning = wordroot_prefixes[pf]
            break  # 前缀只应有一个

    if matched_prefix:
        result['prefix'] = matched_prefix
        result['prefixMeaning'] = matched_prefix_meaning

    # --- 后缀匹配：要求严格匹配到单词末尾 ---
    matched_suffix = None
    matched_suffix_meaning = None
    for sf in sorted(wordroot_suffixes.keys(), key=len, reverse=True):
        sf_clean = sf.lstrip('-')
        if word_lower.endswith(sf_clean):
            matched_suffix = sf
            matched_suffix_meaning = wordroot_suffixes[sf]
            break  # 后缀只应有一个

    if matched_suffix:
        result['suffix'] = matched_suffix
        result['suffixMeaning'] = matched_suffix_meaning

    # --- 词根匹配：在前缀之后、后缀之前的区间内查找 ---
    start_idx = 0
    if matched_prefix:
        start_idx = len(matched_prefix.rstrip('-'))
    end_idx = len(word_lower)
    if matched_suffix:
        end_idx -= len(matched_suffix.lstrip('-'))

    remaining = word_lower[start_idx:end_idx]

    matched_root = None
    matched_root_meaning = None
    for rt in sorted(wordroot_roots.keys(), key=len, reverse=True):
        if rt in remaining:
            matched_root = rt
            matched_root_meaning = wordroot_roots[rt]
            break

    # 回退：如果区间内没找到，在整个单词中搜索（降低精度要求）
    if not matched_root:
        for rt in sorted(wordroot_roots.keys(), key=len, reverse=True):
            if rt in word_lower:
                matched_root = rt
                matched_root_meaning = wordroot_roots[rt]
                break

    if matched_root:
        result['root'] = matched_root
        result['rootMeaning'] = matched_root_meaning

    return result

# ============================================================================
# resemble.txt 解析
# ============================================================================

def parse_resemble(filepath: str):
    """
    解析 resemble.txt，返回 (resemble_rows, word_to_resemble_dict)
    """
    resemble_rows, word_to_resemble = [], {}
    groups = []
    if not os.path.exists(filepath):
        print(f'[init_db] resemble.txt 不存在，跳过'); return [], {}

    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    cur_wl, cur_title, cur_detail = None, '', {}
    for line in content.split('\n'):
        line = line.rstrip('\r')
        if line.startswith('% '):
            if cur_wl is not None:
                groups.append((cur_wl, cur_title, cur_detail))
            cur_wl = line[2:].strip()
            cur_title, cur_detail = '', {}
        elif line.startswith('- '):
            rest = line[2:]
            if ':' in rest:
                w, d = rest.split(':', 1)
                cur_detail[w.strip().lower()] = d.strip()
        elif not line.startswith('%') and not line.startswith('-'):
            s = line.strip()
            if s and cur_wl is not None:
                cur_title = (cur_title + '\n' + s).strip()

    if cur_wl is not None:
        groups.append((cur_wl, cur_title, cur_detail))

    for wl, gt, det in groups:
        dj = json.dumps(det, ensure_ascii=False)
        resemble_rows.append((wl, gt, dj))
        for w in det:
            word_to_resemble[w.strip().lower()] = dj

    print(f'[init_db] resemble.txt 解析完成，共 {len(groups)} 组')
    return resemble_rows, word_to_resemble

# ============================================================================
# wordroot.txt 解析
# ============================================================================

def load_wordroot(conn, wordroot_path: str, valid_words: set = None):
    """
    解析 wordroot.txt，写入 Tree_Root + Tree_Word 表。
    同时填充全局 wordroot_roots/prefixes/suffixes（供 etymology 关联用）。

    valid_words: ECDICT 有效单词集合，用于过滤 Tree_Word 例词中不在 ecdict.csv 的孤儿
    """
    if not os.path.exists(wordroot_path):
        print('[init_db] wordroot.txt 不存在，跳过'); return

    global wordroot_roots, wordroot_prefixes, wordroot_suffixes

    conn.execute('DELETE FROM Tree_Word')
    conn.execute('DELETE FROM Tree_Root')
    cur = conn.cursor()

    with open(wordroot_path, 'r', encoding='utf-8') as f:
        root_data = json.load(f)

    wordroot_roots, wordroot_prefixes, wordroot_suffixes = {}, {}, {}

    print(f'[init_db] wordroot.txt 共 {len(root_data)} 个词根')
    rows, root_count = [], 0

    for root_id, data in root_data.items():
        # 过滤变体词根条目（如 "a-1"、"an-1"、"en-1" 等）
        # 这些是同一词根的不同语义分类，不应作为独立词根条目显示
        if _is_variant_form(root_id):
            continue

        meaning = data.get('meaning', '')
        origin = data.get('origin', '')
        root_function = data.get('function', '').replace('\r\n', '\n').strip()
        root_synonyms = data.get('synonyms', '').strip()
        root_antonyms = data.get('antonyms', '').strip()
        root_cls = data.get('class', '')
        examples = data.get('example', []) or []

        if root_id.startswith('-'):
            group = '后缀'
            wordroot_suffixes[root_id] = meaning
        elif root_id.endswith('-'):
            group = '前缀'
            wordroot_prefixes[root_id] = meaning
        else:
            group = root_cls or '词根'
            wordroot_roots[root_id] = meaning

        root_count += 1
        cur.execute(
            'INSERT OR REPLACE INTO Tree_Root '
            '(Root_ID,Root_Name,Root_Definition,Root_Group,Root_Origin,'
            'Root_Function,Root_Synonyms,Root_Antonyms) '
            'VALUES (?,?,?,?,?,?,?,?)',
            (f'wrd_{root_id}', root_id, meaning, group, origin,
             root_function, root_synonyms, root_antonyms)
        )

        for sort_order, spelling in enumerate(examples):
            spelling_lower = spelling.strip().lower()
            if not spelling_lower:
                continue
            # 过滤变体引用（如 "a-1"、"an-2"）
            if _is_variant_form(spelling_lower):
                continue
            # 跳过无效例词（与 load_ecdict 过滤条件对齐）：
            #   - 以 - 开头（后缀碎片，如 -less）
            #   - 以 ' 开头（前缀/缩写碎片，如 's）
            if spelling_lower.startswith('-') or spelling_lower.startswith("'"):
                continue
            # 跳过不在 ecdict.csv 的孤儿例词（需要 valid_words 集合）
            if valid_words is not None and spelling_lower not in valid_words:
                continue
            concept_uuid = f'note_{spelling_lower}'
            rows.append((f'wrd_{root_id}', concept_uuid, spelling_lower, sort_order))

    for i in range(0, len(rows), BATCH_SIZE):
        batch = rows[i:i + BATCH_SIZE]
        cur.executemany(
            'INSERT OR IGNORE INTO Tree_Word '
            '(Root_ID,Concept_UUID,Compound_Form,Sort_Order) '
            'VALUES (?,?,?,?)',
            batch
        )
        conn.commit()
        print(f'  Tree_Word 已写入 {min(i + BATCH_SIZE, len(rows))}/{len(rows)} 条...')

    print(f'[init_db] Tree_Root {root_count} 个，Tree_Word {len(rows)} 条')

# ============================================================================
# ecdict.csv 解析
# ============================================================================

def load_ecdict(conn, csv_path: str, word_to_resemble: dict) -> dict:
    """
    解析 ecdict.csv，写入 Note 表。
    返回词书统计 dict: {book_id: count}
    """
    tag_to_book = {
        'cet4': 'cet4',
        'cet6': 'cet6',
        'ky': 'kaoyan',
        'zk': 'cet4',
        'toefl': 'toefl',
        'ielts': 'ielts',
        'gre': 'gre',
    }
    book_ids = list(tag_to_book.values()) + ['kaoyan2027']
    book_counts = {bid: 0 for bid in set(book_ids)}

    conn.execute('DELETE FROM Note')
    cur = conn.cursor()
    note_rows, total = [], 0

    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            word = row.get('word', '').strip().lower()
            # 跳过无效单词：
            #   - 空单词
            #   - 含空格（词组，如 "incremental duplex"）
            #   - 不含任何字母（纯数字、符号等）
            #   - 首字符非法（不以字母开头，如 .45-caliber、1st）
            #   - 第二字符非法（a'xx、a-xxx、a1、a. 等，如 A'man、a-）
            #   - 以 - 开头（后缀碎片，如 -aholic、-algia、-hood）
            #   - 以 ' 开头（前缀/缩写碎片，如 'hood、's）
            if not word or ' ' in word or not any(c.isalpha() for c in word) \
               or not word[0].isalpha() \
               or (len(word) >= 2 and not word[1].isalpha()) \
               or word.startswith('-') or word.startswith("'"):
                continue

            phonetic = row.get('phonetic', '').strip()
            def_zh = row.get('translation', '').strip()
            def_en = row.get('definition', '').strip()
            pos = row.get('pos', '').strip()
            collins = int(row.get('collins', '0').strip() or '0')
            bnc = int(row.get('bnc', '0').strip() or '0')
            frq = int(row.get('frq', '0').strip() or '0')
            tag = row.get('tag', '').strip()
            ex_str = row.get('exchange', '').strip()
            detail = row.get('detail', '').strip()
            is_oxford = 1 if row.get('oxford', '0').strip() == '1' else 0
            tags = tag.split() if tag else []

            for t in tags:
                if t in tag_to_book:
                    bid = tag_to_book[t]
                    book_counts[bid] += 1
                    if t == 'cet4':
                        book_counts['cet6'] += 1
                        book_counts['kaoyan'] += 1
                        book_counts['kaoyan2027'] += 1
                    elif t == 'ky':
                        book_counts['kaoyan'] += 1
                        book_counts['kaoyan2027'] += 1

            ex = parse_exchange(ex_str)
            tag_list = json.dumps(tags) if tags else None
            synonym = word_to_resemble.get(word)

            etymology = build_etymology(word)
            etymology_json = json.dumps(etymology, ensure_ascii=False)

            micro_ctx = json.dumps({'en': detail, 'zh': ''}, ensure_ascii=False)
            content = json.dumps({
                'spelling': word,
                'phonetic': phonetic,
                'definition': def_zh,
                'example': detail,
            }, ensure_ascii=False)

            note_rows.append((
                f'note_{word}', word, phonetic or '', def_zh or '',
                etymology_json, micro_ctx, content,
                bnc, frq, collins,
                def_en or None, detail or None,
                ex['past_tense'], ex['past_participle'],
                ex['present_participle'], ex['third_person'],
                ex['comparative'], ex['superlative'],
                ex['plural'], ex['lemma'], ex['lemma_variant'],
                pos or None, tag_list, synonym,
                is_oxford,   # oxford=1 → Oxford_3000=1, Oxford_5000=0
                is_oxford,   # Oxford_3000 follows oxford field
                0,           # Oxford_5000 always 0 (no separate oxford5000 tag in source)
            ))
            total += 1

            if len(note_rows) >= BATCH_SIZE:
                cur.executemany(
                    'INSERT OR REPLACE INTO Note VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                    note_rows
                )
                conn.commit()
                print(f'  Note 已写入 {total} 条...')
                note_rows = []

    if note_rows:
        cur.executemany(
            'INSERT OR REPLACE INTO Note VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
            note_rows
        )
        conn.commit()

    print(f'[init_db] Note 写入完成，共 {total} 条')
    return book_counts

# ============================================================================
# 表创建（与 Dart database.dart 完全对齐）
# ============================================================================

def create_tables(conn):
    conn.execute('PRAGMA journal_mode=WAL')
    conn.execute('PRAGMA synchronous=NORMAL')

    conn.execute('''CREATE TABLE IF NOT EXISTS Note (
        Concept_UUID TEXT PRIMARY KEY, Spelling TEXT NOT NULL, Phonetic TEXT NOT NULL,
        Definition TEXT NOT NULL, Etymology_JSON TEXT, Micro_Context_JSON TEXT NOT NULL,
        Content_JSON TEXT NOT NULL, BNC INTEGER DEFAULT 0, FRQ INTEGER DEFAULT 0,
        Collins_Star INTEGER DEFAULT 0, Definition_En TEXT, Example_Sentence TEXT,
        Past_Tense TEXT, Past_Participle TEXT, Present_Participle TEXT,
        Third_Person TEXT, Comparative TEXT, Superlative TEXT, Plural TEXT,
        Lemma TEXT, Lemma_Variant TEXT, Part_Of_Speech TEXT, Tag_List TEXT,
        Synonym_JSON TEXT, Is_Oxford INTEGER DEFAULT 0,
        Oxford_3000 INTEGER DEFAULT 0, Oxford_5000 INTEGER DEFAULT 0
    )''')

    conn.execute('''CREATE TABLE IF NOT EXISTS Resemble (
        Group_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Word_List TEXT NOT NULL UNIQUE,
        Group_Title TEXT NOT NULL,
        Detail_JSON TEXT NOT NULL
    )''')

    conn.execute('''CREATE TABLE IF NOT EXISTS Tree_Root (
        Root_ID TEXT PRIMARY KEY, Root_Name TEXT NOT NULL,
        Root_Definition TEXT NOT NULL, Root_Group TEXT NOT NULL,
        Root_Origin TEXT DEFAULT '',
        Root_Function TEXT DEFAULT '',
        Root_Synonyms TEXT DEFAULT '',
        Root_Antonyms TEXT DEFAULT ''
    )''')

    conn.execute('''CREATE TABLE IF NOT EXISTS Tree_Word (
        Tree_Word_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        Root_ID TEXT NOT NULL, Concept_UUID TEXT NOT NULL,
        Compound_Form TEXT NOT NULL, Sort_Order INTEGER DEFAULT 0,
        FOREIGN KEY (Root_ID) REFERENCES Tree_Root(Root_ID),
        FOREIGN KEY (Concept_UUID) REFERENCES Note(Concept_UUID)
    )''')

    conn.execute('CREATE INDEX IF NOT EXISTS idx_note_spelling ON Note(Spelling)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_note_taglist ON Note(Tag_List)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_tree_word_root ON Tree_Word(Root_ID)')
    conn.execute('CREATE INDEX IF NOT EXISTS idx_tree_word_uuid ON Tree_Word(Concept_UUID)')

    conn.commit()

# ============================================================================
# Note JSON 生成（Web 端用，每卷 50000 条）
# ============================================================================

def generate_notes_json(conn, output_path: str):
    """将 Note 表导出为 Web 端可读取的分卷 JSON"""
    base_dir = os.path.dirname(output_path)  # e.g. ...assets/ecdict/
    db_name = os.path.splitext(os.path.basename(output_path))[0]  # e.g. ecdict
    manifest = {'chunks': []}
    chunk_size = 50000

    cur = conn.cursor()
    cur.execute('SELECT * FROM Note ORDER BY ROWID')
    cols = [d[0] for d in cur.description]

    idx = 0
    while True:
        rows = cur.fetchmany(chunk_size)
        if not rows:
            break
        chunk = [dict(zip(cols, row)) for row in rows]
        fname = f'{db_name}_notes_p{idx}.json'
        with open(os.path.join(base_dir, fname), 'w', encoding='utf-8') as f:
            json.dump(chunk, f, ensure_ascii=False)
        manifest['chunks'].append(fname)
        idx += 1

    with open(os.path.join(base_dir, f'{db_name}_notes_manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f)

    print(f'[init_db] Note: 共 {idx} 卷（每卷 {chunk_size} 条）')

# ============================================================================
# Web 专用 JSON 生成（Resemble + Tree）
# ============================================================================

def generate_web_json_files(conn, output_path: str):
    """导出 Resemble、Tree_Root、Tree_Word 为 Web 端 JSON"""
    base_dir = os.path.dirname(output_path)
    db_name = os.path.splitext(os.path.basename(output_path))[0]
    cur = conn.cursor()

    # Resemble
    cur.execute('SELECT * FROM Resemble')
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, row)) for row in cur]
    with open(os.path.join(base_dir, f'{db_name}_resemble.json'), 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False)
    print(f'[init_db] ecdict_resemble.json: {len(rows)} 组')

    # Tree_Root
    cur.execute('SELECT * FROM Tree_Root')
    cols = [d[0] for d in cur.description]
    rows = [dict(zip(cols, row)) for row in cur]
    with open(os.path.join(base_dir, f'{db_name}_tree_root.json'), 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False)
    print(f'[init_db] ecdict_tree_root.json: {len(rows)} 条')

    # Tree_Word 分卷（每卷 10万条）
    cur.execute('SELECT * FROM Tree_Word ORDER BY ROWID')
    cols = [d[0] for d in cur.description]
    all_words = [dict(zip(cols, row)) for row in cur]
    manifest = {'chunks': []}
    chunk_size = 100000
    for i in range(0, len(all_words), chunk_size):
        chunk = all_words[i:i + chunk_size]
        fname = f'{db_name}_tree_word_p{i // chunk_size}.json'
        with open(os.path.join(base_dir, fname), 'w', encoding='utf-8') as f:
            json.dump(chunk, f, ensure_ascii=False)
        manifest['chunks'].append(fname)
    with open(os.path.join(base_dir, f'{db_name}_tree_word_manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f)
    print(f'[init_db] Tree_Word: {len(all_words)} 条共 {len(manifest["chunks"])} 卷')

# ============================================================================
# 词书统计保存
# ============================================================================

def save_book_counts(book_counts: dict, output_path: str):
    base_dir = os.path.dirname(output_path)
    db_name = os.path.splitext(os.path.basename(output_path))[0]
    path = os.path.join(base_dir, f'{db_name}_book_counts.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(book_counts, f, ensure_ascii=False)
    print(f'[init_db] 词书统计: {book_counts}')

def verify_data_quality(conn, csv_path: str, output_path: str):
    """
    生成完成后执行数据质量验证。

    验证项：
      1. Note 表行数与 CSV 有效行数一致（允许小量差异因空单词被过滤）
      2. Tree_Word.Concept_UUID 全部存在于 Note 表（外键一致性）
      3. 词书统计数字在合理范围
      4. ecdict.db 文件大小在预期范围（50-300MB）
      5. Oxford 标签分布合理（oxford=1 的词应有合理占比）
      6. Resemble 表关联的单词都存在于 Note 表
    """
    cur = conn.cursor()
    errors = []
    warnings = []

    # 1. Note 表行数验证
    cur.execute('SELECT COUNT(*) FROM Note')
    note_count = cur.fetchone()[0]
    print(f'\n[验证] Note 表行数: {note_count:,}')

    csv_valid_count = 0
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row.get('word', '').strip():
                csv_valid_count += 1
    print(f'[验证] CSV 有效行数: {csv_valid_count:,}')

    diff = abs(note_count - csv_valid_count)
    if note_count == 0:
        errors.append(f'Note 表为空！')
    elif diff > csv_valid_count * 0.05:
        warnings.append(f'Note 表与 CSV 行数差异 {diff} ({diff/csv_valid_count*100:.1f}%)，超过 5%，请检查')
    else:
        print(f'[验证] [OK] Note 行数合理（差异 {diff} 条，占 {diff/csv_valid_count*100:.2f}%）')

    # 2. Tree_Word 外键一致性验证
    cur.execute('''
        SELECT COUNT(*) FROM Tree_Word tw
        WHERE NOT EXISTS (SELECT 1 FROM Note n WHERE n.Concept_UUID = tw.Concept_UUID)
    ''')
    orphan_count = cur.fetchone()[0]
    if orphan_count > 0:
        warnings.append(f'Tree_Word 中有 {orphan_count} 条 Concept_UUID 在 Note 表中不存在')
        print(f'[验证] [WARN] Tree_Word 孤儿记录: {orphan_count} 条')
    else:
        print('[验证] [OK] Tree_Word 外键一致性通过')

    # 3. Resemble 单词关联验证
    resemble_orphan = 0
    cur.execute('SELECT Word_List FROM Resemble')
    for (wl,) in cur:
        words = re.findall(r'\b\w+\b', wl.lower())
        for w in words:
            cur2 = conn.cursor()
            cur2.execute('SELECT 1 FROM Note WHERE Spelling = ? LIMIT 1', (w,))
            if not cur2.fetchone():
                resemble_orphan += 1
                print(f'[验证] [WARN] Resemble 中单词 "{w}" 不在 Note 表中')
                break
    if resemble_orphan == 0:
        print('[验证] [OK] Resemble 单词关联全部存在于 Note 表')
    else:
        warnings.append(f'Resemble 中有 {resemble_orphan} 组单词不在 Note 表中')

    # 4. 文件大小验证
    db_size = os.path.getsize(output_path)
    db_size_mb = db_size / (1024 * 1024)
    print(f'[验证] ecdict.db 文件大小: {db_size_mb:.1f} MB')
    if db_size_mb < 50:
        errors.append(f'数据库文件过小（{db_size_mb:.1f} MB < 50MB），数据可能不完整')
    elif db_size_mb > 300:
        warnings.append(f'数据库文件过大（{db_size_mb:.1f} MB > 300MB），请确认是否有异常')
    else:
        print('[验证] [OK] 文件大小正常')

    # 5. Oxford 标签分布验证
    cur.execute('SELECT COUNT(*) FROM Note WHERE Is_Oxford = 1')
    oxford_count = cur.fetchone()[0]
    oxford_pct = oxford_count / note_count * 100 if note_count > 0 else 0
    print(f'[验证] Oxford 词数: {oxford_count:,} ({oxford_pct:.1f}%)')
    if oxford_pct < 1 or oxford_pct > 50:
        warnings.append(f'Oxford 词占比 {oxford_pct:.1f}% 异常（期望 1%-50%）')
    else:
        print('[验证] [OK] Oxford 标签分布合理')

    # 6. 词书统计合理性
    book_counts_path = os.path.join(
        os.path.dirname(output_path),
        f'{os.path.splitext(os.path.basename(output_path))[0]}_book_counts.json'
    )
    if os.path.exists(book_counts_path):
        with open(book_counts_path, 'r', encoding='utf-8') as f:
            book_counts = json.load(f)
        print(f'[验证] 词书统计: {book_counts}')
        if book_counts.get('cet4', 0) < 3000:
            warnings.append(f'cet4 词数 {book_counts.get("cet4")} 过少，请检查 tag 解析')
        if book_counts.get('cet6', 0) < 5000:
            warnings.append(f'cet6 词数 {book_counts.get("cet6")} 过少，请检查 tag 解析')
    else:
        print('[验证] [WARN] 词书统计文件不存在，跳过此项验证')

    # 汇总
    print('\n' + '=' * 60)
    if errors:
        print(f'[错误] ({len(errors)} 项)：')
        for e in errors:
            print(f'   - {e}')
    if warnings:
        print(f'[警告] ({len(warnings)} 项)：')
        for w in warnings:
            print(f'   - {w}')
    if not errors and not warnings:
        print('[OK] 所有验证通过！')
    print('=' * 60)

    return len(errors) == 0

# ============================================================================
# main
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description='预生成 ecdict.db + Web JSON')
    parser.add_argument('--output', default=os.path.join(ASSETS_DIR, 'ecdict.db'))
    parser.add_argument('--csv',    default=os.path.join(ECDICT_SOURCE_DIR, 'ecdict.csv'))
    parser.add_argument('--wordroot', default=os.path.join(ECDICT_SOURCE_DIR, 'wordroot.txt'))
    parser.add_argument('--resemble', default=os.path.join(ECDICT_SOURCE_DIR, 'resemble.txt'))
    parser.add_argument('--skip-db', action='store_true', help='跳过数据库创建，只重新生成 JSON 文件')
    parser.add_argument('--no-verify', action='store_true', help='跳过数据质量验证')
    args = parser.parse_args()

    ensure_dir(os.path.dirname(args.output))
    print(f'[init_db] 输出目录: {os.path.dirname(args.output)}')

    if args.skip_db:
        # 仅重新生成 JSON，假设 DB 已存在
        conn = sqlite3.connect(args.output)
        print('[init_db] --skip-db: 仅重新生成 JSON 文件')
    else:
        # 删除旧数据库
        if os.path.exists(args.output):
            os.remove(args.output)
            print(f'[init_db] 已删除旧数据库: {args.output}')

        conn = sqlite3.connect(args.output)
        create_tables(conn)

        # 1. 解析近义词
        resemble_rows, w2r = parse_resemble(args.resemble)
        conn.executemany(
            'INSERT OR REPLACE INTO Resemble (Word_List,Group_Title,Detail_JSON) VALUES (?,?,?)',
            resemble_rows
        )
        conn.commit()

        # 2. 收集 ECDICT CSV 有效单词集合（用于 Tree_Word 外键过滤）
        valid_words = set()
        with open(args.csv, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                word = row.get('word', '').strip().lower()
                if not word or ' ' in word or not any(c.isalpha() for c in word) \
                   or word.startswith('-') or word.startswith("'"):
                    continue
                valid_words.add(word)
        print(f'[init_db] ECDICT 有效单词: {len(valid_words)} 个')

        # 3. 加载 wordroot（依赖 valid_words 过滤 Tree_Word 孤儿）
        load_wordroot(conn, args.wordroot, valid_words)

        # 4. 加载 ECDICT CSV
        book_counts = load_ecdict(conn, args.csv, w2r)

    # 4. 生成 Note 分卷 JSON（Web 端用）
    generate_notes_json(conn, args.output)

    # 5. 生成 Web 专用 JSON（Resemble + Tree）
    generate_web_json_files(conn, args.output)

    # 6. 保存词书统计（仅在非 skip-db 模式下）
    if not args.skip_db:
        save_book_counts(book_counts, args.output)

    # 7. 数据质量验证（v2.0 新增）
    if not args.no_verify:
        verify_data_quality(conn, args.csv, args.output)

    conn.close()
    print(f'[init_db] 完成: {args.output}')

if __name__ == '__main__':
    main()
