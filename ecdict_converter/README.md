# ECDICT to Goldene ROM Converter

将 [ECDICT](https://github.com/skywind3000 ECDICT) 词典转换为 goldene SRS 应用的 ROM SQLite 数据库。

## 功能

- 将 ECDICT 76万词条 CSV 数据转换为 goldene ROM SQLite 格式
- 支持按词书标签过滤 (CET-4/CET-6/考研/托福/雅思/GRE)
- 从 wordroot.txt 生成词根树 (Tree_Root + Tree_Word) 数据
- 自动构建话题阅读文章 (Topic + Article)
- 生成完整的 SQLite 数据库，可直接替换 `wordmemory_rom.db`

## 使用方法

### 前置准备

```bash
# 克隆或下载 ECDICT 项目到同级目录
# 确保有以下文件：
#   - ecdict.csv          (完整版，约76万词条)
#   - ecdict.mini.csv     (精简版，约4万词条)
#   - wordroot.txt        (词根数据)
```

### 完整转换（使用默认 ecdict.csv）

```bash
cd ecdict_converter
python convert.py --input ../path/to/ecdict.csv --wordroot ../path/to/wordroot.txt --output wordmemory_rom.db
```

### 使用精简版（约4万词）

```bash
python convert.py --mini --output wordmemory_rom.db
```

### 按词书转换

```bash
# 考研词汇
python convert.py --book kaoyan --output wordmemory_rom.db

# CET-6
python convert.py --book cet6 --output wordmemory_rom_ce6.db

# TOEFL
python convert.py --book toefl --output wordmemory_rom_toefl.db

# GRE
python convert.py --book gre --output wordmemory_rom_gre.db
```

### 限制词汇数量（用于测试）

```bash
# 仅转换前 1000 条，用于快速测试
python convert.py --mini --limit 1000 --max-rows 1000 --output test_rom.db
```

## 输出数据库

生成的 SQLite 文件包含以下表：

| 表名 | 说明 |
|------|------|
| Note | 词汇基础信息 |
| Tree_Root | 词根目录 |
| Tree_Word | 词根派生词关联 |
| Topic | 话题分类 |
| Article | 话题阅读文章 |

## ECDICT 字段映射

| ECDICT 字段 | Goldene 字段 |
|-------------|--------------|
| word | Spelling |
| phonetic | Phonetic |
| definition | Definition |
| translation | (保留在 Content_JSON 中) |
| tag | (按词书过滤使用) |
| exchange | (用于词根关联) |
| detail | (用于 Micro_Context_JSON 例句) |

## 依赖

- Python 3.8+
- 标准库: `csv`, `json`, `sqlite3`, `re`, `argparse`
- 无第三方依赖

## 常见问题

**Q: CSV 解析报错？**
A: ECDICT CSV 使用单引号包裹字段，可能包含换行符。脚本使用手动解析器处理此格式。

**Q: 词根数据不完整？**
A: wordroot.txt 是可选的。脚本会自动处理缺失的词根文件。

**Q: 生成的数据库如何使用？**
A: 将输出的 `.db` 文件重命名为 `wordmemory_rom.db`，替换安装包中的同名文件。
