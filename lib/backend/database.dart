library wordmemory.database;

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================================
// WordMemory SRS - Database Schema
// 对应文档：词汇SRS&SDD v2.1 第 4 节
// ============================================================================

// ROM Data（只读静态数据，随安装包下发）
const String kRomDbName = 'wordmemory_rom.db';
// Hot Data（读写，用户私有目录）
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

Future<void> _attachRomDb(Database db, String romPath) async {
  await db.execute("ATTACH DATABASE ? AS rom_db", [romPath]);
}

// ============================================================================
// ROM Data 建表脚本
// ============================================================================

const String kCreateNoteSql = '''
CREATE TABLE Note (
    Concept_UUID TEXT PRIMARY KEY,
    Spelling TEXT NOT NULL,
    Phonetic TEXT NOT NULL,
    Definition TEXT NOT NULL,
    Etymology_JSON TEXT,
    Micro_Context_JSON TEXT NOT NULL,
    Content_JSON TEXT NOT NULL
) STRICT;
''';

const String kCreateTreeRootSql = '''
CREATE TABLE Tree_Root (
    Root_ID TEXT PRIMARY KEY,
    Root_Name TEXT NOT NULL,
    Root_Definition TEXT NOT NULL,
    Root_Group TEXT NOT NULL
) STRICT;
''';

