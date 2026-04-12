library wordmemory.database;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================================
// 辅助函数
// ============================================================================

/// 判断 Unicode 码点是否为 ASCII 字母（a-z / A-Z），不依赖 RegExp 以保证性能
bool _isAlpha(int codeUnit) {
  return (codeUnit >= 0x61 && codeUnit <= 0x7a) ||
         (codeUnit >= 0x41 && codeUnit <= 0x5a);
}

// ============================================================================
// WordMemory SRS - Database Schema
// 对应文档：词汇SRS&SDD v2.1 第 4 节
// ============================================================================

// ============================================================================
// ROM 数据库初始化
// ============================================================================

/// ROM 数据库文件名（可被外部预生成的 ECDICT 数据库替换）
/// 优先级：外部文件 > 内置示例数据
const String kRomDbName = 'wordmemory_rom.db';
/// Hot Data（读写，用户私有目录）
const String kHotDbName = 'wordmemory_hot.db';

// ROM 表名
const String kTableNote = 'Note';
const String kTableTreeRoot = 'Tree_Root';
const String kTableTreeWord = 'Tree_Word';
const String kTableTopic = 'Topic';
const String kTableArticle = 'Article';

// Hot 表名
const String kTableCard = 'Card';
const String kTableReviewLog = 'Review_Log';
const String kTableQuickScreen = 'Quick_Screen';
const String kTableUserSettings = 'User_Settings';

// ============================================================================
// 辅助函数
// ============================================================================

String _dbPath(String name, String dbDir) => join(dbDir, name);

/// 检查 asset 是否存在（通过尝试加载判断）
Future<bool> _assetExists(String assetPath) async {
  try {
    await rootBundle.loadString(assetPath);
    return true;
  } catch (_) {
    return false;
  }
}

// ============================================================================
// ROM Data 建表脚本
// ============================================================================

const String kCreateNoteSql = '''
CREATE TABLE Note (
    -- 核心字段
    Concept_UUID TEXT PRIMARY KEY,
    Spelling TEXT NOT NULL,
    Phonetic TEXT NOT NULL,
    Definition TEXT NOT NULL,
    Etymology_JSON TEXT,
    Micro_Context_JSON TEXT NOT NULL,
    Content_JSON TEXT NOT NULL,

    -- ECDICT 词频
    BNC INTEGER DEFAULT 0,
    FRQ INTEGER DEFAULT 0,

    -- 柯林斯星级（来自 ecdict.csv collins 列，0-5）
    Collins_Star INTEGER DEFAULT 0,

    -- 英语释义（来自 ecdict.csv definition 列）
    Definition_En TEXT,

    -- 例句（来自 ecdict.csv detail 列）
    Example_Sentence TEXT,

    -- 时态/变形（完整解析 ecdict.csv exchange 列）
    Past_Tense TEXT,
    Past_Participle TEXT,
    Present_Participle TEXT,
    Third_Person TEXT,
    Comparative TEXT,
    Superlative TEXT,
    Plural TEXT,
    Lemma TEXT,
    Lemma_Variant TEXT,

    -- 词性（解析 ecdict.csv pos 列，取占比最高的词性）
    Part_Of_Speech TEXT,

    -- 词书标签（解析 ecdict.csv tag 列，JSON 数组）
    Tag_List TEXT,

    -- 近义词辨析（来自 resemble.txt，完整 JSON）
    Synonym_JSON TEXT,

    -- Oxford 标识
    Is_Oxford INTEGER DEFAULT 0,
    Oxford_3000 INTEGER DEFAULT 0,
    Oxford_5000 INTEGER DEFAULT 0
) STRICT;
''';

/// Resemble 表：存储 ECDICT resemble.txt 近义词辨析数据
/// 每个词组一行，Word_List 唯一（UNIQUE 约束）
const String kCreateResembleSql = '''
CREATE TABLE Resemble (
    Group_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Word_List TEXT NOT NULL UNIQUE,
    Group_Title TEXT NOT NULL,
    Detail_JSON TEXT NOT NULL
) STRICT;
CREATE INDEX idx_resemble_wordlist ON Resemble(Word_List);
''';

const String kCreateTreeRootSql = '''
CREATE TABLE Tree_Root (
    Root_ID TEXT PRIMARY KEY,
    Root_Name TEXT NOT NULL,
    Root_Definition TEXT NOT NULL,
    Root_Group TEXT NOT NULL,
    Root_Origin TEXT DEFAULT '',
    Root_Function TEXT DEFAULT '',
    Root_Synonyms TEXT DEFAULT '',
    Root_Antonyms TEXT DEFAULT ''
) STRICT;
''';

const String kCreateTreeWordSql = '''
CREATE TABLE Tree_Word (
    Tree_Word_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Root_ID TEXT NOT NULL,
    Concept_UUID TEXT NOT NULL,
    Compound_Form TEXT NOT NULL,
    Sort_Order INTEGER DEFAULT 0,
    FOREIGN KEY (Root_ID) REFERENCES Tree_Root(Root_ID),
    FOREIGN KEY (Concept_UUID) REFERENCES Note(Concept_UUID)
) STRICT;
''';

const String kCreateTopicSql = '''
CREATE TABLE Topic (
    Topic_ID TEXT PRIMARY KEY,
    Topic_Name TEXT NOT NULL,
    Topic_Name_EN TEXT NOT NULL,
    Word_Count INTEGER NOT NULL
) STRICT;
''';

const String kCreateArticleSql = '''
CREATE TABLE Article (
    Article_ID TEXT PRIMARY KEY,
    Topic_ID TEXT NOT NULL,
    Content_JSON TEXT NOT NULL,
    Word_Count INTEGER NOT NULL,
    FOREIGN KEY (Topic_ID) REFERENCES Topic(Topic_ID)
) STRICT;
''';

// ============================================================================
// Hot Data 建表脚本
// ============================================================================

const String kCreateCardSql = '''
CREATE TABLE Card (
    Card_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Concept_UUID TEXT NOT NULL UNIQUE,
    Status INTEGER NOT NULL,
    Next_Review_Date INTEGER NOT NULL,
    Last_Review_Date INTEGER DEFAULT 0,
    Last_Review_Log_ID INTEGER,
    R REAL NOT NULL,
    S REAL NOT NULL,
    Fail_Count INTEGER DEFAULT 0,
    Favorite INTEGER DEFAULT 0,
    Topic_Read INTEGER DEFAULT 0,
    Tree_Visit INTEGER DEFAULT 0,
    Random_Sort_ID INTEGER NOT NULL,
    Tag_List TEXT
) STRICT;
CREATE INDEX idx_card_schedule ON Card(Next_Review_Date, (Status & 0x0F));
CREATE INDEX idx_card_uuid ON Card(Concept_UUID);
CREATE INDEX idx_card_favorite ON Card(Favorite);
CREATE INDEX idx_card_random ON Card(Random_Sort_ID);
''';

const String kCreateReviewLogSql = '''
CREATE TABLE Review_Log (
    Log_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Concept_UUID TEXT NOT NULL,
    Rating INTEGER NOT NULL,
    Log_Date INTEGER NOT NULL,
    Local_Date_Str TEXT NOT NULL,
    Pre_Status INTEGER NOT NULL,
    Pre_R REAL NOT NULL,
    Pre_S REAL NOT NULL
) STRICT;
CREATE INDEX idx_review_log_date ON Review_Log(Log_Date);
CREATE INDEX idx_review_log_local_date ON Review_Log(Local_Date_Str);
''';

const String kCreateQuickScreenSql = '''
CREATE TABLE Quick_Screen (
    Screen_ID INTEGER PRIMARY KEY AUTOINCREMENT,
    Concept_UUID TEXT NOT NULL UNIQUE,
    Status INTEGER NOT NULL,
    Screen_Date INTEGER NOT NULL
) STRICT;
CREATE INDEX idx_quick_screen_uuid ON Quick_Screen(Concept_UUID);
''';

const String kCreateUserSettingsSql = '''
CREATE TABLE User_Settings (
    Key TEXT PRIMARY KEY,
    Value TEXT NOT NULL
) STRICT;
''';

/// WordBook 表：动态管理词书元数据
/// 用途：SettingPage 词书选项从数据库加载，替代硬编码
/// 对应 SRS&SDD v2.1 附录 B：词书系统
const String kCreateWordBookSql = '''
CREATE TABLE WordBook (
    Book_ID TEXT PRIMARY KEY,
    Book_Name TEXT NOT NULL,
    Book_Name_EN TEXT NOT NULL,
    Word_Count INTEGER NOT NULL DEFAULT 0,
    Tag_List TEXT NOT NULL,
    Description TEXT NOT NULL,
    Sort_Order INTEGER NOT NULL DEFAULT 0,
    Is_Default INTEGER NOT NULL DEFAULT 0
) STRICT;
CREATE INDEX idx_wordbook_sort ON WordBook(Sort_Order);
''';

// ============================================================================
// ROM 数据库初始化
// ============================================================================

Future<Database> openRomDatabase(String dbDir) async {
  final path = _dbPath(kRomDbName, dbDir);
  print('[DB] openRomDatabase path=$path');

  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      print('[DB] ROM onCreate 开始');
      await db.execute('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA wal_autocheckpoint=1000');
      await db.execute(kCreateNoteSql);
      await db.execute(kCreateResembleSql);
      await db.execute(kCreateTreeRootSql);
      await db.execute(kCreateTreeWordSql);
      await db.execute(kCreateTopicSql);
      await db.execute(kCreateArticleSql);
      await _seedSemanticReadingData(db);
      print('[DB] ROM onCreate 完成');
    },
    onOpen: (db) async {
      print('[DB] ROM onOpen 开始');
      await _ensureRomDataIntegrity(db);
      await _ensureSemanticReadingDataSeeded(db);
      print('[DB] ROM onOpen 完成');
    },
  );
}

/// 确保 ROM 数据完整性。如果 Tree_Root 表为空则重新写入结构树示例数据
///
/// 如果 ROM 文件存在但 Tree_Root 表为空，从预编译 DB 加载结构树数据
Future<void> _ensureRomDataIntegrity(Database db) async {
  print('[DB] _ensureRomDataIntegrity 开始');
  final rootCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Tree_Root'));
  print('[DB] _ensureRomDataIntegrity Tree_Root数量=$rootCount');
  if (rootCount == null || rootCount == 0) {
    print('[DB] _ensureRomDataIntegrity Tree_Root为空，从预编译 DB 加载...');
    // 预编译 DB 数据在 seedHotDataIfNeeded → _loadFromPrebuiltDb 中处理
    // 此处仅保留空实现，由热库初始化统一触发
    print('[DB] _ensureRomDataIntegrity 补种完成');
  } else {
    print('[DB] _ensureRomDataIntegrity Tree_Root已有 ${rootCount} 条，使用已有数据');
  }
  print('[DB] _ensureRomDataIntegrity 结束');
}

/// 公共导出版本，供 provider.dart 调用
Future<void> ensureRomDataIntegrity(Database db) => _ensureRomDataIntegrity(db);