const String kCreateTreeWordSql = '''
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
    Random_Sort_ID INTEGER NOT NULL
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
      await db.execute(kCreateTreeRootSql);
      await db.execute(kCreateTreeWordSql);
      await db.execute(kCreateTopicSql);
      await db.execute(kCreateArticleSql);
      await _seedRomData(db);
      print('[DB] ROM onCreate 完成');
    },
    onOpen: (db) async {
      print('[DB] ROM onOpen 开始');
      await _ensureRomDataIntegrity(db);
      print('[DB] ROM onOpen 完成');
    },
  );
}

/// 确保 ROM 数据完整性。如果 Note 表为空则重新写入数据
Future<void> _ensureRomDataIntegrity(Database db) async {
  print('[DB] _ensureRomDataIntegrity 开始');
  final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Note'));
  print('[DB] _ensureRomDataIntegrity Note数量=$count');
  if (count == null || count == 0) {
    print('[DB] _ensureRomDataIntegrity Note为空，开始补种...');
    await _seedRomData(db);
    print('[DB] _ensureRomDataIntegrity 补种完成');
  }
  print('[DB] _ensureRomDataIntegrity 结束');
}

/// 公共导出版本，供 provider.dart 调用
Future<void> ensureRomDataIntegrity(Database db) => _ensureRomDataIntegrity(db);

// ============================================================================
// ROM 示例数据初始化
// ============================================================================

Future<void> _seedRomData(Database db) async {
  // --------------------------------------------------------------------------
  // Note 数据（20个词汇）
  // --------------------------------------------------------------------------
  final notes = <Map<String, dynamic>>[
    {
      'Concept_UUID': 'note_accede',
      'Spelling': 'accede',
      'Phonetic': '/əkˈsiːd/',
      'Definition': 'v. 同意；答应；加入',
      'Etymology_JSON': '{"prefix":"ac-=ad-=to","root":"ced=go","suffix":""}',
      'Micro_Context_JSON': '{"en":"The king refused to accede to the demands.","zh":"国王拒绝答应这些要求。"}',
      'Content_JSON': '{"spelling":"accede","phonetic":"/əkˈsiːd/","definition":"v. 同意；答应；加入","etymology":"ac-=向+ced-=走→走到一起→同意","example":"The king refused to accede to the demands.","translation":"国王拒绝答应这些要求。"}',
    },
    {
      'Concept_UUID': 'note_proceed',
      'Spelling': 'proceed',
      'Phonetic': '/prəˈsiːd/',
      'Definition': 'v. 继续进行；前进；着手',
      'Etymology_JSON': '{"prefix":"pro-=forward","root":"ced=go","suffix":""}',
      'Micro_Context_JSON': '{"en":"Let us proceed with the plan.","zh":"让我们继续执行计划。"}',
      'Content_JSON': '{"spelling":"proceed","phonetic":"/prəˈsiːd/","definition":"v. 继续进行；前进；着手","etymology":"pro-=向前+ced-=走→向前走→继续进行","example":"Let us proceed with the plan.","translation":"让我们继续执行计划。"}',
    },
    {
      'Concept_UUID': 'note_concede',
      'Spelling': 'concede',
      'Phonetic': '/kənˈsiːd/',
      'Definition': 'v. 承认；让步；给予',
      'Etymology_JSON': '{"prefix":"con-=completely","root":"ced=go","suffix":""}',
      'Micro_Context_JSON': '{"en":"He conceded that he was wrong.","zh":"他承认自己错了。"}',
      'Content_JSON': '{"spelling":"concede","phonetic":"/kənˈsiːd/","definition":"v. 承认；让步；给予","etymology":"con-=完全+ced-=走→走开→让步","example":"He conceded that he was wrong.","translation":"他承认自己错了。"}',
    },
    {
      'Concept_UUID': 'note_exceed',
      'Spelling': 'exceed',
      'Phonetic': '/ɪkˈsiːd/',
      'Definition': 'v. 超过；超越；胜过',
      'Etymology_JSON': '{"prefix":"ex-=out","root":"ced=go","suffix":""}',
      'Micro_Context_JSON': '{"en":"The cost exceeded our budget.","zh":"费用超出了我们的预算。"}',
      'Content_JSON': '{"spelling":"exceed","phonetic":"/ɪkˈsiːd/","definition":"v. 超过；超越；胜过","etymology":"ex-=出+ced-=走→走出→超过","example":"The cost exceeded our budget.","translation":"费用超出了我们的预算。"}',
    },
    {
      'Concept_UUID': 'note_adapt',
      'Spelling': 'adapt',
      'Phonetic': '/əˈdæpt/',
      'Definition': 'v. 使适应；改编',
      'Etymology_JSON': '{"prefix":"ad-=to","root":"apt=fit","suffix":""}',
      'Micro_Context_JSON': '{"en":"We must adapt to the changes.","zh":"我们必须适应这些变化。"}',
      'Content_JSON': '{"spelling":"adapt","phonetic":"/əˈdæpt/","definition":"v. 使适应；改编","etymology":"ad-=向+apt=适合→使适合→适应","example":"We must adapt to the changes.","translation":"我们必须适应这些变化。"}',
    },
    {
      'Concept_UUID': 'note_adopt',
      'Spelling': 'adopt',
      'Phonetic': '/əˈdɒpt/',
      'Definition': 'v. 采纳；收养；采用',
      'Etymology_JSON': '{"prefix":"ad-=to","root":"opt=choose","suffix":""}',
      'Micro_Context_JSON': '{"en":"The committee adopted the new policy.","zh":"委员会采纳了新政策。"}',
      'Content_JSON': '{"spelling":"adopt","phonetic":"/əˈdɒpt/","definition":"v. 采纳；收养；采用","etymology":"ad-=向+opt=选择→选择→采纳","example":"The committee adopted the new policy.","translation":"委员会采纳了新政策。"}',
    },
    {
      'Concept_UUID': 'note_combine',
      'Spelling': 'combine',
      'Phonetic': '/kəmˈbaɪn/',
      'Definition': 'v. 联合；结合；合并',
      'Etymology_JSON': '{"prefix":"com-=together","root":"bin=two","suffix":""}',
      'Micro_Context_JSON': '{"en":"We combined our efforts to finish the project.","zh":"我们合并力量完成了这个项目。"}',
      'Content_JSON': '{"spelling":"combine","phonetic":"/kəmˈbaɪn/","definition":"v. 联合；结合；合并","etymology":"com-=共同+bin=二→合二为一→结合","example":"We combined our efforts to finish the project.","translation":"我们合并力量完成了这个项目。"}',
    },
    {
      'Concept_UUID': 'note_compete',
      'Spelling': 'compete',
      'Phonetic': '/kəmˈpiːt/',
      'Definition': 'v. 竞争；比赛；对抗',
      'Etymology_JSON': '{"prefix":"com-=together","root":"pet=seek","suffix":""}',
      'Micro_Context_JSON': '{"en":"Several teams will compete for the prize.","zh":"几个团队将竞争这个奖项。"}',
      'Content_JSON': '{"spelling":"compete","phonetic":"/kəmˈpiːt/","definition":"v. 竞争；比赛；对抗","etymology":"com-=共同+pet=追求→共同追求→竞争","example":"Several teams will compete for the prize.","translation":"几个团队将竞争这个奖项。"}',
    },
    {
      'Concept_UUID': 'note_describe',
      'Spelling': 'describe',
      'Phonetic': '/dɪˈskraɪb/',
      'Definition': 'v. 描述；形容；描绘',
      'Etymology_JSON': '{"prefix":"de-=down","root":"scrib=write","suffix":""}',
      'Micro_Context_JSON': '{"en":"Can you describe what happened?","zh":"你能描述一下发生了什么吗？"}',
      'Content_JSON': '{"spelling":"describe","phonetic":"/dɪˈskraɪb/","definition":"v. 描述；形容；描绘","etymology":"de-=向下+scrib=写→写下→描述","example":"Can you describe what happened?","translation":"你能描述一下发生了什么吗？"}',
    },
    {
      'Concept_UUID': 'note_decide',
      'Spelling': 'decide',
      'Phonetic': '/dɪˈsaɪd/',
      'Definition': 'v. 决定；判决；解决',
      'Etymology_JSON': '{"prefix":"de-=completely","root":"cid=cut","suffix":""}',
      'Micro_Context_JSON': '{"en":"We need to decide by tomorrow.","zh":"我们需要在明天之前决定。"}',
      'Content_JSON': '{"spelling":"decide","phonetic":"/dɪˈsaɪd/","definition":"v. 决定；判决；解决","etymology":"de-=完全+cid=切→切掉→决定","example":"We need to decide by tomorrow.","translation":"我们需要在明天之前决定。"}',
    },
    {
      'Concept_UUID': 'note_react',
      'Spelling': 'react',
      'Phonetic': '/riˈækt/',
      'Definition': 'v. 反应；起反应；回应',
      'Etymology_JSON': '{"prefix":"re-=back","root":"act=do","suffix":""}',
      'Micro_Context_JSON': '{"en":"How did she react to the news?","zh":"她对这个消息有什么反应？"}',
      'Content_JSON': '{"spelling":"react","phonetic":"/riˈækt/","definition":"v. 反应；起反应；回应","etymology":"re-=回+act=做→回做→反应","example":"How did she react to the news?","translation":"她对这个消息有什么反应？"}',
    },
    {
      'Concept_UUID': 'note_return',
      'Spelling': 'return',
      'Phonetic': '/rɪˈtɜːn/',
      'Definition': 'v. 返回；回来；归还',
      'Etymology_JSON': '{"prefix":"re-=back","root":"turn=turn","suffix":""}',
      'Micro_Context_JSON': '{"en":"I will return the book tomorrow.","zh":"我明天会还这本书。"}',
      'Content_JSON': '{"spelling":"return","phonetic":"/rɪˈtɜːn/","definition":"v. 返回；回来；归还","etymology":"re-=回+turn=转→转回→返回","example":"I will return the book tomorrow.","translation":"我明天会还这本书。"}',
    },
    {
      'Concept_UUID': 'note_review',
      'Spelling': 'review',
      'Phonetic': '/rɪˈvjuː/',
      'Definition': 'v. 复习；回顾；审核',
      'Etymology_JSON': '{"prefix":"re-=again","root":"view=see","suffix":""}',
      'Micro_Context_JSON': '{"en":"I need to review my notes before the exam.","zh":"考试前我需要复习笔记。"}',
      'Content_JSON': '{"spelling":"review","phonetic":"/rɪˈvjuː/","definition":"v. 复习；回顾；审核","etymology":"re-=再+view=看→再看→复习","example":"I need to review my notes before the exam.","translation":"考试前我需要复习笔记。"}',
    },
    {
      'Concept_UUID': 'note_translate',
      'Spelling': 'translate',
      'Phonetic': '/trænzˈleɪt/',
      'Definition': 'v. 翻译；转化；解释',
      'Etymology_JSON': '{"prefix":"trans-=across","root":"lat=carry","suffix":""}',
      'Micro_Context_JSON': '{"en":"Can you translate this sentence into English?","zh":"你能把这句话翻译成英语吗？"}',
      'Content_JSON': '{"spelling":"translate","phonetic":"/trænzˈleɪt/","definition":"v. 翻译；转化；解释","etymology":"trans-=跨+lat=带→带过去→翻译","example":"Can you translate this sentence into English?","translation":"你能把这句话翻译成英语吗？"}',
    },
    {
      'Concept_UUID': 'note_transport',
      'Spelling': 'transport',
      'Phonetic': '/trænzˈpɔːt/',
      'Definition': 'v. 运输；运送；搬运',
      'Etymology_JSON': '{"prefix":"trans-=across","root":"port=carry","suffix":""}',
      'Micro_Context_JSON': '{"en":"The goods were transported by train.","zh":"货物是通过火车运输的。"}',
      'Content_JSON': '{"spelling":"transport","phonetic":"/trænzˈpɔːt/","definition":"v. 运输；运送；搬运","etymology":"trans-=跨+port=搬运→搬运过去→运输","example":"The goods were transported by train.","translation":"货物是通过火车运输的。"}',
    },
    {
      'Concept_UUID': 'note_transform',
      'Spelling': 'transform',
      'Phonetic': '/trænzˈfɔːm/',
      'Definition': 'v. 改变；改造；转变',
      'Etymology_JSON': '{"prefix":"trans-=across","root":"form=shape","suffix":""}',
      'Micro_Context_JSON': '{"en":"The city has been transformed over the years.","zh":"这座城市在这些年里发生了巨大的变化。"}',
      'Content_JSON': '{"spelling":"transform","phonetic":"/trænzˈfɔːm/","definition":"v. 改变；改造；转变","etymology":"trans-=跨+form=形状→改变形状→改造","example":"The city has been transformed over the years.","translation":"这座城市在这些年里发生了巨大的变化。"}',
    },
    {
      'Concept_UUID': 'note_reduce',
      'Spelling': 'reduce',
      'Phonetic': '/rɪˈdjuːs/',
      'Definition': 'v. 减少；降低；缩小',
      'Etymology_JSON': '{"prefix":"re-=back","root":"duc=lead","suffix":""}',
      'Micro_Context_JSON': '{"en":"We need to reduce our expenses.","zh":"我们需要减少开支。"}',
      'Content_JSON': '{"spelling":"reduce","phonetic":"/rɪˈdjuːs/","definition":"v. 减少；降低；缩小","etymology":"re-=回+duc=引导→往回引→减少","example":"We need to reduce our expenses.","translation":"我们需要减少开支。"}',
    },
    {
      'Concept_UUID': 'note_produce',
      'Spelling': 'produce',
      'Phonetic': '/prəˈdjuːs/',
      'Definition': 'v. 生产；产生；制造',
      'Etymology_JSON': '{"prefix":"pro-=forward","root":"duc=lead","suffix":""}',
      'Micro_Context_JSON': '{"en":"The factory produces thousands of cars each year.","zh":"这家工厂每年生产数千辆汽车。"}',
      'Content_JSON': '{"spelling":"produce","phonetic":"/prəˈdjuːs/","definition":"v. 生产；产生；制造","etymology":"pro-=向前+duc=引导→引导出来→生产","example":"The factory produces thousands of cars each year.","translation":"这家工厂每年生产数千辆汽车。"}',
    },
    {
      'Concept_UUID': 'note_introduce',
      'Spelling': 'introduce',
      'Phonetic': '/ˌɪntrəˈdjuːs/',
      'Definition': 'v. 介绍；引进；提出',
      'Etymology_JSON': '{"prefix":"intro-=within","root":"duc=lead","suffix":""}',
      'Micro_Context_JSON': '{"en":"Let me introduce my colleague to you.","zh":"让我给你介绍一下我的同事。"}',
      'Content_JSON': '{"spelling":"introduce","phonetic":"/ˌɪntrəˈdjuːs/","definition":"v. 介绍；引进；提出","etymology":"intro-=向内+duc=引导→引导进来→介绍","example":"Let me introduce my colleague to you.","translation":"让我给你介绍一下我的同事。"}',
    },
    {
      'Concept_UUID': 'note_conduct',
      'Spelling': 'conduct',
      'Phonetic': '/kənˈdʌkt/',
      'Definition': 'v. 引导；传导；实施',
      'Etymology_JSON': '{"prefix":"con-=together","root":"duct=lead","suffix":""}',
      'Micro_Context_JSON': '{"en":"The teacher will conduct the experiment.","zh":"老师将进行这个实验。"}',
      'Content_JSON': '{"spelling":"conduct","phonetic":"/kənˈdʌkt/","definition":"v. 引导；传导；实施","etymology":"con-=共同+duct=引导→引导到一起→组织","example":"The teacher will conduct the experiment.","translation":"老师将进行这个实验。"}',
    },
  ];

  for (final note in notes) {
    await db.insert(kTableNote, note);
  }

  // --------------------------------------------------------------------------
  // Tree_Root 数据（6个词根，按 A/C/D/R/T 分组）
  // --------------------------------------------------------------------------
  final treeRoots = [
    {'Root_ID': 'root_ad', 'Root_Name': 'ad', 'Root_Definition': '向、靠近', 'Root_Group': 'A'},
    {'Root_ID': 'root_ced', 'Root_Name': 'ced', 'Root_Definition': '走、前进', 'Root_Group': 'C'},
    // D组
    {'Root_ID': 'root_de', 'Root_Name': 'de', 'Root_Definition': '向下、离开、否定', 'Root_Group': 'D'},
    // R组
    {'Root_ID': 'root_re', 'Root_Name': 're', 'Root_Definition': '再、回来', 'Root_Group': 'R'},
    // T组
    {'Root_ID': 'root_trans', 'Root_Name': 'trans', 'Root_Definition': '跨越、改变', 'Root_Group': 'T'},
    {'Root_ID': 'root_duct', 'Root_Name': 'duct', 'Root_Definition': '引导、带领', 'Root_Group': 'D'},
    // P组 - 新增词根
    {'Root_ID': 'root_pro', 'Root_Name': 'pro', 'Root_Definition': '向前、替代', 'Root_Group': 'P'},
    {'Root_ID': 'root_pre', 'Root_Name': 'pre', 'Root_Definition': '前、预先', 'Root_Group': 'P'},
    // S组 - 新增词根
    {'Root_ID': 'root_sub', 'Root_Name': 'sub', 'Root_Definition': '下、在下', 'Root_Group': 'S'},
    // D组 - 新增词根
    {'Root_ID': 'root_dis', 'Root_Name': 'dis', 'Root_Definition': '分开、否定', 'Root_Group': 'D'},
    // I组 - 新增词根
    {'Root_ID': 'root_in', 'Root_Name': 'in', 'Root_Definition': '内、向内', 'Root_Group': 'I'},
  ];

  for (final root in treeRoots) {
    await db.insert(kTableTreeRoot, root);
  }

  // --------------------------------------------------------------------------
  // Tree_Word 数据（派生词）
  // --------------------------------------------------------------------------
  final treeWords = [
    // ced 词根
    {'Root_ID': 'root_ced', 'Concept_UUID': 'note_accede', 'Compound_Form': 'ac+ced+e', 'Compound_Meaning': '向+走+e', 'Final_Meaning': '走到一起→同意', 'Sort_Order': 1},
    {'Root_ID': 'root_ced', 'Concept_UUID': 'note_proceed', 'Compound_Form': 'pro+ceed', 'Compound_Meaning': '向前+走', 'Final_Meaning': '向前走→继续', 'Sort_Order': 2},
    {'Root_ID': 'root_ced', 'Concept_UUID': 'note_concede', 'Compound_Form': 'con+cede', 'Compound_Meaning': '共同+走', 'Final_Meaning': '共同走→让步', 'Sort_Order': 3},
    {'Root_ID': 'root_ced', 'Concept_UUID': 'note_exceed', 'Compound_Form': 'ex+ceed', 'Compound_Meaning': '出+走', 'Final_Meaning': '走出→超过', 'Sort_Order': 4},
    // ad 词根
    {'Root_ID': 'root_ad', 'Concept_UUID': 'note_adapt', 'Compound_Form': 'ad+apt', 'Compound_Meaning': '向+适合', 'Final_Meaning': '使适合→适应', 'Sort_Order': 1},
    {'Root_ID': 'root_ad', 'Concept_UUID': 'note_adopt', 'Compound_Form': 'ad+opt', 'Compound_Meaning': '向+选择', 'Final_Meaning': '选择→采纳', 'Sort_Order': 2},
    {'Root_ID': 'root_ad', 'Concept_UUID': 'note_combine', 'Compound_Form': 'com+bine', 'Compound_Meaning': '共同+二', 'Final_Meaning': '合二为一→合并', 'Sort_Order': 3},
    {'Root_ID': 'root_ad', 'Concept_UUID': 'note_compete', 'Compound_Form': 'com+pete', 'Compound_Meaning': '共同+追求', 'Final_Meaning': '共同追求→竞争', 'Sort_Order': 4},
    // de 词根
    {'Root_ID': 'root_de', 'Concept_UUID': 'note_describe', 'Compound_Form': 'de+scribe', 'Compound_Meaning': '向下+写', 'Final_Meaning': '写下→描述', 'Sort_Order': 1},
    {'Root_ID': 'root_de', 'Concept_UUID': 'note_decide', 'Compound_Form': 'de+cide', 'Compound_Meaning': '完全+切', 'Final_Meaning': '切掉→决定', 'Sort_Order': 2},
    {'Root_ID': 'root_de', 'Concept_UUID': 'note_reduce', 'Compound_Form': 're+duce', 'Compound_Meaning': '回+引导', 'Final_Meaning': '往回引→减少', 'Sort_Order': 3},
    // re 词根
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_react', 'Compound_Form': 're+act', 'Compound_Meaning': '回+做', 'Final_Meaning': '回做→反应', 'Sort_Order': 1},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_return', 'Compound_Form': 're+turn', 'Compound_Meaning': '回+转', 'Final_Meaning': '转回→返回', 'Sort_Order': 2},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_review', 'Compound_Form': 're+view', 'Compound_Meaning': '再+看', 'Final_Meaning': '再看→复习', 'Sort_Order': 3},
    // trans 词根
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_translate', 'Compound_Form': 'trans+late', 'Compound_Meaning': '跨+带', 'Final_Meaning': '带过去→翻译', 'Sort_Order': 1},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transport', 'Compound_Form': 'trans+port', 'Compound_Meaning': '跨+搬运', 'Final_Meaning': '搬运过去→运输', 'Sort_Order': 2},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transform', 'Compound_Form': 'trans+form', 'Compound_Meaning': '跨+形状', 'Final_Meaning': '改变形状→改造', 'Sort_Order': 3},
    // duct 词根
    {'Root_ID': 'root_duct', 'Concept_UUID': 'note_produce', 'Compound_Form': 'pro+duce', 'Compound_Meaning': '向前+引导', 'Final_Meaning': '引导出来→生产', 'Sort_Order': 1},
    {'Root_ID': 'root_duct', 'Concept_UUID': 'note_introduce', 'Compound_Form': 'intro+duce', 'Compound_Meaning': '向内+引导', 'Final_Meaning': '引导进来→介绍', 'Sort_Order': 2},
    {'Root_ID': 'root_duct', 'Concept_UUID': 'note_conduct', 'Compound_Form': 'con+duct', 'Compound_Meaning': '共同+引导', 'Final_Meaning': '引导到一起→组织', 'Sort_Order': 3},
    // pro 词根 - 新增
    {'Root_ID': 'root_pro', 'Concept_UUID': 'note_proceed', 'Compound_Form': 'pro+ceed', 'Compound_Meaning': '向前+走', 'Final_Meaning': '向前走→前进、进行', 'Sort_Order': 1},
    // pre 词根 - 新增
    {'Root_ID': 'root_pre', 'Concept_UUID': 'note_preview', 'Compound_Form': 'pre+view', 'Compound_Meaning': '预先+看', 'Final_Meaning': '再看→预习、预映', 'Sort_Order': 1},
    {'Root_ID': 'root_pre', 'Concept_UUID': 'note_predict', 'Compound_Form': 'pre+dict', 'Compound_Meaning': '预先+说', 'Final_Meaning': '预先说→预言、预测', 'Sort_Order': 2},
    // sub 词根 - 新增
    {'Root_ID': 'root_sub', 'Concept_UUID': 'note_submit', 'Compound_Form': 'sub+mit', 'Compound_Meaning': '下+放', 'Final_Meaning': '往下放→提交、呈递', 'Sort_Order': 1},
    // dis 词根 - 新增
    {'Root_ID': 'root_dis', 'Concept_UUID': 'note_disagree', 'Compound_Form': 'dis+agree', 'Compound_Meaning': '不+同意', 'Final_Meaning': '不同意→意见不合', 'Sort_Order': 1},
    {'Root_ID': 'root_dis', 'Concept_UUID': 'note_disappear', 'Compound_Form': 'dis+appear', 'Compound_Meaning': '不+出现', 'Final_Meaning': '不出现→消失、不见', 'Sort_Order': 2},
    // in 词根 - 新增
    {'Root_ID': 'root_in', 'Concept_UUID': 'note_inside', 'Compound_Form': 'in+side', 'Compound_Meaning': '内+边', 'Final_Meaning': '内边→内部', 'Sort_Order': 1},
    {'Root_ID': 'root_in', 'Concept_UUID': 'note_inject', 'Compound_Form': 'in+ject', 'Compound_Meaning': '内+扔', 'Final_Meaning': '往内扔→注射、注入', 'Sort_Order': 2},
  ];

  for (final word in treeWords) {
    await db.insert(kTableTreeWord, word);
  }

  // --------------------------------------------------------------------------
  // Topic & Article 数据
  // --------------------------------------------------------------------------
  // 科技主题
  await db.insert(kTableTopic, {
    'Topic_ID': 'topic_tech',
    'Topic_Name': '科技词汇',
    'Topic_Name_EN': 'Technology',
    'Word_Count': 4,
  });

  // 科技文章：AI与未来
  await db.insert(kTableArticle, {
    'Article_ID': 'article_tech_1',
    'Topic_ID': 'topic_tech',
    'Word_Count': 4,
    'Content_JSON': _buildArticleContent([
      {'uuid': 'note_translate', 't': 'This new AI system can ', 'c': 0},
      {'uuid': 'note_translate', 't': 'translate', 'c': 1},
      {'uuid': 'note_translate', 't': ' languages in real time. It uses advanced algorithms to ', 'c': 0},
      {'uuid': 'note_produce', 't': 'produce', 'c': 1},
      {'uuid': 'note_produce', 't': ' natural-sounding speech. The technology will ', 'c': 0},
      {'uuid': 'note_transform', 't': 'transform', 'c': 1},
      {'uuid': 'note_transform', 't': ' how we communicate globally.', 'c': 0},
    ]),
  });

  // 科技文章2：自动驾驶
  await db.insert(kTableArticle, {
    'Article_ID': 'article_tech_2',
    'Topic_ID': 'topic_tech',
    'Word_Count': 3,
    'Content_JSON': _buildArticleContent([
      {'uuid': 'note_introduce', 't': 'Self-driving cars will soon ', 'c': 0},
      {'uuid': 'note_introduce', 't': 'introduce', 'c': 1},
      {'uuid': 'note_introduce', 't': ' a new era of transport. Sensors ', 'c': 0},
      {'uuid': 'note_react', 't': 'react', 'c': 1},
      {'uuid': 'note_react', 't': ' instantly to road conditions, making travel safer. This technology will ', 'c': 0},
      {'uuid': 'note_reduce', 't': 'reduce', 'c': 1},
      {'uuid': 'note_reduce', 't': ' accidents significantly.', 'c': 0},
    ]),
  });

  // 日常主题
  await db.insert(kTableTopic, {
    'Topic_ID': 'topic_daily',
    'Topic_Name': '日常词汇',
    'Topic_Name_EN': 'Daily Life',
    'Word_Count': 4,
  });

  // 日常文章：城市生活
  await db.insert(kTableArticle, {
    'Article_ID': 'article_daily_1',
    'Topic_ID': 'topic_daily',
    'Word_Count': 4,
    'Content_JSON': _buildArticleContent([
      {'uuid': 'note_adapt', 't': 'Living in a big city requires you to ', 'c': 0},
      {'uuid': 'note_adapt', 't': 'adapt', 'c': 1},
      {'uuid': 'note_adapt', 't': ' to a fast-paced lifestyle. Every day, people ', 'c': 0},
      {'uuid': 'note_proceed', 't': 'proceed', 'c': 1},
      {'uuid': 'note_proceed', 't': ' to work without hesitation. Sometimes we must ', 'c': 0},
      {'uuid': 'note_decide', 't': 'decide', 'c': 1},
      {'uuid': 'note_decide', 't': ' quickly on important matters.', 'c': 0},
    ]),
  });

  // 日常文章2：团队协作
  await db.insert(kTableArticle, {
    'Article_ID': 'article_daily_2',
    'Topic_ID': 'topic_daily',
    'Word_Count': 3,
    'Content_JSON': _buildArticleContent([
      {'uuid': 'note_adopt', 't': 'Our team decided to ', 'c': 0},
      {'uuid': 'note_adopt', 't': 'adopt', 'c': 1},
      {'uuid': 'note_adopt', 't': ' a new project management tool. It helps us ', 'c': 0},
      {'uuid': 'note_combine', 't': 'combine', 'c': 1},
      {'uuid': 'note_combine', 't': ' our strengths and work more efficiently. When problems arise, we must ', 'c': 0},
      {'uuid': 'note_compete', 't': 'compete', 'c': 1},
      {'uuid': 'note_compete', 't': ' with rival teams to stay ahead.', 'c': 0},
    ]),
  });

  // 词根主题
  await db.insert(kTableTopic, {
    'Topic_ID': 'topic_prefix',
    'Topic_Name': '词根词缀',
    'Topic_Name_EN': 'Roots & Prefixes',
    'Word_Count': 4,
  });

  // 词根文章
  await db.insert(kTableArticle, {
    'Article_ID': 'article_prefix_1',
    'Topic_ID': 'topic_prefix',
    'Word_Count': 4,
    'Content_JSON': _buildArticleContent([
      {'uuid': 'note_accede', 't': 'The prefix "ad-" means "to" or "toward". When attached to a root, it can ', 'c': 0},
      {'uuid': 'note_accede', 't': 'accede', 'c': 1},
      {'uuid': 'note_accede', 't': ' the meaning of approaching. Similarly, "con-" means "with" or "together", and "de-" means "down" or "away". These prefixes help us ', 'c': 0},
      {'uuid': 'note_describe', 't': 'describe', 'c': 1},
      {'uuid': 'note_describe', 't': ' the direction and intensity of actions.', 'c': 0},
    ]),
  });

  // 新增专题：词根词缀
  await db.insert(kTableTopic, {
    'Topic_ID': 'topic_suf',
    'Topic_Name': '词根词缀专题',
    'Topic_Name_EN': 'Roots & Affixes',
    'Word_Count': 50,
  });

  await db.insert(kTableArticle, {
    'Article_ID': 'art_suf_01',
    'Topic_ID': 'topic_suf',
    'Word_Count': 50,
    'Content_JSON': jsonEncode({
      'title': '常用词根精讲：pro/pre/sub',
      'sections': [
        {'heading': 'pro — 向前', 'body': 'pro-表示"向前、为了、代替"...'},
        {'heading': 'pre — 预先', 'body': 'pre-表示"在...之前"...'},
        {'heading': 'sub — 在下', 'body': 'sub-表示"在下面、低于"...'},
      ],
    }),
  });

  await db.insert(kTableArticle, {
    'Article_ID': 'art_suf_02',
    'Topic_ID': 'topic_suf',
    'Word_Count': 40,
    'Content_JSON': jsonEncode({
      'title': '前缀家族：dis/de/re',
      'sections': [
        {'heading': 'dis — 分开/否定', 'body': 'dis-表示"分开、否定"...'},
      ],
    }),
  });

  // 新增专题：语义阅读训练
  await db.insert(kTableTopic, {
    'Topic_ID': 'topic_read',
    'Topic_Name': '语义阅读训练',
    'Topic_Name_EN': 'Semantic Reading',
    'Word_Count': 100,
  });

  await db.insert(kTableArticle, {
    'Article_ID': 'art_read_01',
    'Topic_ID': 'topic_read',
    'Word_Count': 80,
    'Content_JSON': jsonEncode({
      'title': '阅读理解技巧：如何通过词根猜词义',
      'sections': [
        {'heading': '核心思想', 'body': '遇到不认识单词时，分析其词根词缀是高效猜词的技巧...'},
        {'heading': '实例分析', 'body': '例：submarine...'},
      ],
    }),
  });

  await db.insert(kTableArticle, {
    'Article_ID': 'art_read_02',
    'Topic_ID': 'topic_read',
    'Word_Count': 60,
    'Content_JSON': jsonEncode({
      'title': '英语词根故事：ced/gress/duct 三大词根',
      'sections': [
        {'heading': 'ced — 走', 'body': 'cedere 在拉丁语中意为"走"...'},
      ],
    }),
  });
}

String _buildArticleContent(List<Map<String, dynamic>> segments) {
  return jsonEncode(segments);
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
      await _initDefaultSettings(db);
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

/// 写入热库种子数据：新用户首次打开时，为 ROM 中的每个 Note 创建一张对应的 Card
Future<void> seedHotDataIfNeeded(Database hotDb, Database romDb) async {
  print('[DB] seedHotDataIfNeeded 开始');
  final count = Sqflite.firstIntValue(await hotDb.rawQuery('SELECT COUNT(*) FROM Card'));
  print('[DB] seedHotDataIfNeeded 当前Card数量=$count');
  if (count != null && count > 0) {
    print('[DB] seedHotDataIfNeeded 已有数据，跳过');
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
  final randomIds = List.generate(notes.length, (i) => i)..shuffle();
  final batch = hotDb.batch();
  for (int i = 0; i < notes.length; i++) {
    final note = notes[i];
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
        'Random_Sort_ID': randomIds[i],
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }
  print('[DB] seedHotDataIfNeeded 开始批量写入Card...');
  await batch.commit(noResult: true);
  print('[DB] seedHotDataIfNeeded 完成');
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

  NoteModel({
    required this.conceptUuid,
    required this.spelling,
    required this.phonetic,
    required this.definition,
    this.etymologyJson,
    required this.microContextJson,
    required this.contentJson,
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
    );
  }
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
// ROM 数据查询（Tree 相关）
// ============================================================================

class TreeRootModel {
  final String rootId;
  final String rootName;
  final String rootDefinition;
  final String rootGroup;

  TreeRootModel({
    required this.rootId,
    required this.rootName,
    required this.rootDefinition,
    required this.rootGroup,
  });

  factory TreeRootModel.fromMap(Map<String, dynamic> map) {
    return TreeRootModel(
      rootId: map['Root_ID'] as String,
      rootName: map['Root_Name'] as String,
      rootDefinition: map['Root_Definition'] as String,
      rootGroup: map['Root_Group'] as String,
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
  final int treeWordId;
  final String rootId;
  final String conceptUuid;
  final String compoundForm;
  final String compoundMeaning;
  final String finalMeaning;
  final int sortOrder;

  TreeWordModel({
    required this.treeWordId,
    required this.rootId,
    required this.conceptUuid,
    required this.compoundForm,
    required this.compoundMeaning,
    required this.finalMeaning,
    required this.sortOrder,
  });

  factory TreeWordModel.fromMap(Map<String, dynamic> map) {
    return TreeWordModel(
      treeWordId: map['Tree_Word_ID'] as int,
      rootId: map['Root_ID'] as String,
      conceptUuid: map['Concept_UUID'] as String,
      compoundForm: map['Compound_Form'] as String,
      compoundMeaning: map['Compound_Meaning'] as String,
      finalMeaning: map['Final_Meaning'] as String,
      sortOrder: map['Sort_Order'] as int,
    );
  }

  /// 渲染字符串 = {单词}={词根组合形式}={组合含义}={最终中文释义}
  String get renderString =>
      '$compoundForm=$compoundMeaning=$finalMeaning';
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

    // 导入 Card
    final cards = data['cards'] as List<dynamic>? ?? [];
    for (final card in cards) {
      final map = Map<String, dynamic>.from(card as Map);
      final uuid = map['Concept_UUID'] as String;
      // 检查 UUID 是否存在于 ROM 库（通过查询 HotDB 中是否有该 UUID）
      // 如果不存在则跳过
      final exists = await hotDb.query(
        kTableCard,
        where: 'Concept_UUID = ?',
        whereArgs: [uuid],
        limit: 1,
      );
      if (exists.isNotEmpty) {
        // 存在则 UPDATE
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