// ============================================================================
// 语义阅读专题：科技阅读（词级高亮演示）
// --------------------------------------------------------------------------
Future<void> _seedSemanticReadingData(Database db) async {
  // Note：evolution / efficiency / digital / frequently
  final evolutionNote = {
    'Concept_UUID': 'note_evolution',
    'Spelling': 'evolution',
    'Phonetic': '/ˌiːvəˈluːʃn/',
    'Definition': 'n. 进化；演变；发展',
    'Etymology_JSON': '{"roots":[{"root":"e-","meaning":"外、出"},{"root":"vol","meaning":"卷、转"},{"root":"-ution","meaning":"过程"}],"compound":"e(出)+vol(转)+ution(过程)→转出来→进化","final":"进化"}',
    'Micro_Context_JSON': '{"zh":"The evolution of communication technology illustrates humanity\'s pursuit of efficiency.","en":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency."}',
    'Content_JSON': '{"spelling":"evolution","phonetic":"/ˌiːvəˈluːʃn/","definition":"n. 进化；演变；发展","etymology":"e-(出)+vol(转)+-ution(过程)→转出来→进化","example":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency.","translation":"通信技术的演变生动地说明了人类对效率的不懈追求。"}',
  };
  final efficiencyNote = {
    'Concept_UUID': 'note_efficiency',
    'Spelling': 'efficiency',
    'Phonetic': '/ɪˈfɪʃnsi/',
    'Definition': 'n. 效率；效能',
    'Etymology_JSON': '{"roots":[{"root":"ef-","meaning":"出"},{"root":"fic","meaning":"做"},{"root":"-iency","meaning":"性质/状态"}],"compound":"ef(出)+fic(做)+-iency(性质)→做出来的效果→效率","final":"效率"}',
    'Micro_Context_JSON': '{"zh":"The telegraph was a crude device to transmit signals across vast distances.","en":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency."}',
    'Content_JSON': '{"spelling":"efficiency","phonetic":"/ɪˈfɪʃnsi/","definition":"n. 效率；效能","etymology":"ef-(出)+fic(做)+-iency(性质)→做出来的效果→效率","example":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency.","translation":"通信技术的演变生动地说明了人类对效率的不懈追求。"}',
  };
  final digitalNote = {
    'Concept_UUID': 'note_digital',
    'Spelling': 'digital',
    'Phonetic': '/ˈdɪdʒɪtl/',
    'Definition': 'adj. 数字的；数码的',
    'Etymology_JSON': '{"roots":[{"root":"digit","meaning":"手指/数字"},{"root":"-al","meaning":"...的"}],"compound":"digit(数字)+-al(...的)→数字的","final":"数字的"}',
    'Micro_Context_JSON': '{"zh":"In the digital age, we rely heavily on technology.","en":"In the digital age, the proliferation of digital devices makes modern life increasingly demanding."}',
    'Content_JSON': '{"spelling":"digital","phonetic":"/ˈdɪdʒɪtl/","definition":"adj. 数字的；数码的","etymology":"digit(数字)+-al(...的)→数字的","example":"In the digital age, the proliferation of digital devices makes modern life increasingly demanding.","translation":"在数字时代，数字设备的普及使现代生活日益 demanding。"}',
  };
  final frequentlyNote = {
    'Concept_UUID': 'note_frequently',
    'Spelling': 'frequently',
    'Phonetic': '/ˈfriːkwəntli/',
    'Definition': 'adv. 频繁地；经常地',
    'Etymology_JSON': '{"roots":[{"root":"frequent","meaning":"频繁的"},{"root":"-ly","meaning":"副词后缀"}],"compound":"frequent(频繁的)+-ly(副词)→频繁地","final":"频繁地"}',
    'Micro_Context_JSON': '{"zh":"We frequently browse massive amounts of data on our portable gadgets.","en":"We frequently browse massive amounts of data on our portable gadgets, hoping to stay informed."}',
    'Content_JSON': '{"spelling":"frequently","phonetic":"/ˈfriːkwəntli/","definition":"adv. 频繁地；经常地","etymology":"frequent(频繁的)+-ly(副词)→频繁地","example":"We frequently browse massive amounts of data on our portable gadgets, hoping to stay informed.","translation":"我们频繁地在便携设备上浏览大量数据，希望保持信息灵通。"}',
  };

  await db.insert(kTableNote, evolutionNote);
  await db.insert(kTableNote, efficiencyNote);
  await db.insert(kTableNote, digitalNote);
  await db.insert(kTableNote, frequentlyNote);

  // Topic: 科技阅读
  await db.insert(kTableTopic, {
    'Topic_ID': 'topic_tech_read',
    'Topic_Name': '科技阅读',
    'Topic_Name_EN': 'Tech Reading',
    'Word_Count': 2,
  });

  // Article: 第一篇
  final techArticleContent = {
    'title': 'The Evolution of Communication Technology',
    'segments': [
      {'t': 'The ', 'c': 0, 'u': ''},
      {'t': 'evolution', 'c': 1, 'u': 'note_evolution'},
      {'t': ' of communication technology vividly illustrates humanity\'s relentless pursuit of ', 'c': 0, 'u': ''},
      {'t': 'efficiency', 'c': 1, 'u': 'note_efficiency'},
      {'t': '. Initially, early inventors relied on a rather crude device, the telegraph, to transmit simple text signals across vast distances. Over time, as scientists continued to refine these primitive systems, the ability to broadcast voice and video globally became a ubiquitous reality. In the contemporary digital era, the focus has fundamentally shifted. Modern industries now fabricate intricate microchips that process massive amounts of information, which is subsequently stored in an expansive, interconnected database. This remarkable transition from basic wires to sophisticated data networks has profoundly reshaped human society.', 'c': 0, 'u': ''},
    ],
  };

  await db.insert(kTableArticle, {
    'Article_ID': 'art_tech_read_01',
    'Topic_ID': 'topic_tech_read',
    'Word_Count': 2,
    'Content_JSON': jsonEncode(techArticleContent),
  });

  // Article: 第二篇（占位）
  final techArticle2Content = {
    'title': 'Artificial Intelligence: Past, Present, and Future',
    'segments': [
      {'t': 'Artificial ', 'c': 0, 'u': ''},
      {'t': 'intelligence', 'c': 1, 'u': 'note_intelligence'},
      {'t': ' has transformed every facet of modern life. From the earliest ', 'c': 0, 'u': ''},
      {'t': 'algorithms', 'c': 1, 'u': 'note_algorithm'},
      {'t': ' that played chess to the contemporary large language models capable of natural conversation, the trajectory of AI reflects humanity\'s endless ambition to ', 'c': 0, 'u': ''},
      {'t': 'simulate', 'c': 1, 'u': 'note_simulate'},
      {'t': ' cognition. Yet this rapid advancement raises profound ethical questions about ', 'c': 0, 'u': ''},
      {'t': 'privacy', 'c': 1, 'u': 'note_privacy'},
      {'t': ' and societal impact. Striking a balance between innovation and responsibility remains the defining challenge of our era.', 'c': 0, 'u': ''},
    ],
  };

  await db.insert(kTableArticle, {
    'Article_ID': 'art_tech_read_02',
    'Topic_ID': 'topic_tech_read',
    'Word_Count': 4,
    'Content_JSON': jsonEncode(techArticle2Content),
  });

  // Article: 第三篇（新）
  final techArticle3Content = {
    'title': 'The Information Age',
    'segments': [
      {'t': 'In the ', 'c': 0, 'u': ''},
      {'t': 'digital', 'c': 1, 'u': 'note_digital'},
      {'t': ' age, the proliferation of ', 'c': 0, 'u': ''},
      {'t': 'frequently', 'c': 1, 'u': 'note_frequently'},
      {'t': ' browse massive amounts of data on our portable gadgets, hoping to stay informed. However, true productivity necessitates a focused effort to streamline our workflow, cutting through irrelevant noise. To manage information overload, individuals often look for a cognitive hack to save time, attempting to compress extensive knowledge into brief summaries. While this approach seems efficient, it risks diluting the depth of critical understanding. Mastery requires dedicated engagement rather than mere speed. Therefore, we should create opportunities to ventilate varying perspectives through careful analysis and rigorous discussion. Genuine wisdom is rarely achieved through superficial shortcuts; it demands profound contemplation.', 'c': 0, 'u': ''},
    ],
  };

  await db.insert(kTableArticle, {
    'Article_ID': 'art_tech_read_03',
    'Topic_ID': 'topic_tech_read',
    'Word_Count': 2,
    'Content_JSON': jsonEncode(techArticle3Content),
  });
}

Future<void> _ensureSemanticReadingDataSeeded(Database db) async {
  // 检查 Topic 是否存在
  final topicExists = Sqflite.firstIntValue(
      await db.rawQuery("SELECT 1 FROM ${kTableTopic} WHERE Topic_ID = 'topic_tech_read'"));

  await db.transaction((txn) async {
    // Notes（ignore：不重复）
    final noteEvolution = {
      'Concept_UUID': 'note_evolution',
      'Spelling': 'evolution',
      'Phonetic': '/ˌiːvəˈluːʃn/',
      'Definition': 'n. 进化；演变；发展',
      'Etymology_JSON': '{"roots":[{"root":"e-","meaning":"外、出"},{"root":"vol","meaning":"卷、转"},{"root":"-ution","meaning":"过程"}],"compound":"e(出)+vol(转)+-ution(过程)→转出来→进化","final":"进化"}',
      'Micro_Context_JSON': '{"zh":"The evolution of communication technology illustrates humanity\'s pursuit of efficiency.","en":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency."}',
      'Content_JSON': '{"spelling":"evolution","phonetic":"/ˌiːvəˈluːʃn/","definition":"n. 进化；演变；发展","etymology":"e-(出)+vol(转)+-ution(过程)→转出来→进化","example":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency.","translation":"通信技术的演变生动地说明了人类对效率的不懈追求。"}',
    };
    final noteEfficiency = {
      'Concept_UUID': 'note_efficiency',
      'Spelling': 'efficiency',
      'Phonetic': '/ɪˈfɪʃnsi/',
      'Definition': 'n. 效率；效能',
      'Etymology_JSON': '{"roots":[{"root":"ef-","meaning":"出"},{"root":"fic","meaning":"做"},{"root":"-iency","meaning":"性质/状态"}],"compound":"ef(出)+fic(做)+-iency(性质)→做出来的效果→效率","final":"效率"}',
      'Micro_Context_JSON': '{"zh":"The telegraph was a crude device to transmit signals across vast distances.","en":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency."}',
      'Content_JSON': '{"spelling":"efficiency","phonetic":"/ɪˈfɪʃnsi/","definition":"n. 效率；效能","etymology":"ef-(出)+fic(做)+-iency(性质)→做出来的效果→效率","example":"The evolution of communication technology vividly illustrates humanity\'s relentless pursuit of efficiency.","translation":"通信技术的演变生动地说明了人类对效率的不懈追求。"}',
    };
    final noteDigital = {
      'Concept_UUID': 'note_digital',
      'Spelling': 'digital',
      'Phonetic': '/ˈdɪdʒɪtl/',
      'Definition': 'adj. 数字的；数码的',
      'Etymology_JSON': '{"roots":[{"root":"digit","meaning":"手指/数字"},{"root":"-al","meaning":"...的"}],"compound":"digit(数字)+-al(...的)→数字的","final":"数字的"}',
      'Micro_Context_JSON': '{"zh":"In the digital age, we rely heavily on technology.","en":"In the digital age, the proliferation of digital devices makes modern life increasingly demanding."}',
      'Content_JSON': '{"spelling":"digital","phonetic":"/ˈdɪdʒɪtl/","definition":"adj. 数字的；数码的","etymology":"digit(数字)+-al(...的)→数字的","example":"In the digital age, the proliferation of digital devices makes modern life increasingly demanding.","translation":"在数字时代，数字设备的普及使现代生活日益 demanding。"}',
    };
    final noteFrequently = {
      'Concept_UUID': 'note_frequently',
      'Spelling': 'frequently',
      'Phonetic': '/ˈfriːkwəntli/',
      'Definition': 'adv. 频繁地；经常地',
      'Etymology_JSON': '{"roots":[{"root":"frequent","meaning":"频繁的"},{"root":"-ly","meaning":"副词后缀"}],"compound":"frequent(频繁的)+-ly(副词)→频繁地","final":"频繁地"}',
      'Micro_Context_JSON': '{"zh":"We frequently browse massive amounts of data on our portable gadgets.","en":"We frequently browse massive amounts of data on our portable gadgets, hoping to stay informed."}',
      'Content_JSON': '{"spelling":"frequently","phonetic":"/ˈfriːkwəntli/","definition":"adv. 频繁地；经常地","etymology":"frequent(频繁的)+-ly(副词)→频繁地","example":"We frequently browse massive amounts of data on our portable gadgets, hoping to stay informed.","translation":"我们频繁地在便携设备上浏览大量数据，希望保持信息灵通。"}',
    };
    await txn.insert(kTableNote, noteEvolution, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert(kTableNote, noteEfficiency, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert(kTableNote, noteDigital, conflictAlgorithm: ConflictAlgorithm.ignore);
    await txn.insert(kTableNote, noteFrequently, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Topic（仅在不存在时创建）
    if (topicExists == null) {
      await txn.insert(kTableTopic, {
        'Topic_ID': 'topic_tech_read',
        'Topic_Name': '科技阅读',
        'Topic_Name_EN': 'Tech Reading',
        'Word_Count': 2,
      });
    }

    // Articles（ignore：已存在不覆盖）
    final techArticleContent = {
      'title': 'The Evolution of Communication Technology',
      'segments': [
        {'t': 'The ', 'c': 0, 'u': ''},
        {'t': 'evolution', 'c': 1, 'u': 'note_evolution'},
        {'t': ' of communication technology vividly illustrates humanity\'s relentless pursuit of ', 'c': 0, 'u': ''},
        {'t': 'efficiency', 'c': 1, 'u': 'note_efficiency'},
        {'t': '. Initially, early inventors relied on a rather crude device, the telegraph, to transmit simple text signals across vast distances. Over time, as scientists continued to refine these primitive systems, the ability to broadcast voice and video globally became a ubiquitous reality. In the contemporary digital era, the focus has fundamentally shifted. Modern industries now fabricate intricate microchips that process massive amounts of information, which is subsequently stored in an expansive, interconnected database. This remarkable transition from basic wires to sophisticated data networks has profoundly reshaped human society.', 'c': 0, 'u': ''},
      ],
    };
    await txn.insert(kTableArticle, {
      'Article_ID': 'art_tech_read_01',
      'Topic_ID': 'topic_tech_read',
      'Word_Count': 2,
      'Content_JSON': jsonEncode(techArticleContent),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final techArticle2Content = {
      'title': 'Artificial Intelligence: Past, Present, and Future',
      'segments': [
        {'t': 'Artificial ', 'c': 0, 'u': ''},
        {'t': 'intelligence', 'c': 1, 'u': 'note_intelligence'},
        {'t': ' has transformed every facet of modern life. From the earliest ', 'c': 0, 'u': ''},
        {'t': 'algorithms', 'c': 1, 'u': 'note_algorithm'},
        {'t': ' that played chess to the contemporary large language models capable of natural conversation, the trajectory of AI reflects humanity\'s endless ambition to ', 'c': 0, 'u': ''},
        {'t': 'simulate', 'c': 1, 'u': 'note_simulate'},
        {'t': ' cognition. Yet this rapid advancement raises profound ethical questions about ', 'c': 0, 'u': ''},
        {'t': 'privacy', 'c': 1, 'u': 'note_privacy'},
        {'t': ' and societal impact. Striking a balance between innovation and responsibility remains the defining challenge of our era.', 'c': 0, 'u': ''},
      ],
    };
    await txn.insert(kTableArticle, {
      'Article_ID': 'art_tech_read_02',
      'Topic_ID': 'topic_tech_read',
      'Word_Count': 4,
      'Content_JSON': jsonEncode(techArticle2Content),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    // Article: 第三篇（新）
    final techArticle3Content = {
      'title': 'The Information Age',
      'segments': [
        {'t': 'In the ', 'c': 0, 'u': ''},
        {'t': 'digital', 'c': 1, 'u': 'note_digital'},
        {'t': ' age, the proliferation of ', 'c': 0, 'u': ''},
        {'t': 'frequently', 'c': 1, 'u': 'note_frequently'},
        {'t': ' browse massive amounts of data on our portable gadgets, hoping to stay informed. However, true productivity necessitates a focused effort to streamline our workflow, cutting through irrelevant noise. To manage information overload, individuals often look for a cognitive hack to save time, attempting to compress extensive knowledge into brief summaries. While this approach seems efficient, it risks diluting the depth of critical understanding. Mastery requires dedicated engagement rather than mere speed. Therefore, we should create opportunities to ventilate varying perspectives through careful analysis and rigorous discussion. Genuine wisdom is rarely achieved through superficial shortcuts; it demands profound contemplation.', 'c': 0, 'u': ''},
      ],
    };
    await txn.insert(kTableArticle, {
      'Article_ID': 'art_tech_read_03',
      'Topic_ID': 'topic_tech_read',
      'Word_Count': 2,
      'Content_JSON': jsonEncode(techArticle3Content),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  });
  print('[DB] _ensureSemanticReadingDataSeeded: 完成');
}

// ============================================================================
// Hot 数据库初始化
// ============================================================================

Future<Database> openHotDatabase(String dbDir) async {
  final path = _dbPath(kHotDbName, dbDir);
  print('[DB] openHotDatabase path=$path');
  return openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {
      print('[DB] Hot onCreate 开始');
      await db.execute('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA wal_autocheckpoint=1000');
      await db.execute(kCreateCardSql);
      await db.execute(kCreateReviewLogSql);
      await db.execute(kCreateQuickScreenSql);
      await db.execute(kCreateUserSettingsSql);
      await db.execute(kCreateWordBookSql);
      await _initDefaultSettings(db);
      await _seedWordBooks(db);
      print('[DB] Hot onCreate 完成');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      await db.execute('PRAGMA journal_mode=WAL');
    },
    onOpen: (db) async {
      print('[DB] Hot onOpen 开始');
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Card'));
      print('[DB] Hot onOpen Card数量=$count');
      if (count == null || count == 0) return; // 交由外层补种
      print('[DB] Hot onOpen 完成');
    },
  );
}

Future<void> _initDefaultSettings(Database db) async {
  final defaults = {
    'user_name': '',
    'daily_target': '1000',
    'current_book': 'cet6',
    'book_progress_current': '0',
    'book_progress_total': '5000',
    'single_session_limit': '70',
    'show_etymology': '1',
    'show_definition': '1',
    'show_example': '1',
    'daily_refresh_hour': '0',
    'last_export_time': '${DateTime.now().millisecondsSinceEpoch}',
    'total_study_time_ms': '0',
    'total_study_count': '0',
    'total_study_days': '0',
    'today_study_time_ms': '0',
  };
  final batch = db.batch();
  for (final e in defaults.entries) {
    batch.insert(kTableUserSettings, {'Key': e.key, 'Value': e.value},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await batch.commit(noResult: true);
}

/// 初始化默认词书数据
/// 对应 SRS&SDD v2.1 附录 B：词书系统
Future<void> _seedWordBooks(Database db) async {
  await db.delete('WordBook');

  final books = [
    {
      'Book_ID': 'cet4',
      'Book_Name': 'CET-4',
      'Book_Name_EN': 'College English Test Band 4',
      'Word_Count': 0,
      'Tag_List': 'zk cet4',
      'Description': '大学英语四级词汇',
      'Sort_Order': 1,
      'Is_Default': 1,
    },
    {
      'Book_ID': 'cet6',
      'Book_Name': 'CET-6',
      'Book_Name_EN': 'College English Test Band 6',
      'Word_Count': 0,
      'Tag_List': 'cet6',
      'Description': '大学英语六级词汇',
      'Sort_Order': 2,
      'Is_Default': 1,
    },
    {
      'Book_ID': 'kaoyan',
      'Book_Name': '考研',
      'Book_Name_EN': 'Graduate Entrance Exam',
      'Word_Count': 0,
      'Tag_List': 'ky zk cet4 cet6',
      'Description': '考研英语词汇（含四六级核心词）',
      'Sort_Order': 3,
      'Is_Default': 1,
    },
    {
      'Book_ID': 'toefl',
      'Book_Name': 'TOEFL',
      'Book_Name_EN': 'Test of English as a Foreign Language',
      'Word_Count': 0,
      'Tag_List': 'toefl',
      'Description': '托福学术英语词汇',
      'Sort_Order': 4,
      'Is_Default': 0,
    },
    {
      'Book_ID': 'ielts',
      'Book_Name': 'IELTS',
      'Book_Name_EN': 'International English Language Testing System',
      'Word_Count': 0,
      'Tag_List': 'ielts',
      'Description': '雅思学术英语词汇',
      'Sort_Order': 5,
      'Is_Default': 0,
    },
    {
      'Book_ID': 'gre',
      'Book_Name': 'GRE',
      'Book_Name_EN': 'Graduate Record Examination',
      'Word_Count': 0,
      'Tag_List': 'gre',
      'Description': 'GRE 学术类研究生入学考试词汇',
      'Sort_Order': 6,
      'Is_Default': 0,
    },
    {
      'Book_ID': 'kaoyan2027',
      'Book_Name': '2027考研',
      'Book_Name_EN': '2027 Graduate Entrance Exam',
      'Word_Count': 0,
      'Tag_List': 'ky zk cet4 cet6',
      'Description': '2027届考研英语词汇',
      'Sort_Order': 0,
      'Is_Default': 1,
    },
  ];

  final batch = db.batch();
  for (final book in books) {
    batch.insert('WordBook', book, conflictAlgorithm: ConflictAlgorithm.replace);
  }
  await batch.commit(noResult: true);

  // 验证写入结果
  final count = (await db.query('WordBook')).length;
  print('[DB] _seedWordBooks 完成，已写入 ${books.length} 个词书，验证查询: $count 个');
  if (count != books.length) {
    print('[DB] 警告：词书数量不匹配，预期 ${books.length}，实际 $count');
  }
}

// ============================================================================
// 预编译数据库加载（桌面端 ATTACH / Web 端 JSON）
// ============================================================================

/// 从预编译 assets/ecdict/ecdict.db 倒入数据到 romDb
/// 桌面端（非 Web）：复制到 tempDir → ATTACH → INSERT
/// Web 端：读取分卷 JSON → batch insert
Future<void> _loadFromPrebuiltDb(Database romDb, Database hotDb) async {
  print('[DB] _loadFromPrebuiltDb 开始');

  // 步骤 0：读取词书统计，更新 WordBook 词数
  final countsAsset = 'assets/ecdict/ecdict_book_counts.json';
  if (await _assetExists(countsAsset)) {
    try {
      final raw = jsonDecode(await rootBundle.loadString(countsAsset)) as Map<String, dynamic>;
      final bookCounts = <String, int>{};
      for (final e in raw.entries) {
        bookCounts[e.key] = e.value as int;
      }
      if (bookCounts.isNotEmpty) {
        await _updateWordBookCountsFromMap(hotDb, bookCounts);
      }
    } catch (e) {
      print('[DB] _loadFromPrebuiltDb: 词书统计读取失败: $e');
    }
  }

  // 步骤 1：加载 Note + Tree 数据
  if (kIsWeb) {
    await _loadPrebuiltNotesToWeb(romDb);
  } else {
    await _attachPrebuiltDb(romDb);
  }

  print('[DB] _loadFromPrebuiltDb 完成');
}

/// 桌面端：从 assets 复制预编译 .db 到 tempDir，ATTACH，倒入
Future<void> _attachPrebuiltDb(Database romDb) async {
  const dbAsset = 'assets/ecdict/ecdict.db';
  if (!await _assetExists(dbAsset)) {
    print('[DB] _attachPrebuiltDb: ecdict.db 不存在');
    return;
  }

  final ByteData data = await rootBundle.load(dbAsset);
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  print('[DB] _attachPrebuiltDb: 读取 ecdict.db ${bytes.length} bytes');

  final tempDir = await getTemporaryDirectory();
  final tempPath =
      '${tempDir.path}/ecdict_prebuilt_${DateTime.now().millisecondsSinceEpoch}.db';
  final tempFile = File(tempPath);
  await tempFile.writeAsBytes(bytes);

  try {
    await romDb.execute("ATTACH DATABASE '\$tempPath' AS prebuilt");
    try {
      final noteCount = Sqflite.firstIntValue(
          await romDb.rawQuery('SELECT COUNT(*) FROM prebuilt.Note')) ?? 0;
      print('[DB] _attachPrebuiltDb: 预编译 DB 有 $noteCount 条 Note');

      if (noteCount > 0) {
        await romDb.execute('INSERT OR REPLACE INTO Note SELECT * FROM prebuilt.Note');
        await romDb.execute('INSERT OR IGNORE INTO Resemble SELECT * FROM prebuilt.Resemble');
        await romDb.execute('INSERT OR REPLACE INTO Tree_Root SELECT * FROM prebuilt.Tree_Root');
        await romDb.execute('INSERT OR IGNORE INTO Tree_Word SELECT * FROM prebuilt.Tree_Word');
      }
    } finally {
      await romDb.execute('DETACH DATABASE prebuilt');
    }
  } finally {
    try {
      await tempFile.delete();
    } catch (_) {}
  }
}

/// Web 端：读取 ecdict_notes_manifest.json，逐卷加载 JSON，批量 insert
Future<void> _loadPrebuiltNotesToWeb(Database romDb) async {
  const manifestAsset = 'assets/ecdict/ecdict_notes_manifest.json';
  if (!await _assetExists(manifestAsset)) {
    print('[DB] _loadPrebuiltNotesToWeb: manifest 不存在，跳过');
    return;
  }

  try {
    final manifestStr = await rootBundle.loadString(manifestAsset);
    final manifest = jsonDecode(manifestStr) as Map<String, dynamic>;
    final chunks = (manifest['chunks'] as List<dynamic>).cast<String>();

    for (final chunkFile in chunks) {
      final chunkAsset = 'assets/ecdict/$chunkFile';
      if (!await _assetExists(chunkAsset)) continue;
      final chunkStr = await rootBundle.loadString(chunkAsset);
      final notes = jsonDecode(chunkStr) as List<dynamic>;

      final batch = romDb.batch();
      for (final note in notes) {
        batch.insert(kTableNote, Map<String, dynamic>.from(note),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }

    // Web: Resemble + Tree JSON
    await _loadPrebuiltResembleAndTreeToWeb(romDb);
  } catch (e) {
    print('[DB] _loadPrebuiltNotesToWeb 异常: $e');
  }
}

/// Web: Resemble + Tree 数据
Future<void> _loadPrebuiltResembleAndTreeToWeb(Database romDb) async {
  // Resemble
  try {
    const asset = 'assets/ecdict/ecdict_resemble.json';
    if (await _assetExists(asset)) {
      final str = await rootBundle.loadString(asset);
      final rows = jsonDecode(str) as List<dynamic>;
      final batch = romDb.batch();
      for (final r in rows) {
        batch.insert('Resemble', Map<String, dynamic>.from(r),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  } catch (e) {
    print('[DB] Web Resemble 加载失败: $e');
  }

  // Tree_Root
  try {
    const asset = 'assets/ecdict/ecdict_tree_root.json';
    if (await _assetExists(asset)) {
      final str = await rootBundle.loadString(asset);
      final rows = jsonDecode(str) as List<dynamic>;
      final batch = romDb.batch();
      for (final r in rows) {
        batch.insert(kTableTreeRoot, Map<String, dynamic>.from(r),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    }
  } catch (e) {
    print('[DB] Web Tree_Root 加载失败: $e');
  }

  // Tree_Word 分卷
  try {
    const manifestAsset = 'assets/ecdict/ecdict_tree_word_manifest.json';
    if (!await _assetExists(manifestAsset)) return;
    final mStr = await rootBundle.loadString(manifestAsset);
    final manifest = jsonDecode(mStr) as Map<String, dynamic>;
    final chunks = (manifest['chunks'] as List<dynamic>).cast<String>();
    for (final chunkFile in chunks) {
      final chunkAsset = 'assets/ecdict/$chunkFile';
      if (!await _assetExists(chunkAsset)) continue;
      final cStr = await rootBundle.loadString(chunkAsset);
      final rows = jsonDecode(cStr) as List<dynamic>;
      final batch = romDb.batch();
      for (final r in rows) {
        batch.insert(kTableTreeWord, Map<String, dynamic>.from(r),
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    }
  } catch (e) {
    print('[DB] Web Tree_Word 加载失败: $e');
  }
}

/// 根据词书统计 Map 批量更新 WordBook 表的 Word_Count
Future<void> _updateWordBookCountsFromMap(Database db, Map<String, int> bookCounts) async {
  int updated = 0;
  for (final entry in bookCounts.entries) {
    final count = await db.rawUpdate(
      'UPDATE WordBook SET Word_Count = ? WHERE Book_ID = ?',
      [entry.value, entry.key],
    );
    if (count > 0) updated++;
  }
  print('[DB] _updateWordBookCountsFromMap: 更新了 $updated 个词书的词数');
}

// ============================================================================
// 种子数据与热库初始化
// ============================================================================

/// 写入热库种子数据：新用户首次打开时，为 ROM 中的每个 Note 创建一张对应的 Card
Future<void> seedHotDataIfNeeded(Database hotDb, Database romDb) async {
  print('[DB] seedHotDataIfNeeded 开始');
  final count = Sqflite.firstIntValue(await hotDb.rawQuery('SELECT COUNT(*) FROM Card'));
  print('[DB] seedHotDataIfNeeded 当前Card数量=$count');

  // 确保词书数据已种入
  await _seedWordBooks(hotDb);

  // 如果 Card 表为空或树表为空，从预编译 DB 加载
  if (count == null || count == 0) {
    print('[DB] seedHotDataIfNeeded Card为空，从预编译 DB 加载...');
    await romDb.delete(kTableTreeWord);
    await romDb.delete(kTableTreeRoot);
    await _loadFromPrebuiltDb(romDb, hotDb);
  } else {
    // Card 非空但树表可能为空
    final treeRootCount = Sqflite.firstIntValue(
        await romDb.rawQuery('SELECT COUNT(*) FROM Tree_Root')) ?? 0;
    if (treeRootCount == 0) {
      print('[DB] seedHotDataIfNeeded 树表为空，从预编译 DB 加载...');
      await _loadFromPrebuiltDb(romDb, hotDb);
    }
  }

  // 再次检查 Card 数量
  final cardCountAfter = Sqflite.firstIntValue(await hotDb.rawQuery('SELECT COUNT(*) FROM Card'));
  if (cardCountAfter != null && cardCountAfter > 0) {
    // 即使 Card 表已有数据，仍需检查并清理旧词组卡片（如 "incremental duplex"）
    // Web：Card 和 Note 在不同 IndexedDB，改用 in-memory 过滤
    // 非 Web：直接 JOIN 查询
    try {
      if (kIsWeb) {
        // Web：遍历所有 Card，清理孤立 Card（ROM 无对应 Note）+ 词组/脏数据 Card
        final allCards = await hotDb.query(kTableCard, columns: ['Card_ID', 'Concept_UUID']);
        int orphanDeleted = 0, dirtyDeleted = 0;
        for (final card in allCards) {
          final uuid = card['Concept_UUID'] as String?;
          if (uuid == null) continue;
          final notes = await romDb.query(
            kTableNote,
            columns: ['Spelling'],
            where: 'Concept_UUID = ?',
            whereArgs: [uuid],
            limit: 1,
          );
          if (notes.isEmpty) {
            // ROM 中无对应 Note → 孤立 Card，直接删除
            await hotDb.delete(kTableCard, where: 'Card_ID = ?', whereArgs: [card['Card_ID']]);
            orphanDeleted++;
          } else {
            final spelling = (notes.first['Spelling'] as String? ?? '').trim();
            // 过滤词组（包含空格）、不含字母、首/第二字符非法、以 - 或 ' 开头
            if (spelling.isEmpty || spelling.contains(' ') ||
                !spelling.contains(RegExp(r'[a-zA-Z]')) ||
                !_isAlpha(spelling.codeUnitAt(0)) ||
                (spelling.length >= 2 && !_isAlpha(spelling.codeUnitAt(1))) ||
                spelling.startsWith('-') || spelling.startsWith("'")) {
              await hotDb.delete(kTableCard, where: 'Card_ID = ?', whereArgs: [card['Card_ID']]);
              dirtyDeleted++;
            }
          }
        }
        print('[DB] seedHotDataIfNeeded 清理完成（Web 模式）：孤立 Card=$orphanDeleted，脏数据 Card=$dirtyDeleted');
      } else {
        // 非 Web：直接 JOIN 查询，清理词组/词根词缀/首第二字符非法卡片
        final phraseCards = await hotDb.rawQuery('''
          SELECT Card.Card_ID FROM Card
          JOIN Note ON Card.Concept_UUID = Note.Concept_UUID
          WHERE (Note.Spelling = '' OR Note.Spelling LIKE '% %'
             OR NOT Note.Spelling GLOB '*[a-zA-Z]*'
             OR unicode(substr(Note.Spelling,1,1)) NOT BETWEEN 65 AND 90
                AND unicode(substr(Note.Spelling,1,1)) NOT BETWEEN 97 AND 122
             OR (LENGTH(Note.Spelling) >= 2
                AND unicode(substr(Note.Spelling,2,1)) NOT BETWEEN 65 AND 90
                AND unicode(substr(Note.Spelling,2,1)) NOT BETWEEN 97 AND 122)
             OR Note.Spelling LIKE '-%'
             OR Note.Spelling LIKE "'%")
        ''');
        for (final row in phraseCards) {
          await hotDb.delete(kTableCard, where: 'Card_ID = ?', whereArgs: [row['Card_ID']]);
        }
        print('[DB] seedHotDataIfNeeded 清理了 ${phraseCards.length} 张词组/词根词缀卡片（非 Web 模式）');
      }
    } catch (e) {
      print('[DB] seedHotDataIfNeeded 清理词组卡片异常: $e');
    }
    print('[DB] seedHotDataIfNeeded 已有数据，跳过 Card 写入');
    return;
  }

  print('[DB] seedHotDataIfNeeded 开始查询ROM数据...');
  final notes = await romDb.query(kTableNote);
  print('[DB] seedHotDataIfNeeded ROM Note数量=${notes.length}');
  if (notes.isEmpty) {
    print('[DB] seedHotDataIfNeeded ROM Note为空，跳过');
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final batch = hotDb.batch();
  int insertedCount = 0;
  for (int i = 0; i < notes.length; i++) {
    final note = notes[i];
    final spelling = (note['Spelling'] as String? ?? '').trim();
    // 过滤无效单词：空单词、含空格、不含任何字母、首/第二字符非法、以 - 或 ' 开头
    if (spelling.isEmpty || spelling.contains(' ') ||
        !spelling.contains(RegExp(r'[a-zA-Z]')) ||
        !_isAlpha(spelling.codeUnitAt(0)) ||
        (spelling.length >= 2 && !_isAlpha(spelling.codeUnitAt(1))) ||
        spelling.startsWith('-') || spelling.startsWith("'")) continue;
    batch.insert(
      kTableCard,
      {
        'Concept_UUID': note['Concept_UUID'] as String,
        'Status': CardStatus.newCard,
        'Next_Review_Date': now,
        'R': 0.9,
        'S': 1.0,
        'Fail_Count': 0,
        'Favorite': 0,
        'Topic_Read': 0,
        'Tree_Visit': 0,
        'Random_Sort_ID': insertedCount,
        'Tag_List': note['Tag_List'] as String?,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    insertedCount++;
  }
  // 打乱插入顺序以实现随机排序
  await hotDb.execute(
    'UPDATE $kTableCard SET Random_Sort_ID = (ABS(RANDOM()) % $insertedCount) WHERE Random_Sort_ID >= 0',
  );
  print('[DB] seedHotDataIfNeeded 开始批量写入Card...');
  await batch.commit(noResult: true);
  print('[DB] seedHotDataIfNeeded 完成，插入 $insertedCount 张 Card（已过滤词组）');
}

// ============================================================================
// 数据库完整性探针（对应文档 3.1 节）
// ============================================================================

Future<bool> probeRomIntegrity(Database db) async {
  try {
    final result = await db.rawQuery('PRAGMA integrity_check');
    return result.isNotEmpty && result.first.values.first == 'ok';
  } catch (_) {
    return false;
  }
}

Future<bool> probeHotIntegrity(Database db) async {
  try {
    final result = await db.rawQuery('PRAGMA integrity_check');
    return result.isNotEmpty && result.first.values.first == 'ok';
  } catch (_) {
    return false;
  }
}

// ============================================================================
// ROM 数据查询（Note 相关）
// ============================================================================

class NoteModel {
  final String conceptUuid;
  final String spelling;
  final String phonetic;
  final String definition;
  final String? etymologyJson;
  final String microContextJson;
  final String contentJson;
  final int bnc;
  final int frq;
  final int collinsStar;
  final String? definitionEn;
  final String? exampleSentence;

  // 时态/变形（完整解析 exchange 列）
  final String? pastTense;
  final String? pastParticiple;
  final String? presentParticiple;
  final String? thirdPerson;
  final String? comparative;
  final String? superlative;
  final String? plural;
  final String? lemma;
  final String? lemmaVariant;

  final String? partOfSpeech;

  // 词书标签（JSON 数组字符串）
  final String? tagList;

  // 近义词辨析（来自 resemble.txt）
  final String? synonymJson;

  // Oxford 标识
  final int isOxford;
  final int oxford3000;
  final int oxford5000;

  NoteModel({
    required this.conceptUuid,
    required this.spelling,
    required this.phonetic,
    required this.definition,
    this.etymologyJson,
    required this.microContextJson,
    required this.contentJson,
    this.bnc = 0,
    this.frq = 0,
    this.collinsStar = 0,
    this.definitionEn,
    this.exampleSentence,
    this.pastTense,
    this.pastParticiple,
    this.presentParticiple,
    this.thirdPerson,
    this.comparative,
    this.superlative,
    this.plural,
    this.lemma,
    this.lemmaVariant,
    this.partOfSpeech,
    this.tagList,
    this.synonymJson,
    this.isOxford = 0,
    this.oxford3000 = 0,
    this.oxford5000 = 0,
  });

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    return NoteModel(
      conceptUuid: map['Concept_UUID'] as String,
      spelling: map['Spelling'] as String,
      phonetic: map['Phonetic'] as String,
      definition: map['Definition'] as String,
      etymologyJson: map['Etymology_JSON'] as String?,
      microContextJson: map['Micro_Context_JSON'] as String,
      contentJson: map['Content_JSON'] as String,
      bnc: map['BNC'] as int? ?? 0,
      frq: map['FRQ'] as int? ?? 0,
      collinsStar: map['Collins_Star'] as int? ?? 0,
      definitionEn: map['Definition_En'] as String?,
      exampleSentence: map['Example_Sentence'] as String?,
      pastTense: map['Past_Tense'] as String?,
      pastParticiple: map['Past_Participle'] as String?,
      presentParticiple: map['Present_Participle'] as String?,
      thirdPerson: map['Third_Person'] as String?,
      comparative: map['Comparative'] as String?,
      superlative: map['Superlative'] as String?,
      plural: map['Plural'] as String?,
      lemma: map['Lemma'] as String?,
      lemmaVariant: map['Lemma_Variant'] as String?,
      partOfSpeech: map['Part_Of_Speech'] as String?,
      tagList: map['Tag_List'] as String?,
      synonymJson: map['Synonym_JSON'] as String?,
      isOxford: map['Is_Oxford'] as int? ?? 0,
      oxford3000: map['Oxford_3000'] as int? ?? 0,
      oxford5000: map['Oxford_5000'] as int? ?? 0,
    );
  }
}

/// 批量查询 Note（Map<UUID, NoteModel>），每批 2000 条
Future<Map<String, NoteModel>> queryNotesBatch(Database db, List<String> uuids) async {
  if (uuids.isEmpty) return {};
  final result = <String, NoteModel>{};
  const batchSize = 2000;
  for (int i = 0; i < uuids.length; i += batchSize) {
    final batch = uuids.skip(i).take(batchSize).toList();
    final placeholders = List.filled(batch.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT * FROM Note WHERE Concept_UUID IN ($placeholders)',
      batch,
    );
    for (final row in rows) {
      final note = NoteModel.fromMap(row);
      result[note.conceptUuid] = note;
    }
  }
  return result;
}

Future<NoteModel?> queryNoteByUuid(Database db, String uuid) async {
  final results = await db.query(
    kTableNote,
    where: 'Concept_UUID = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  if (results.isEmpty) return null;
  return NoteModel.fromMap(results.first);
}

Future<List<NoteModel>> queryAllNotes(Database db, {int? limit, int? offset}) async {
  final results = await db.query(kTableNote, limit: limit, offset: offset);
  return results.map((e) => NoteModel.fromMap(e)).toList();
}

// ============================================================================
// Hot 数据查询（WordBook 相关）
// ============================================================================

/// 词书数据模型（SRS&SDD v2.1 附录 B）
class WordBookModel {
  final String bookId;
  final String bookName;
  final String bookNameEn;
  final int wordCount;
  final String tagList;
  final String description;
  final int sortOrder;
  final bool isDefault;

  WordBookModel({
    required this.bookId,
    required this.bookName,
    required this.bookNameEn,
    required this.wordCount,
    required this.tagList,
    required this.description,
    required this.sortOrder,
    required this.isDefault,
  });

  factory WordBookModel.fromMap(Map<String, dynamic> map) {
    return WordBookModel(
      bookId: map['Book_ID'] as String,
      bookName: map['Book_Name'] as String,
      bookNameEn: map['Book_Name_EN'] as String,
      wordCount: map['Word_Count'] as int,
      tagList: map['Tag_List'] as String,
      description: map['Description'] as String,
      sortOrder: map['Sort_Order'] as int,
      isDefault: (map['Is_Default'] as int) == 1,
    );
  }
}

/// 查询所有词书（按 Sort_Order 排序）
Future<List<WordBookModel>> queryAllWordBooks(Database db) async {
  final results = await db.query(
    'WordBook',
    orderBy: 'Sort_Order ASC',
  );
  return results.map((e) => WordBookModel.fromMap(e)).toList();
}

/// 查询 Note 表统计信息（用于词库诊断）
Future<Map<String, int>> queryNoteStats(Database romDb) async {
  final total = Sqflite.firstIntValue(
      await romDb.rawQuery('SELECT COUNT(*) FROM Note')) ?? 0;
  final collinsPos = Sqflite.firstIntValue(
      await romDb.rawQuery('SELECT COUNT(*) FROM Note WHERE Collins_Star > 0')) ?? 0;
  final bncPos = Sqflite.firstIntValue(
      await romDb.rawQuery('SELECT COUNT(*) FROM Note WHERE BNC > 0')) ?? 0;
  final frqPos = Sqflite.firstIntValue(
      await romDb.rawQuery('SELECT COUNT(*) FROM Note WHERE FRQ > 0')) ?? 0;
  final oxfordPos = Sqflite.firstIntValue(
      await romDb.rawQuery('SELECT COUNT(*) FROM Note WHERE Is_Oxford > 0 OR Oxford_3000 > 0 OR Oxford_5000 > 0')) ?? 0;
  final resembleCount = Sqflite.firstIntValue(
      await romDb.rawQuery('SELECT COUNT(*) FROM Resemble')) ?? 0;
  final synonymFilled = Sqflite.firstIntValue(
      await romDb.rawQuery("SELECT COUNT(*) FROM Note WHERE Synonym_JSON IS NOT NULL AND Synonym_JSON != ''")) ?? 0;
  return {
    'total': total,
    'collinsPos': collinsPos,
    'bncPos': bncPos,
    'frqPos': frqPos,
    'oxfordPos': oxfordPos,
    'resembleCount': resembleCount,
    'synonymFilled': synonymFilled,
  };
}

/// 根据 Book_ID 查询词书
Future<WordBookModel?> queryWordBookById(Database db, String bookId) async {
  final results = await db.query(
    'WordBook',
    where: 'Book_ID = ?',
    whereArgs: [bookId],
    limit: 1,
  );
  if (results.isEmpty) return null;
  return WordBookModel.fromMap(results.first);
}

// ============================================================================
// ROM 数据查询（Tree 相关）
// ============================================================================

class TreeRootModel {
  final String rootId;
  final String rootName;
  final String rootDefinition;
  final String rootGroup;
  final String origin;
  final String rootFunction;   // 构词说明（新增，约611条词根有值）
  final String rootSynonyms;   // 同义词根（新增）
  final String rootAntonyms;   // 反义词根（新增）

  TreeRootModel({
    required this.rootId,
    required this.rootName,
    required this.rootDefinition,
    required this.rootGroup,
    required this.origin,
    this.rootFunction  = '',
    this.rootSynonyms  = '',
    this.rootAntonyms  = '',
  });

  factory TreeRootModel.fromMap(Map<String, dynamic> map) {
    return TreeRootModel(
      rootId:         map['Root_ID'] as String,
      rootName:       map['Root_Name'] as String,
      rootDefinition: map['Root_Definition'] as String,
      rootGroup:      map['Root_Group'] as String,
      origin:        (map['Root_Origin'] as String?) ?? '',
      rootFunction:  (map['Root_Function'] as String?) ?? '',
      rootSynonyms:  (map['Root_Synonyms'] as String?) ?? '',
      rootAntonyms:  (map['Root_Antonyms'] as String?) ?? '',
    );
  }
}

Future<TreeRootModel?> queryTreeRootById(Database db, String rootId) async {
  final results = await db.query(
    kTableTreeRoot,
    where: 'Root_ID = ?',
    whereArgs: [rootId],
    limit: 1,
  );
  if (results.isEmpty) return null;
  return TreeRootModel.fromMap(results.first);
}

Future<List<TreeRootModel>> queryTreeRootsByGroup(Database db, String group) async {
  final results = await db.query(
    kTableTreeRoot,
    where: 'Root_Group = ?',
    whereArgs: [group],
    orderBy: 'Root_Name ASC',
  );
  return results.map((e) => TreeRootModel.fromMap(e)).toList();
}

Future<List<TreeRootModel>> queryAllTreeRoots(Database db) async {
  final results = await db.query(kTableTreeRoot, orderBy: 'Root_Group ASC, Root_Name ASC');
  return results.map((e) => TreeRootModel.fromMap(e)).toList();
}

class TreeWordModel {
  final int? treeWordId;
  final String rootId;
  final String conceptUuid;
  final String compoundForm; // 单词本身，如 absorb
  final int sortOrder;

  TreeWordModel({
    this.treeWordId,
    required this.rootId,
    required this.conceptUuid,
    required this.compoundForm,
    this.sortOrder = 0,
  });

  factory TreeWordModel.fromMap(Map<String, dynamic> map) {
    return TreeWordModel(
      treeWordId: map['Tree_Word_ID'] as int?,
      rootId: map['Root_ID'] as String,
      conceptUuid: map['Concept_UUID'] as String,
      compoundForm: map['Compound_Form'] as String,
      sortOrder: map['Sort_Order'] as int? ?? 0,
    );
  }
}

Future<List<TreeWordModel>> queryTreeWordsByRoot(Database db, String rootId) async {
  final results = await db.query(
    kTableTreeWord,
    where: 'Root_ID = ?',
    whereArgs: [rootId],
    orderBy: 'Sort_Order ASC',
  );
  return results.map((e) => TreeWordModel.fromMap(e)).toList();
}

// ============================================================================
// ROM 数据查询（Topic & Article 相关）
// ============================================================================

class TopicModel {
  final String topicId;
  final String topicName;
  final String topicNameEn;
  final int wordCount;

  TopicModel({
    required this.topicId,
    required this.topicName,
    required this.topicNameEn,
    required this.wordCount,
  });

  factory TopicModel.fromMap(Map<String, dynamic> map) {
    return TopicModel(
      topicId: map['Topic_ID'] as String,
      topicName: map['Topic_Name'] as String,
      topicNameEn: map['Topic_Name_EN'] as String,
      wordCount: map['Word_Count'] as int,
    );
  }
}

Future<List<TopicModel>> queryAllTopics(Database db) async {
  final results = await db.query(kTableTopic);
  return results.map((e) => TopicModel.fromMap(e)).toList();
}

class ArticleModel {
  final String articleId;
  final String topicId;
  final String contentJson;
  final int wordCount;

  ArticleModel({
    required this.articleId,
    required this.topicId,
    required this.contentJson,
    required this.wordCount,
  });

  factory ArticleModel.fromMap(Map<String, dynamic> map) {
    return ArticleModel(
      articleId: map['Article_ID'] as String,
      topicId: map['Topic_ID'] as String,
      contentJson: map['Content_JSON'] as String,
      wordCount: map['Word_Count'] as int,
    );
  }
}

Future<List<ArticleModel>> queryArticlesByTopic(Database db, String topicId) async {
  final results = await db.query(
    kTableArticle,
    where: 'Topic_ID = ?',
    whereArgs: [topicId],
  );
  return results.map((e) => ArticleModel.fromMap(e)).toList();
}

// ============================================================================
// Hot 数据查询/写入（Card 相关）
// ============================================================================

/// Card 状态机
class CardStatus {
  static const int newCard = 0;
  static const int learning = 1;
  static const int review = 2;
  static const int relearning = 3;
}

class CardModel {
  int? cardId;
  final String conceptUuid;
  int status;
  int nextReviewDate; // UTC 毫秒时间戳
  int lastReviewDate; // UTC 毫秒时间戳，上次复习的真实时间
  int? lastReviewLogId; // 最近一次 Review_Log 的 Log_ID，用于内存撤销时精准删除
  double r; // Retrievability
  double s; // Stability
  int failCount;
  int favorite;
  int topicRead;
  int treeVisit;
  int randomSortId;

  CardModel({
    this.cardId,
    required this.conceptUuid,
    required this.status,
    required this.nextReviewDate,
    required this.lastReviewDate,
    this.lastReviewLogId,
    required this.r,
    required this.s,
    this.failCount = 0,
    this.favorite = 0,
    this.topicRead = 0,
    this.treeVisit = 0,
    required this.randomSortId,
  });

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      cardId: map['Card_ID'] as int?,
      conceptUuid: map['Concept_UUID'] as String,
      status: map['Status'] as int,
      nextReviewDate: map['Next_Review_Date'] as int,
      lastReviewDate: map['Last_Review_Date'] as int? ?? 0,
      lastReviewLogId: map['Last_Review_Log_ID'] as int?,
      r: (map['R'] as num).toDouble(),
      s: (map['S'] as num).toDouble(),
      failCount: map['Fail_Count'] as int? ?? 0,
      favorite: map['Favorite'] as int? ?? 0,
      topicRead: map['Topic_Read'] as int? ?? 0,
      treeVisit: map['Tree_Visit'] as int? ?? 0,
      randomSortId: map['Random_Sort_ID'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (cardId != null) 'Card_ID': cardId,
      'Concept_UUID': conceptUuid,
      'Status': status,
      'Next_Review_Date': nextReviewDate,
      'Last_Review_Date': lastReviewDate,
      if (lastReviewLogId != null) 'Last_Review_Log_ID': lastReviewLogId,
      'R': r,
      'S': s,
      'Fail_Count': failCount,
      'Favorite': favorite,
      'Topic_Read': topicRead,
      'Tree_Visit': treeVisit,
      'Random_Sort_ID': randomSortId,
    };
  }
}

Future<CardModel?> queryCardByUuid(Database db, String uuid) async {
  final results = await db.query(
    kTableCard,
    where: 'Concept_UUID = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  if (results.isEmpty) return null;
  return CardModel.fromMap(results.first);
}

/// 查询所有待复习的卡片（Next_Review_Date <= now）
Future<List<CardModel>> queryDueCards(Database db, int now) async {
  final results = await db.query(
    kTableCard,
    where: 'Next_Review_Date <= ? AND Status IN (?, ?, ?)',
    whereArgs: [now, CardStatus.learning, CardStatus.review, CardStatus.relearning],
    orderBy: 'Next_Review_Date ASC',
  );
  return results.map((e) => CardModel.fromMap(e)).toList();
}

/// 查询所有新卡片（Status=0），按 Random_Sort_ID 乱序
Future<List<CardModel>> queryNewCards(Database db, {int? limit}) async {
  final results = await db.query(
    kTableCard,
    where: 'Status = ?',
    whereArgs: [CardStatus.newCard],
    orderBy: 'Random_Sort_ID ASC',
    limit: limit,
  );
  return results.map((e) => CardModel.fromMap(e)).toList();
}

/// 查询所有卡片（用于快速筛选回退：当没有新卡时显示所有卡）
Future<List<CardModel>> queryAllCards(Database db, {int? limit}) async {
  final results = await db.query(
    kTableCard,
    orderBy: 'Random_Sort_ID ASC',
    limit: limit,
  );
  return results.map((e) => CardModel.fromMap(e)).toList();
}

/// 查询收藏卡片
Future<List<CardModel>> queryFavoriteCards(Database db) async {
  final results = await db.query(
    kTableCard,
    where: 'Favorite = ?',
    whereArgs: [1],
    orderBy: 'Card_ID DESC',
  );
  return results.map((e) => CardModel.fromMap(e)).toList();
}

Future<void> upsertCard(Database db, CardModel card) async {
  await db.insert(
    kTableCard,
    card.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// 按词书过滤查询新卡
/// Web（单库）：JOIN 跨表查询；非 Web：直接按 Card.Tag_List 过滤（已迁移回填）
Future<List<CardModel>> queryNewCardsByBook(Database hotDb, String bookId, {int? limit}) async {
  // 从 WordBook 表查 Tag_List
  final book = await queryWordBookById(hotDb, bookId);
  if (book == null) {
    print('[DB] queryNewCardsByBook: 未找到词书 $bookId，回退到 queryNewCards');
    return queryNewCards(hotDb, limit: limit);
  }

  final tags = book.tagList.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tags.isEmpty) {
    print('[DB] queryNewCardsByBook: 词书 $bookId 无 Tag_List，回退到 queryNewCards');
    return queryNewCards(hotDb, limit: limit);
  }

  print('[DB] queryNewCardsByBook: 词书=$bookId, tags=$tags');
  final effectiveLimit = limit ?? 999999;

  List<Map<String, dynamic>> results;

  if (kIsWeb) {
    // Web: Card.Tag_List 已在 seedHotDataIfNeeded 时从 Note 回填，直接过滤，无需跨库 JOIN
    final likeConditions = tags.map((t) => "Tag_List LIKE '%\"$t\"%'").join(' OR ');
    results = await hotDb.rawQuery('''
      SELECT * FROM Card
      WHERE Status = ?
      AND ($likeConditions)
      ORDER BY Random_Sort_ID ASC
      LIMIT ?
    ''', [CardStatus.newCard, effectiveLimit]);
  } else {
    // 非 Web：Card.Tag_List 已通过迁移回填，直接过滤
    final likeConditions = tags.map((t) => "Tag_List LIKE '%\"$t\"%'").join(' OR ');
    results = await hotDb.rawQuery('''
      SELECT * FROM Card
      WHERE Status = ?
      AND ($likeConditions)
      ORDER BY Random_Sort_ID ASC
      LIMIT ?
    ''', [CardStatus.newCard, effectiveLimit]);
  }

  print('[DB] queryNewCardsByBook: 查询到 ${results.length} 张新卡');
  return results.map((e) => CardModel.fromMap(e)).toList();
}

Future<void> updateCardFavorite(Database db, String uuid, int favorite) async {
  await db.update(
    kTableCard,
    {'Favorite': favorite},
    where: 'Concept_UUID = ?',
    whereArgs: [uuid],
  );
}

Future<void> updateCardTreeVisit(Database db, String uuid) async {
  await db.update(
    kTableCard,
    {'Tree_Visit': 1},
    where: 'Concept_UUID = ?',
    whereArgs: [uuid],
  );
}

Future<void> updateCardTopicRead(Database db, String uuid) async {
  await db.update(
    kTableCard,
    {'Topic_Read': 1},
    where: 'Concept_UUID = ?',
    whereArgs: [uuid],
  );
}

// ============================================================================
// Hot 数据查询/写入（Review_Log 相关）
// ============================================================================

class ReviewLogModel {
  int? logId;
  final String conceptUuid;
  final int rating;
  final int logDate;
  final String localDateStr;
  final int preStatus;
  final double preR;
  final double preS;

  ReviewLogModel({
    this.logId,
    required this.conceptUuid,
    required this.rating,
    required this.logDate,
    required this.localDateStr,
    required this.preStatus,
    required this.preR,
    required this.preS,
  });

  Map<String, dynamic> toMap() {
    return {
      if (logId != null) 'Log_ID': logId,
      'Concept_UUID': conceptUuid,
      'Rating': rating,
      'Log_Date': logDate,
      'Local_Date_Str': localDateStr,
      'Pre_Status': preStatus,
      'Pre_R': preR,
      'Pre_S': preS,
    };
  }
}

Future<int> insertReviewLog(Database db, ReviewLogModel log) async {
  return await db.insert(kTableReviewLog, log.toMap());
}

Future<ReviewLogModel?> queryLastReviewLog(Database db) async {
  final results = await db.query(
    kTableReviewLog,
    orderBy: 'Log_ID DESC',
    limit: 1,
  );
  if (results.isEmpty) return null;
  final map = Map<String, dynamic>.from(results.first);
  return ReviewLogModel(
    logId: map['Log_ID'] as int?,
    conceptUuid: map['Concept_UUID'] as String,
    rating: map['Rating'] as int,
    logDate: map['Log_Date'] as int,
    localDateStr: map['Local_Date_Str'] as String,
    preStatus: map['Pre_Status'] as int,
    preR: (map['Pre_R'] as num).toDouble(),
    preS: (map['Pre_S'] as num).toDouble(),
  );
}

/// 查询指定 Concept_UUID 的最近一条 Review_Log
Future<ReviewLogModel?> queryLastReviewLogByUuid(Database db, String conceptUuid) async {
  final results = await db.query(
    kTableReviewLog,
    where: 'Concept_UUID = ?',
    whereArgs: [conceptUuid],
    orderBy: 'Log_ID DESC',
    limit: 1,
  );
  if (results.isEmpty) return null;
  final map = Map<String, dynamic>.from(results.first);
  return ReviewLogModel(
    logId: map['Log_ID'] as int?,
    conceptUuid: map['Concept_UUID'] as String,
    rating: map['Rating'] as int,
    logDate: map['Log_Date'] as int,
    localDateStr: map['Local_Date_Str'] as String,
    preStatus: map['Pre_Status'] as int,
    preR: (map['Pre_R'] as num).toDouble(),
    preS: (map['Pre_S'] as num).toDouble(),
  );
}

Future<void> deleteLastReviewLog(Database db) async {
  await db.execute(
    'DELETE FROM $kTableReviewLog WHERE Log_ID = (SELECT MAX(Log_ID) FROM $kTableReviewLog)',
  );
}

Future<void> deleteReviewLogById(Database db, int logId) async {
  await db.delete(
    kTableReviewLog,
    where: 'Log_ID = ?',
    whereArgs: [logId],
  );
}

// ============================================================================
// Hot 数据查询/写入（Quick_Screen 相关）
// ============================================================================

Future<void> markWordAsKnown(Database db, String uuid, int now) async {
  await db.insert(
    kTableQuickScreen,
    {
      'Concept_UUID': uuid,
      'Status': 1,
      'Screen_Date': now,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// 切换单词的快速筛选状态（认识 ↔ 默认）
/// known=true → 写入 Status=1
/// known=false → 删除记录（恢复默认）
Future<void> toggleWordScreenStatus(Database db, String uuid, bool known) async {
  if (known) {
    await db.insert(
      kTableQuickScreen,
      {
        'Concept_UUID': uuid,
        'Status': 1,
        'Screen_Date': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  } else {
    await db.delete(
      kTableQuickScreen,
      where: 'Concept_UUID = ?',
      whereArgs: [uuid],
    );
  }
}

Future<int> queryKnownCount(Database db) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) as cnt FROM $kTableQuickScreen WHERE Status = 1',
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<Set<String>> queryKnownUuids(Database db) async {
  final results = await db.query(
    kTableQuickScreen,
    columns: ['Concept_UUID'],
    where: 'Status = 1',
  );
  return results.map((e) => e['Concept_UUID'] as String).toSet();
}

// ============================================================================
// Hot 数据查询/写入（User_Settings 相关）
// ============================================================================

Future<String?> querySetting(Database db, String key) async {
  final results = await db.query(
    kTableUserSettings,
    where: 'Key = ?',
    whereArgs: [key],
    limit: 1,
  );
  if (results.isEmpty) return null;
  return results.first['Value'] as String?;
}

Future<int?> querySettingInt(Database db, String key) async {
  final v = await querySetting(db, key);
  return v != null ? int.tryParse(v) : null;
}

Future<void> setSetting(Database db, String key, String value) async {
  await db.insert(
    kTableUserSettings,
    {'Key': key, 'Value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

Future<void> setSettingInt(Database db, String key, int value) async {
  await setSetting(db, key, value.toString());
}

// ============================================================================
// 统计聚合查询
// ============================================================================

Future<int> queryTotalDueCount(Database db, int now) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) FROM $kTableCard WHERE Next_Review_Date <= ? AND Status IN (1,2,3)',
    [now],
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<int> queryTotalNewCount(Database db) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) FROM $kTableCard WHERE Status = 0',
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

Future<int> queryFavoriteCount(Database db) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) FROM $kTableCard WHERE Favorite = 1',
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

/// 查询某逻辑日（Local_Date_Str）的学习记录数
Future<int> queryLogCountByDate(Database db, String localDateStr) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) FROM $kTableReviewLog WHERE Local_Date_Str = ?',
    [localDateStr],
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

/// 查询某时间戳区间内 Quick_Screen 中标记为 known 的单词数（每个单词只计一次）
Future<int> queryTodayQuickKnownCount(Database db, int startOfDayMs, int endOfDayMs) async {
  final result = await db.rawQuery(
    'SELECT COUNT(*) FROM $kTableQuickScreen WHERE Status = 1 AND Screen_Date >= ? AND Screen_Date < ?',
    [startOfDayMs, endOfDayMs],
  );
  return Sqflite.firstIntValue(result) ?? 0;
}

/// 查询某逻辑日的各评级分布
Future<Map<int, int>> queryRatingDistributionByDate(
    Database db, String localDateStr) async {
  final results = await db.rawQuery(
    'SELECT Rating, COUNT(*) as cnt FROM $kTableReviewLog WHERE Local_Date_Str = ? GROUP BY Rating',
    [localDateStr],
  );
  return {for (final row in results) row['Rating'] as int: row['cnt'] as int};
}

/// 查询特定时间范围内的 Review_Log
Future<List<ReviewLogModel>> queryReviewLogsByDateRange(
    Database db, int startDate, int endDate) async {
  final results = await db.query(
    kTableReviewLog,
    where: 'Log_Date >= ? AND Log_Date < ?',
    whereArgs: [startDate, endDate],
    orderBy: 'Log_Date DESC',
  );
  return results.map((e) {
    final m = Map<String, dynamic>.from(e);
    return ReviewLogModel(
      logId: m['Log_ID'] as int?,
      conceptUuid: m['Concept_UUID'] as String,
      rating: m['Rating'] as int,
      logDate: m['Log_Date'] as int,
      localDateStr: m['Local_Date_Str'] as String,
      preStatus: m['Pre_Status'] as int,
      preR: (m['Pre_R'] as num).toDouble(),
      preS: (m['Pre_S'] as num).toDouble(),
    );
  }).toList();
}

/// 查询单个单词的历史评级分布
Future<Map<int, int>> queryRatingDistributionByUuid(
    Database db, String conceptUuid) async {
  final results = await db.rawQuery(
    'SELECT Rating, COUNT(*) as cnt FROM $kTableReviewLog WHERE Concept_UUID = ? GROUP BY Rating',
    [conceptUuid],
  );
  return {for (final row in results) row['Rating'] as int: row['cnt'] as int};
}

/// 查询特定 Concept_UUID 列表的 Review_Log（用于精确的 Session 统计）
Future<List<ReviewLogModel>> queryReviewLogsByUuids(
    Database db, Set<String> uuids, int startDate, int endDate) async {
  if (uuids.isEmpty) return [];
  final placeholders = List.filled(uuids.length, '?').join(',');
  final results = await db.rawQuery(
    'SELECT * FROM $kTableReviewLog WHERE Concept_UUID IN ($placeholders) AND Log_Date >= ? AND Log_Date < ? ORDER BY Log_Date ASC',
    [...uuids, startDate, endDate],
  );
  return results.map((e) {
    final m = Map<String, dynamic>.from(e);
    return ReviewLogModel(
      logId: m['Log_ID'] as int?,
      conceptUuid: m['Concept_UUID'] as String,
      rating: m['Rating'] as int,
      logDate: m['Log_Date'] as int,
      localDateStr: m['Local_Date_Str'] as String,
      preStatus: m['Pre_Status'] as int,
      preR: (m['Pre_R'] as num).toDouble(),
      preS: (m['Pre_S'] as num).toDouble(),
    );
  }).toList();
}

int _reviewAggInt(Map<String, Object?> r, String key) {
  final v = r[key];
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

class MonthlyStat {
  final String yearMonth; // 'YYYY-MM'
  final int reviewCount;
  final int goodCount;
  final int hardCount;
  final int againCount;
  final int easyCount;

  MonthlyStat({
    required this.yearMonth,
    required this.reviewCount,
    required this.goodCount,
    required this.hardCount,
    required this.againCount,
    required this.easyCount,
  });

  double get goodRate => reviewCount > 0 ? goodCount / reviewCount : 0;
}

/// 查询最近 N 个月的月度统计数据
Future<List<MonthlyStat>> queryMonthlyStats(Database db, int months) async {
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month - months + 1, 1);
  final startMs = startDate.millisecondsSinceEpoch;

  final results = await db.rawQuery('''
    SELECT
      substr(Local_Date_Str, 1, 7) AS year_month,
      COUNT(*) AS review_count,
      COALESCE(SUM(CASE WHEN Rating = 3 THEN 1 ELSE 0 END), 0) AS good_count,
      COALESCE(SUM(CASE WHEN Rating = 2 THEN 1 ELSE 0 END), 0) AS hard_count,
      COALESCE(SUM(CASE WHEN Rating = 1 THEN 1 ELSE 0 END), 0) AS again_count,
      COALESCE(SUM(CASE WHEN Rating = 4 THEN 1 ELSE 0 END), 0) AS easy_count
    FROM $kTableReviewLog
    WHERE Log_Date >= ?
    GROUP BY substr(Local_Date_Str, 1, 7)
    ORDER BY year_month ASC
  ''', [startMs]);

  return results.map((r) {
    final m = Map<String, Object?>.from(r);
    return MonthlyStat(
      yearMonth: m['year_month']! as String,
      reviewCount: _reviewAggInt(m, 'review_count'),
      goodCount: _reviewAggInt(m, 'good_count'),
      hardCount: _reviewAggInt(m, 'hard_count'),
      againCount: _reviewAggInt(m, 'again_count'),
      easyCount: _reviewAggInt(m, 'easy_count'),
    );
  }).toList();
}

/// 查询每年的统计数据
Future<Map<int, MonthlyStat>> queryYearlyStats(Database db, int years) async {
  final now = DateTime.now();
  final startDate = DateTime(now.year - years + 1, 1, 1);
  final startMs = startDate.millisecondsSinceEpoch;

  final results = await db.rawQuery('''
    SELECT
      CAST(substr(Local_Date_Str, 1, 4) AS INTEGER) AS year,
      COUNT(*) AS review_count,
      COALESCE(SUM(CASE WHEN Rating = 3 THEN 1 ELSE 0 END), 0) AS good_count,
      COALESCE(SUM(CASE WHEN Rating = 2 THEN 1 ELSE 0 END), 0) AS hard_count,
      COALESCE(SUM(CASE WHEN Rating = 1 THEN 1 ELSE 0 END), 0) AS again_count,
      COALESCE(SUM(CASE WHEN Rating = 4 THEN 1 ELSE 0 END), 0) AS easy_count
    FROM $kTableReviewLog
    WHERE Log_Date >= ?
    GROUP BY substr(Local_Date_Str, 1, 4)
    ORDER BY year ASC
  ''', [startMs]);

  final byYear = <int, MonthlyStat>{};
  for (final r in results) {
    final m = Map<String, Object?>.from(r);
    final y = _reviewAggInt(m, 'year');
    byYear[y] = MonthlyStat(
      yearMonth: y.toString(),
      reviewCount: _reviewAggInt(m, 'review_count'),
      goodCount: _reviewAggInt(m, 'good_count'),
      hardCount: _reviewAggInt(m, 'hard_count'),
      againCount: _reviewAggInt(m, 'again_count'),
      easyCount: _reviewAggInt(m, 'easy_count'),
    );
  }
  return byYear;
}

// ============================================================================
// 数据库迁移（对应文档 3.1 节）
// ============================================================================

Future<void> runMigrations(Database hotDb, Database romDb) async {
  // Web 上无法跨 IndexedDB 查询，跳过孤儿清理；非 Web 下走完整逻辑
  if (kIsWeb) return;

  // 孤儿记录清理：须在同一连接内 ATTACH ROM，不能用「路径.表名」（Web 上路径含 .db 会语法错误）
  const romAlias = 'rom_db';
  await hotDb.execute('ATTACH DATABASE ? AS $romAlias', [romDb.path]);
  try {
    await hotDb.execute('''
      DELETE FROM $kTableCard
      WHERE Concept_UUID NOT IN (SELECT Concept_UUID FROM $romAlias.$kTableNote)
    ''');
  } finally {
    await hotDb.execute('DETACH DATABASE $romAlias');
  }

  // 迁移：为 Note 表添加 BNC 和 FRQ 列（如果不存在）
  try {
    await romDb.execute('ALTER TABLE $kTableNote ADD COLUMN BNC INTEGER DEFAULT 0');
  } catch (_) {}
  try {
    await romDb.execute('ALTER TABLE $kTableNote ADD COLUMN FRQ INTEGER DEFAULT 0');
  } catch (_) {}

  // 迁移：为 Card 表添加 Tag_List 列（如果不存在）
  try {
    await hotDb.execute('ALTER TABLE $kTableCard ADD COLUMN Tag_List TEXT');
  } catch (_) {}

  // 迁移：回填现有 Card 的 Tag_List（从 Note 表关联）
  try {
    final updated = await hotDb.rawUpdate('''
      UPDATE Card
      SET Tag_List = (
        SELECT Note.Tag_List FROM Note
        WHERE Note.Concept_UUID = Card.Concept_UUID
        LIMIT 1
      )
      WHERE Card.Tag_List IS NULL OR Card.Tag_List = ''
    ''');
    if (updated > 0) {
      print('[DB] Migration: Card.Tag_List 回填完成，更新了 $updated 条');
    }
  } catch (e) {
    print('[DB] Migration Card.Tag_List 回填失败: $e');
  }

  // 日志修剪：保留与报表窗口一致（queryYearlyStats 默认 3 年），避免月度/年度统计被过早清空
  const reviewLogRetentionDays = 1095;
  final logCutoff =
      DateTime.now().millisecondsSinceEpoch -
          const Duration(days: reviewLogRetentionDays).inMilliseconds;
  await hotDb.delete(
    kTableReviewLog,
    where: 'Log_Date < ?',
    whereArgs: [logCutoff],
  );
}

// ============================================================================
// 导入导出（对应文档 11.1 节）
// ============================================================================

Future<String> exportProgressJson(Database hotDb) async {
  // 导出：剔除 Status=0 的未学数据
  final cards = await hotDb.query(
    kTableCard,
    where: 'Status != ?',
    whereArgs: [CardStatus.newCard],
  );

  final logs = await hotDb.query(kTableReviewLog);
  final settings = await hotDb.query(kTableUserSettings);

  final exportData = {
    'exportTime': DateTime.now().millisecondsSinceEpoch,
    'version': '2.1',
    'cards': cards,
    'reviewLogs': logs,
    'settings': settings,
  };

  return _jsonEncode(exportData);
}

Future<ImportResult> importProgressJson(
    Database hotDb, String jsonStr) async {
  try {
    final data = _jsonDecode(jsonStr) as Map<String, dynamic>;
    int imported = 0;
    int skipped = 0;

    // 导入 Card（只更新用户库中已存在的卡，不添加新卡）
    final cards = data['cards'] as List<dynamic>? ?? [];
    for (final card in cards) {
      final map = Map<String, dynamic>.from(card as Map);
      final uuid = map['Concept_UUID'] as String;
      // 检查该 UUID 是否已在用户库（HotDB）中存在
      // 只有存在的卡才更新其进度，不存在的卡则跳过（避免导入不完整的词汇数据）
      final exists = await hotDb.query(
        kTableCard,
        where: 'Concept_UUID = ?',
        whereArgs: [uuid],
        limit: 1,
      );
      if (exists.isNotEmpty) {
        // 存在则 UPDATE 用户学习进度
        await hotDb.update(
          kTableCard,
          map,
          where: 'Concept_UUID = ?',
          whereArgs: [uuid],
        );
        imported++;
      } else {
        skipped++;
      }
    }

    // 导入 Review_Log（追加，不覆盖）
    final logs = data['reviewLogs'] as List<dynamic>? ?? [];
    final batch = hotDb.batch();
    for (final log in logs) {
      batch.insert(kTableReviewLog, Map<String, dynamic>.from(log as Map),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    return ImportResult(imported: imported, skipped: skipped);
  } catch (e) {
    throw FormatException('IMPORT_FORMAT_ERROR: $e');
  }
}

class ImportResult {
  final int imported;
  final int skipped;
  ImportResult({required this.imported, required this.skipped});
}

// ============================================================================
// 辅助 JSON 编解码（避免直接引用 dart:convert）
// ============================================================================

dynamic _jsonDecode(String str) {
  // ignore: avoid_dynamic_calls
  return _jsonDecodeImpl(str, 0).value;
}

dynamic _jsonEncode(dynamic obj) {
  if (obj == null) return 'null';
  if (obj is String) return '"${_escapeString(obj)}"';
  if (obj is num || obj is bool) return obj.toString();
  if (obj is List) {
    return '[${obj.map(_jsonEncode).join(',')}]';
  }
  if (obj is Map) {
    final entries = obj.entries.map((e) => '"${_escapeString(e.key.toString())}":${_jsonEncode(e.value)}');
    return '{${entries.join(',')}}';
  }
  return 'null';
}

String _escapeString(String s) {
  return s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t');
}

// 简单递归下降 JSON 解析器
class _JsonResult {
  final dynamic value;
  final int pos;
  _JsonResult(this.value, this.pos);
}

_JsonResult _jsonDecodeImpl(String s, int pos) {
  while (pos < s.length && (s[pos] == ' ' || s[pos] == '\n' || s[pos] == '\r' || s[pos] == '\t')) {
    pos++;
  }
  if (pos >= s.length) return _JsonResult(null, pos);

  final c = s[pos];
  if (c == '"') return _jsonDecodeString(s, pos + 1);
  if (c == '[') return _jsonDecodeArray(s, pos + 1);
  if (c == '{') return _jsonDecodeObject(s, pos + 1);
  if (c == 't' && s.substring(pos, pos + 4) == 'true') return _JsonResult(true, pos + 4);
  if (c == 'f' && s.substring(pos, pos + 5) == 'false') return _JsonResult(false, pos + 5);
  if (c == 'n' && s.substring(pos, pos + 4) == 'null') return _JsonResult(null, pos + 4);
  return _jsonDecodeNumber(s, pos);
}

_JsonResult _jsonDecodeString(String s, int pos) {
  final buf = StringBuffer();
  while (pos < s.length && s[pos] != '"') {
    if (s[pos] == '\\' && pos + 1 < s.length) {
      pos++;
      switch (s[pos]) {
        case 'n': buf.write('\n'); break;
        case 'r': buf.write('\r'); break;
        case 't': buf.write('\t'); break;
        case '"': buf.write('"'); break;
        case '\\': buf.write('\\'); break;
        default: buf.write(s[pos]);
      }
    } else {
      buf.write(s[pos]);
    }
    pos++;
  }
  return _JsonResult(buf.toString(), pos + 1);
}

_JsonResult _jsonDecodeArray(String s, int pos) {
  final list = <dynamic>[];
  while (pos < s.length) {
    while (pos < s.length && (s[pos] == ' ' || s[pos] == '\n' || s[pos] == '\r' || s[pos] == '\t')) pos++;
    if (pos >= s.length || s[pos] == ']') return _JsonResult(list, pos + 1);
    final r = _jsonDecodeImpl(s, pos);
    list.add(r.value);
    pos = r.pos;
    while (pos < s.length && (s[pos] == ' ' || s[pos] == '\n' || s[pos] == '\r' || s[pos] == '\t')) pos++;
    if (pos >= s.length) return _JsonResult(list, pos);
    if (s[pos] == ',') pos++;
  }
  return _JsonResult(list, pos);
}

_JsonResult _jsonDecodeObject(String s, int pos) {
  final map = <String, dynamic>{};
  while (pos < s.length) {
    while (pos < s.length && (s[pos] == ' ' || s[pos] == '\n' || s[pos] == '\r' || s[pos] == '\t')) pos++;
    if (pos >= s.length || s[pos] == '}') return _JsonResult(map, pos + 1);
    if (s[pos] == ',') { pos++; continue; }
    final keyResult = _jsonDecodeImpl(s, pos);
    final key = keyResult.value as String;
    pos = keyResult.pos;
    while (pos < s.length && (s[pos] == ' ' || s[pos] == '\n' || s[pos] == '\r' || s[pos] == '\t')) pos++;
    if (pos < s.length && s[pos] == ':') pos++;
    while (pos < s.length && (s[pos] == ' ' || s[pos] == '\n' || s[pos] == '\r' || s[pos] == '\t')) pos++;
    final valResult = _jsonDecodeImpl(s, pos);
    map[key] = valResult.value;
    pos = valResult.pos;
  }
  return _JsonResult(map, pos);
}

_JsonResult _jsonDecodeNumber(String s, int pos) {
  final start = pos;
  if (pos < s.length && (s[pos] == '-' || s[pos] == '+')) pos++;
  while (pos < s.length && (s[pos].codeUnitAt(0) >= 48 && s[pos].codeUnitAt(0) <= 57)) pos++;
  if (pos < s.length && s[pos] == '.') pos++;
  while (pos < s.length && (s[pos].codeUnitAt(0) >= 48 && s[pos].codeUnitAt(0) <= 57)) pos++;
  if (pos < s.length && (s[pos] == 'e' || s[pos] == 'E')) {
    pos++;
    if (pos < s.length && (s[pos] == '+' || s[pos] == '-')) pos++;
    while (pos < s.length && (s[pos].codeUnitAt(0) >= 48 && s[pos].codeUnitAt(0) <= 57)) pos++;
  }
  final numStr = s.substring(start, pos);
  final num = numStr.contains('.') || numStr.contains('e') || numStr.contains('E')
      ? double.tryParse(numStr)
      : int.tryParse(numStr);
  return _JsonResult(num ?? 0, pos);
}
