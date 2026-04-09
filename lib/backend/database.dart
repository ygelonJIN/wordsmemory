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

/// 确保 ROM 数据完整性。如果 Note 表为空则重新写入示例数据
///
/// 注意：如果需要加载 ECDICT 预生成数据库：
/// 1. 将 ECDICT 转换工具输出的 wordmemory_rom.db 复制到应用私有目录
/// 2. 该文件已有数据，不会触发此处补种逻辑
/// 3. 如果 ROM 文件存在但 Note 表为空，说明是新数据库，也会触发补种
Future<void> _ensureRomDataIntegrity(Database db) async {
  print('[DB] _ensureRomDataIntegrity 开始');
  final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM Note'));
  print('[DB] _ensureRomDataIntegrity Note数量=$count');
  if (count == null || count == 0) {
    print('[DB] _ensureRomDataIntegrity Note为空，开始补种示例数据...');
    await _seedRomData(db);
    print('[DB] _ensureRomDataIntegrity 补种完成');
  } else {
    print('[DB] _ensureRomDataIntegrity ROM已有 ${count} 条词汇，使用预生成数据或已有数据');
  }
  print('[DB] _ensureRomDataIntegrity 结束');
}

/// 公共导出版本，供 provider.dart 调用
Future<void> ensureRomDataIntegrity(Database db) => _ensureRomDataIntegrity(db);

// ============================================================================
// ROM 示例数据初始化
// ============================================================================

Future<void> _seedRomData(Database db) async {
  // 先清空旧的结构树和文章数据（保留其他词汇）
  await db.delete(kTableTreeWord);
  await db.delete(kTableTreeRoot);
  await db.delete(kTableArticle);
  await db.delete(kTableTopic);

  // --------------------------------------------------------------------------
  // Note 数据（re/trans 词根系列 + 旧有词，共约 70 个）
  // --------------------------------------------------------------------------
  final notes = <Map<String, dynamic>>[
    // ======================== re- 系列（25个）========================
    {
      'Concept_UUID': 'note_reassure',
      'Spelling': 'reassure',
      'Phonetic': '/ˌriːəˈʃɔː/',
      'Definition': 'v. 使安心；使确信',
      'Etymology_JSON': '{"prefix":"re-=再/重新","root":"assure=使确信","suffix":""}',
      'Micro_Context_JSON': '{"en":"Her smile reassured me.","zh":"她的微笑使我安心。"}',
      'Content_JSON': '{"spelling":"reassure","phonetic":"/ˌriːəˈʃɔː/","definition":"v. 使安心；使确信","etymology":"re-=再+assure=使确信→再次使确信→使安心","example":"Her smile reassured me.","translation":"她的微笑使我安心。"}',
    },
    {
      'Concept_UUID': 'note_recollect',
      'Spelling': 'recollect',
      'Phonetic': '/ˌrekəˈlekt/',
      'Definition': 'v. 回忆起；想起',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"collect=收集","suffix":""}',
      'Micro_Context_JSON': '{"en":"I tried to recollect her name.","zh":"我努力回忆她的名字。"}',
      'Content_JSON': '{"spelling":"recollect","phonetic":"/ˌrekəˈlekt/","definition":"v. 回忆起；想起","etymology":"re-=重新+collect=收集→重新收集→回忆起","example":"I tried to recollect her name.","translation":"我努力回忆她的名字。"}',
    },
    {
      'Concept_UUID': 'note_reconcile',
      'Spelling': 'reconcile',
      'Phonetic': '/ˈrekənsaɪl/',
      'Definition': 'v. 和解；调解；使一致',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"concile=召集/使和好","suffix":""}',
      'Micro_Context_JSON': '{"en":"They finally reconciled after a long dispute.","zh":"经过长时间的争执，他们终于和解了。"}',
      'Content_JSON': '{"spelling":"reconcile","phonetic":"/ˈrekənsaɪl/","definition":"v. 和解；调解；使一致","etymology":"re-=重新+concile=召集→重新召集到一起→和解","example":"They finally reconciled after a long dispute.","translation":"经过长时间的争执，他们终于和解了。"}',
    },
    {
      'Concept_UUID': 'note_reproduce',
      'Spelling': 'reproduce',
      'Phonetic': '/ˌriːprəˈdjuːs/',
      'Definition': 'v. 繁殖；复制；再生',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"produce=生产","suffix":""}',
      'Micro_Context_JSON': '{"en":"The device can reproduce images perfectly.","zh":"这台设备能完美地复制图像。"}',
      'Content_JSON': '{"spelling":"reproduce","phonetic":"/ˌriːprəˈdjuːs/","definition":"v. 繁殖；复制；再生","etymology":"re-=重新+produce=生产→重新生产→繁殖","example":"The device can reproduce images perfectly.","translation":"这台设备能完美地复制图像。"}',
    },
    {
      'Concept_UUID': 'note_request',
      'Spelling': 'request',
      'Phonetic': '/rɪˈkwest/',
      'Definition': 'v. 请求；要求 n. 请求',
      'Etymology_JSON': '{"prefix":"re-=一再","root":"quest=寻求","suffix":""}',
      'Micro_Context_JSON': '{"en":"I made a request for more information.","zh":"我请求更多信息。"}',
      'Content_JSON': '{"spelling":"request","phonetic":"/rɪˈkwest/","definition":"v. 请求；要求 n. 请求","etymology":"re-=一再+quest=寻求→一再寻求→请求","example":"I made a request for more information.","translation":"我请求更多信息。"}',
    },
    {
      'Concept_UUID': 'note_recommend',
      'Spelling': 'recommend',
      'Phonetic': '/ˌrekəˈmend/',
      'Definition': 'v. 推荐；建议',
      'Etymology_JSON': '{"prefix":"re-=再次/一再","root":"commend=称赞/托付","suffix":""}',
      'Micro_Context_JSON': '{"en":"Can you recommend a good restaurant?","zh":"你能推荐一家好餐厅吗？"}',
      'Content_JSON': '{"spelling":"recommend","phonetic":"/ˌrekəˈmend/","definition":"v. 推荐；建议","etymology":"re-=再次+commend=称赞→再次称赞→推荐","example":"Can you recommend a good restaurant?","translation":"你能推荐一家好餐厅吗？"}',
    },
    {
      'Concept_UUID': 'note_recompense',
      'Spelling': 'recompense',
      'Phonetic': '/ˈrekəmpens/',
      'Definition': 'v. 赔偿；补偿 n. 赔偿金',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"compense=称量/补偿","suffix":""}',
      'Micro_Context_JSON': '{"en":"The company offered to recompense the victims.","zh":"公司提出赔偿受害者。"}',
      'Content_JSON': '{"spelling":"recompense","phonetic":"/ˈrekəmpens/","definition":"v. 赔偿；补偿 n. 赔偿金","etymology":"re-=重新+compense=称量→重新称量→重新补偿→赔偿","example":"The company offered to recompense the victims.","translation":"公司提出赔偿受害者。"}',
    },
    {
      'Concept_UUID': 'note_restrain',
      'Spelling': 'restrain',
      'Phonetic': '/rɪˈstreɪn/',
      'Definition': 'v. 抑制；阻止；约束',
      'Etymology_JSON': '{"prefix":"re-=向后","root":"strain=拉紧","suffix":""}',
      'Micro_Context_JSON': '{"en":"The police restrained the crowd.","zh":"警察阻止了人群。"}',
      'Content_JSON': '{"spelling":"restrain","phonetic":"/rɪˈstreɪn/","definition":"v. 抑制；阻止；约束","etymology":"re-=向后+strain=拉紧→往回拉紧→抑制","example":"The police restrained the crowd.","translation":"警察阻止了人群。"}',
    },
    {
      'Concept_UUID': 'note_retail',
      'Spelling': 'retail',
      'Phonetic': '/ˈriːteɪl/',
      'Definition': 'v. 零售 n. 零售 adj. 零售的',
      'Etymology_JSON': '{"prefix":"re-=再次","root":"tail=切割","suffix":""}',
      'Micro_Context_JSON': '{"en":"They retail products at a discount.","zh":"他们以折扣价零售商品。"}',
      'Content_JSON': '{"spelling":"retail","phonetic":"/ˈriːteɪl/","definition":"v. 零售 n. 零售 adj. 零售的","etymology":"re-=再次+tail=切割→再次切割→分割销售→零售","example":"They retail products at a discount.","translation":"他们以折扣价零售商品。"}',
    },
    {
      'Concept_UUID': 'note_revolve',
      'Spelling': 'revolve',
      'Phonetic': '/rɪˈvɒlv/',
      'Definition': 'v. 旋转；环绕；反复思考',
      'Etymology_JSON': '{"prefix":"re-=一再","root":"volve=滚动/转动","suffix":""}',
      'Micro_Context_JSON': '{"en":"The earth revolves around the sun.","zh":"地球绕太阳旋转。"}',
      'Content_JSON': '{"spelling":"revolve","phonetic":"/rɪˈvɒlv/","definition":"v. 旋转；环绕；反复思考","etymology":"re-=一再+volve=滚动→一再滚动→旋转","example":"The earth revolves around the sun.","translation":"地球绕太阳旋转。"}',
    },
    {
      'Concept_UUID': 'note_refresh',
      'Spelling': 'refresh',
      'Phonetic': '/rɪˈfreʃ/',
      'Definition': 'v. 使恢复；使振作；刷新',
      'Etymology_JSON': '{"prefix":"re-=再次","root":"fresh=新鲜的","suffix":""}',
      'Micro_Context_JSON': '{"en":"Press F5 to refresh the page.","zh":"按F5刷新页面。"}',
      'Content_JSON': '{"spelling":"refresh","phonetic":"/rɪˈfreʃ/","definition":"v. 使恢复；使振作；刷新","etymology":"re-=再次+fresh=新鲜的→再次变新鲜→刷新","example":"Press F5 to refresh the page.","translation":"按F5刷新页面。"}',
    },
    {
      'Concept_UUID': 'note_remark',
      'Spelling': 'remark',
      'Phonetic': '/rɪˈmɑːk/',
      'Definition': 'v. 评论；谈论 n. 评论；注意',
      'Etymology_JSON': '{"prefix":"re-=一再","root":"mark=标记","suffix":""}',
      'Micro_Context_JSON': '{"en":"She remarked on his excellent performance.","zh":"她评论了他的出色表现。"}',
      'Content_JSON': '{"spelling":"remark","phonetic":"/rɪˈmɑːk/","definition":"v. 评论；谈论 n. 评论；注意","etymology":"re-=一再+mark=标记→一再标记→加以标注→评论","example":"She remarked on his excellent performance.","translation":"她评论了他的出色表现。"}',
    },
    {
      'Concept_UUID': 'note_remarkable',
      'Spelling': 'remarkable',
      'Phonetic': '/rɪˈmɑːkəbl/',
      'Definition': 'adj. 卓越的；非凡的；值得注意的',
      'Etymology_JSON': '{"prefix":"re-=一再","root":"mark=标记","suffix":"-able=值得...的"}',
      'Micro_Context_JSON': '{"en":"This is a remarkable achievement.","zh":"这是一项非凡的成就。"}',
      'Content_JSON': '{"spelling":"remarkable","phonetic":"/rɪˈmɑːkəbl/","definition":"adj. 卓越的；非凡的；值得注意的","etymology":"re-=一再+mark=标记+-able=值得...的→值得一再标记的→卓越的","example":"This is a remarkable achievement.","translation":"这是一项非凡的成就。"}',
    },
    {
      'Concept_UUID': 'note_recite',
      'Spelling': 'recite',
      'Phonetic': '/rɪˈsaɪt/',
      'Definition': 'v. 背诵；朗读；列举',
      'Etymology_JSON': '{"prefix":"re-=再次","root":"cite=唤起/引用","suffix":""}',
      'Micro_Context_JSON': '{"en":"The student recited the poem fluently.","zh":"学生流利地背诵了这首诗。"}',
      'Content_JSON': '{"spelling":"recite","phonetic":"/rɪˈsaɪt/","definition":"v. 背诵；朗读；列举","etymology":"re-=再次+cite=唤起→再次唤起记忆→背诵","example":"The student recited the poem fluently.","translation":"学生流利地背诵了这首诗。"}',
    },
    {
      'Concept_UUID': 'note_renaissance',
      'Spelling': 'renaissance',
      'Phonetic': '/rɪˈneɪsəns/',
      'Definition': 'n. 文艺复兴；复兴；复活',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"naissance=诞生","suffix":""}',
      'Micro_Context_JSON': '{"en":"The Renaissance transformed European culture.","zh":"文艺复兴改变了欧洲文化。"}',
      'Content_JSON': '{"spelling":"renaissance","phonetic":"/rɪˈneɪsəns/","definition":"n. 文艺复兴；复兴；复活","etymology":"re-=重新+naissance=诞生→重新诞生→文艺复兴","example":"The Renaissance transformed European culture.","translation":"文艺复兴改变了欧洲文化。"}',
    },
    {
      'Concept_UUID': 'note_recount',
      'Spelling': 'recount',
      'Phonetic': '/rɪˈkaʊnt/',
      'Definition': 'v. 重新计算；叙述；讲述',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"count=计算","suffix":""}',
      'Micro_Context_JSON': '{"en":"She recounted her adventures in detail.","zh":"她详细叙述了她的冒险经历。"}',
      'Content_JSON': '{"spelling":"recount","phonetic":"/rɪˈkaʊnt/","definition":"v. 重新计算；叙述；讲述","etymology":"re-=重新+count=计算→重新计算→叙述","example":"She recounted her adventures in detail.","translation":"她详细叙述了她的冒险经历。"}',
    },
    {
      'Concept_UUID': 'note_renovation',
      'Spelling': 'renovation',
      'Phonetic': '/ˌrenəˈveɪʃn/',
      'Definition': 'n. 翻修；革新；装修',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"nov=新","suffix":"-ation=行为/结果"}',
      'Micro_Context_JSON': '{"en":"The house needs renovation.","zh":"这房子需要翻修。"}',
      'Content_JSON': '{"spelling":"renovation","phonetic":"/ˌrenəˈveɪʃn/","definition":"n. 翻修；革新；装修","etymology":"re-=重新+nov=新+-ation=行为→重新造新→翻修","example":"The house needs renovation.","translation":"这房子需要翻修。"}',
    },
    {
      'Concept_UUID': 'note_reinforce',
      'Spelling': 'reinforce',
      'Phonetic': '/ˌriːɪnˈfɔːs/',
      'Definition': 'v. 加强；增援；巩固',
      'Etymology_JSON': '{"prefix":"re-=再次","root":"inforce=enforce=加强","suffix":""}',
      'Micro_Context_JSON': '{"en":"We need to reinforce the walls.","zh":"我们需要加固墙壁。"}',
      'Content_JSON': '{"spelling":"reinforce","phonetic":"/ˌriːɪnˈfɔːs/","definition":"v. 加强；增援；巩固","etymology":"re-=再次+inforce=加强→再次加强→强化","example":"We need to reinforce the walls.","translation":"我们需要加固墙壁。"}',
    },
    {
      'Concept_UUID': 'note_renew',
      'Spelling': 'renew',
      'Phonetic': '/rɪˈnjuː/',
      'Definition': 'v. 更新；续签；使恢复',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"new=新的","suffix":""}',
      'Micro_Context_JSON': '{"en":"Please renew your subscription online.","zh":"请在网上续订您的订阅。"}',
      'Content_JSON': '{"spelling":"renew","phonetic":"/rɪˈnjuː/","definition":"v. 更新；续签；使恢复","etymology":"re-=重新+new=新的→重新变新→更新","example":"Please renew your subscription online.","translation":"请在网上续订您的订阅。"}',
    },
    {
      'Concept_UUID': 'note_require',
      'Spelling': 'require',
      'Phonetic': '/rɪˈkwaɪə/',
      'Definition': 'v. 需要；要求；命令',
      'Etymology_JSON': '{"prefix":"re-=一再","root":"quire=寻求/询问","suffix":""}',
      'Micro_Context_JSON': '{"en":"The job requires experience.","zh":"这份工作需要经验。"}',
      'Content_JSON': '{"spelling":"require","phonetic":"/rɪˈkwaɪə/","definition":"v. 需要；要求；命令","etymology":"re-=一再+quire=寻求→一再寻求→需要","example":"The job requires experience.","translation":"这份工作需要经验。"}',
    },
    {
      'Concept_UUID': 'note_replace',
      'Spelling': 'replace',
      'Phonetic': '/rɪˈpleɪs/',
      'Definition': 'v. 替换；取代；把...放回原处',
      'Etymology_JSON': '{"prefix":"re-=重新","root":"place=放置","suffix":""}',
      'Micro_Context_JSON': '{"en":"Can you replace the broken light bulb?","zh":"你能换掉烧坏的灯泡吗？"}',
      'Content_JSON': '{"spelling":"replace","phonetic":"/rɪˈpleɪs/","definition":"v. 替换；取代；把...放回原处","etymology":"re-=重新+place=放置→重新放置→替换","example":"Can you replace the broken light bulb?","translation":"你能换掉烧坏的灯泡吗？"}',
    },
    {
      'Concept_UUID': 'note_register',
      'Spelling': 'register',
      'Phonetic': '/ˈredʒɪstə/',
      'Definition': 'v. 登记；注册；记录 n. 登记表',
      'Etymology_JSON': '{"prefix":"re-=带回","root":"gister=带来/记录","suffix":""}',
      'Micro_Context_JSON': '{"en":"Please register for the course online.","zh":"请在网上注册这门课程。"}',
      'Content_JSON': '{"spelling":"register","phonetic":"/ˈredʒɪstə/","definition":"v. 登记；注册；记录 n. 登记表","etymology":"re-=带回+gister=带来→带回来记录→登记","example":"Please register for the course online.","translation":"请在网上注册这门课程。"}',
    },
    {
      'Concept_UUID': 'note_resemble',
      'Spelling': 'resemble',
      'Phonetic': '/rɪˈzembl/',
      'Definition': 'v. 类似；像；相似',
      'Etymology_JSON': '{"prefix":"re-=再次","root":"semble=相似","suffix":""}',
      'Micro_Context_JSON': '{"en":"She resembles her mother closely.","zh":"她很像她的母亲。"}',
      'Content_JSON': '{"spelling":"resemble","phonetic":"/rɪˈzembl/","definition":"v. 类似；像；相似","etymology":"re-=再次+semble=相似→再次相似→类似","example":"She resembles her mother closely.","translation":"她很像她的母亲。"}',
    },
    {
      'Concept_UUID': 'note_resemblance',
      'Spelling': 'resemblance',
      'Phonetic': '/rɪˈzembləns/',
      'Definition': 'n. 相似；相似之处；相像程度',
      'Etymology_JSON': '{"prefix":"re-=再次","root":"semblance=相似的样子","suffix":""}',
      'Micro_Context_JSON': '{"en":"There is a strong resemblance between them.","zh":"他们之间有很强的相似之处。"}',
      'Content_JSON': '{"spelling":"resemblance","phonetic":"/rɪˈzembləns/","definition":"n. 相似；相似之处；相像程度","etymology":"re-=再次+semblance=相似的样子→再次相似的状态→相似之处","example":"There is a strong resemblance between them.","translation":"他们之间有很强的相似之处。"}',
    },
    {
      'Concept_UUID': 'note_remain',
      'Spelling': 'remain',
      'Phonetic': '/rɪˈmeɪn/',
      'Definition': 'v. 保持；留下；剩余',
      'Etymology_JSON': '{"prefix":"re-=向后","root":"main=停留（=manere）","suffix":""}',
      'Micro_Context_JSON': '{"en":"Please remain seated until the bus stops.","zh":"请在公共汽车停下之前保持坐着。"}',
      'Content_JSON': '{"spelling":"remain","phonetic":"/rɪˈmeɪn/","definition":"v. 保持；留下；剩余","etymology":"re-=向后+main=停留→向后停留→保持","example":"Please remain seated until the bus stops.","translation":"请在公共汽车停下之前保持坐着。"}',
    },
    {
      'Concept_UUID': 'note_restrict',
      'Spelling': 'restrict',
      'Phonetic': '/rɪˈstrɪkt/',
      'Definition': 'v. 限制；约束；限定',
      'Etymology_JSON': '{"prefix":"re-=往回","root":"strict=拉紧/严格","suffix":""}',
      'Micro_Context_JSON': '{"en":"Speed is restricted to 60 km/h here.","zh":"这里限速60公里/小时。"}',
      'Content_JSON': '{"spelling":"restrict","phonetic":"/rɪˈstrɪkt/","definition":"v. 限制；约束；限定","etymology":"re-=往回+strict=拉紧→往回拉紧→限制","example":"Speed is restricted to 60 km/h here.","translation":"这里限速60公里/小时。"}',
    },
    // ======================== trans- 系列（15个）========================
    {
      'Concept_UUID': 'note_transfer',
      'Spelling': 'transfer',
      'Phonetic': '/trænsˈfɜː/',
      'Definition': 'v. 转移；转学；转让 n. 转移；转让',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"fer=携带/搬运","suffix":""}',
      'Micro_Context_JSON': '{"en":"Please transfer the files to the server.","zh":"请把文件转移到服务器上。"}',
      'Content_JSON': '{"spelling":"transfer","phonetic":"/trænsˈfɜː/","definition":"v. 转移；转学；转让 n. 转移；转让","etymology":"trans-=跨越+fer=携带→跨越携带→转移","example":"Please transfer the files to the server.","translation":"请把文件转移到服务器上。"}',
    },
    {
      'Concept_UUID': 'note_translate',
      'Spelling': 'translate',
      'Phonetic': '/trænzˈleɪt/',
      'Definition': 'v. 翻译；转化；解释',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"late=搬运/携带（lat=携带）","suffix":""}',
      'Micro_Context_JSON': '{"en":"Can you translate this sentence into English?","zh":"你能把这句话翻译成英语吗？"}',
      'Content_JSON': '{"spelling":"translate","phonetic":"/trænzˈleɪt/","definition":"v. 翻译；转化；解释","etymology":"trans-=跨越+late=搬运→跨越搬运→翻译","example":"Can you translate this sentence into English?","translation":"你能把这句话翻译成英语吗？"}',
    },
    {
      'Concept_UUID': 'note_transmit',
      'Spelling': 'transmit',
      'Phonetic': '/trænzˈmɪt/',
      'Definition': 'v. 传输；发送；传播；传达',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"mit=发送（=mittere）","suffix":""}',
      'Micro_Context_JSON': '{"en":"The station transmits news around the world.","zh":"电台向全世界发送新闻。"}',
      'Content_JSON': '{"spelling":"transmit","phonetic":"/trænzˈmɪt/","definition":"v. 传输；发送；传播；传达","etymology":"trans-=跨越+mit=发送→跨越发送→传输","example":"The station transmits news around the world.","translation":"电台向全世界发送新闻。"}',
    },
    {
      'Concept_UUID': 'note_transport',
      'Spelling': 'transport',
      'Phonetic': '/trænzˈpɔːt/',
      'Definition': 'v. 运输；运送 n. 运输；运输工具',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"port=搬运/携带","suffix":""}',
      'Micro_Context_JSON': '{"en":"Trucks transport goods across the country.","zh":"卡车将货物运往全国各地。"}',
      'Content_JSON': '{"spelling":"transport","phonetic":"/trænzˈpɔːt/","definition":"v. 运输；运送 n. 运输；运输工具","etymology":"trans-=跨越+port=搬运→跨越搬运→运输","example":"Trucks transport goods across the country.","translation":"卡车将货物运往全国各地。"}',
    },
    {
      'Concept_UUID': 'note_transform',
      'Spelling': 'transform',
      'Phonetic': '/trænzˈfɔːm/',
      'Definition': 'v. 改变；改造；使变形',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"form=形状/形态","suffix":""}',
      'Micro_Context_JSON': '{"en":"The city has been transformed over the years.","zh":"这座城市在这些年里发生了巨大的变化。"}',
      'Content_JSON': '{"spelling":"transform","phonetic":"/trænzˈfɔːm/","definition":"v. 改变；改造；使变形","etymology":"trans-=跨越+form=形状→跨越改变形状→变形","example":"The city has been transformed over the years.","translation":"这座城市在这些年里发生了巨大的变化。"}',
    },
    {
      'Concept_UUID': 'note_transparent',
      'Spelling': 'transparent',
      'Phonetic': '/trænsˈpærənt/',
      'Definition': 'adj. 透明的；显然的；易觉察的',
      'Etymology_JSON': '{"prefix":"trans-=穿透","root":"parent=显现/出现（parere）","suffix":""}',
      'Micro_Context_JSON': '{"en":"Glass is transparent.","zh":"玻璃是透明的。"}',
      'Content_JSON': '{"spelling":"transparent","phonetic":"/trænsˈpærənt/","definition":"adj. 透明的；显然的；易觉察的","etymology":"trans-=穿透+parent=显现→穿透显现→透明的","example":"Glass is transparent.","translation":"玻璃是透明的。"}',
    },
    {
      'Concept_UUID': 'note_transplant',
      'Spelling': 'transplant',
      'Phonetic': '/trænsˈplɑːnt/',
      'Definition': 'v. 移植；迁移 n. 移植；器官移植',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"plant=种植","suffix":""}',
      'Micro_Context_JSON': '{"en":"The surgeon will transplant the kidney tomorrow.","zh":"外科医生明天将进行肾脏移植手术。"}',
      'Content_JSON': '{"spelling":"transplant","phonetic":"/trænsˈplɑːnt/","definition":"v. 移植；迁移 n. 移植；器官移植","etymology":"trans-=跨越+plant=种植→跨越种植→移植","example":"The surgeon will transplant the kidney tomorrow.","translation":"外科医生明天将进行肾脏移植手术。"}',
    },
    {
      'Concept_UUID': 'note_transaction',
      'Spelling': 'transaction',
      'Phonetic': '/trænˈzækʃn/',
      'Definition': 'n. 交易；业务；办理',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"action=行为/行动","suffix":""}',
      'Micro_Context_JSON': '{"en":"All transactions are recorded in the system.","zh":"所有交易都在系统中记录。"}',
      'Content_JSON': '{"spelling":"transaction","phonetic":"/trænˈzækʃn/","definition":"n. 交易；业务；办理","etymology":"trans-=跨越+action=行为→跨越性行为→交易","example":"All transactions are recorded in the system.","translation":"所有交易都在系统中记录。"}',
    },
    {
      'Concept_UUID': 'note_transcend',
      'Spelling': 'transcend',
      'Phonetic': '/trænˈsend/',
      'Definition': 'v. 超越；胜过；超出...的范围',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"scend=攀爬/上升（scandere）","suffix":""}',
      'Micro_Context_JSON': '{"en":"The movie transcends the typical Hollywood formula.","zh":"这部电影超越了典型的好莱坞套路。"}',
      'Content_JSON': '{"spelling":"transcend","phonetic":"/trænˈsend/","definition":"v. 超越；胜过；超出...的范围","etymology":"trans-=跨越+scend=攀爬→跨越攀爬→超越","example":"The movie transcends the typical Hollywood formula.","translation":"这部电影超越了典型的好莱坞套路。"}',
    },
    {
      'Concept_UUID': 'note_transfuse',
      'Spelling': 'transfuse',
      'Phonetic': '/trænsˈfjuːz/',
      'Definition': 'v. 输注；灌输；渗透',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"fuse=倾倒/注入","suffix":""}',
      'Micro_Context_JSON': '{"en":"The doctor transfused blood into the patient.","zh":"医生给病人输了血。"}',
      'Content_JSON': '{"spelling":"transfuse","phonetic":"/trænsˈfjuːz/","definition":"v. 输注；灌输；渗透","etymology":"trans-=跨越+fuse=倾倒→跨越倾倒→输注","example":"The doctor transfused blood into the patient.","translation":"医生给病人输了血。"}',
    },
    {
      'Concept_UUID': 'note_transition',
      'Spelling': 'transition',
      'Phonetic': '/trænˈzɪʃn/',
      'Definition': 'n. 过渡；转变；变迁 v. 转变；过渡',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"it=走（ire）","suffix":"-ion=行为/状态"}',
      'Micro_Context_JSON': '{"en":"The country is in transition to democracy.","zh":"该国正在向民主过渡。"}',
      'Content_JSON': '{"spelling":"transition","phonetic":"/trænˈzɪʃn/","definition":"n. 过渡；转变；变迁 v. 转变；过渡","etymology":"trans-=跨越+it=走+-ion=状态→跨越行走的状态→过渡","example":"The country is in transition to democracy.","translation":"该国正在向民主过渡。"}',
    },
    {
      'Concept_UUID': 'note_transgress',
      'Spelling': 'transgress',
      'Phonetic': '/trænzˈɡres/',
      'Definition': 'v. 越界；违背；违反（规则、法律等）',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"gress=迈步/行走","suffix":""}',
      'Micro_Context_JSON': '{"en":"No one should transgress the law.","zh":"任何人都不能违法。"}',
      'Content_JSON': '{"spelling":"transgress","phonetic":"/trænzˈɡres/","definition":"v. 越界；违背；违反（规则、法律等）","etymology":"trans-=跨越+gress=迈步→跨越界限迈步→越界","example":"No one should transgress the law.","translation":"任何人都不能违法。"}',
    },
    {
      'Concept_UUID': 'note_translucent',
      'Spelling': 'translucent',
      'Phonetic': '/trænzˈluːsnt/',
      'Definition': 'adj. 半透明的；透光的',
      'Etymology_JSON': '{"prefix":"trans-=穿透","root":"lucent=发光/明亮（lucere）","suffix":""}',
      'Micro_Context_JSON': '{"en":"The lampshade is made of translucent glass.","zh":"灯罩是用半透明玻璃制成的。"}',
      'Content_JSON': '{"spelling":"translucent","phonetic":"/trænzˈluːsnt/","definition":"adj. 半透明的；透光的","etymology":"trans-=穿透+lucent=发光→穿透发光→半透明的","example":"The lampshade is made of translucent glass.","translation":"灯罩是用半透明玻璃制成的。"}',
    },
    {
      'Concept_UUID': 'note_transcribe',
      'Spelling': 'transcribe',
      'Phonetic': '/trænˈskraɪb/',
      'Definition': 'v. 转录；抄写；改编',
      'Etymology_JSON': '{"prefix":"trans-=跨越","root":"scribe=写","suffix":""}',
      'Micro_Context_JSON': '{"en":"Please transcribe the interview recording.","zh":"请转录采访录音。"}',
      'Content_JSON': '{"spelling":"transcribe","phonetic":"/trænˈskraɪb/","definition":"v. 转录；抄写；改编","etymology":"trans-=跨越+scribe=写→跨越写下→转录","example":"Please transcribe the interview recording.","translation":"请转录采访录音。"}',
    },
    {
      'Concept_UUID': 'note_transit',
      'Spelling': 'transit',
      'Phonetic': '/ˈtrænzɪt/',
      'Definition': 'n. 运输；通行；交通运输 v. 通过；穿越',
      'Etymology_JSON': '{"prefix":"trans-=穿过","root":"it=走（ire）","suffix":""}',
      'Micro_Context_JSON': '{"en":"The goods are in transit.","zh":"货物正在运输中。"}',
      'Content_JSON': '{"spelling":"transit","phonetic":"/ˈtrænzɪt/","definition":"n. 运输；通行；交通运输 v. 通过；穿越","etymology":"trans-=穿过+it=走→穿过走→通行","example":"The goods are in transit.","translation":"货物正在运输中。"}',
    },
  ];

  for (final note in notes) {
    await db.insert(kTableNote, note);
  }

  // --------------------------------------------------------------------------
  // Tree_Root 数据（2个词根）
  // --------------------------------------------------------------------------
  final treeRoots = [
    {'Root_ID': 'root_re', 'Root_Name': 're', 'Root_Definition': '再、重新、向后', 'Root_Group': 'R'},
    {'Root_ID': 'root_trans', 'Root_Name': 'trans', 'Root_Definition': '横跨、穿过、跨越', 'Root_Group': 'T'},
  ];

  for (final root in treeRoots) {
    await db.insert(kTableTreeRoot, root);
  }

  // --------------------------------------------------------------------------
  // Tree_Word 数据（re 和 trans 派生词，严格按用户格式）
  // --------------------------------------------------------------------------
  final treeWords = <Map<String, dynamic>>[
    // re 词根（25个派生词）
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_reassure', 'Compound_Form': 're+assure', 'Compound_Meaning': '再次使确信', 'Final_Meaning': '使安心', 'Sort_Order': 1},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_recollect', 'Compound_Form': 're+collect', 'Compound_Meaning': '重新收集', 'Final_Meaning': '回忆起', 'Sort_Order': 2},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_reconcile', 'Compound_Form': 're+concile', 'Compound_Meaning': '重新协调', 'Final_Meaning': '和解', 'Sort_Order': 3},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_reproduce', 'Compound_Form': 're+produce', 'Compound_Meaning': '重新生产', 'Final_Meaning': '繁殖', 'Sort_Order': 4},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_request', 'Compound_Form': 're+quest', 'Compound_Meaning': '一再寻求', 'Final_Meaning': '请求', 'Sort_Order': 5},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_recommend', 'Compound_Form': 're+commend', 'Compound_Meaning': '再次赞赏', 'Final_Meaning': '推荐', 'Sort_Order': 6},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_recompense', 'Compound_Form': 're+compense', 'Compound_Meaning': '重新补偿', 'Final_Meaning': '赔偿', 'Sort_Order': 7},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_restrain', 'Compound_Form': 're+strain', 'Compound_Meaning': '向后拉紧', 'Final_Meaning': '抑制', 'Sort_Order': 8},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_retail', 'Compound_Form': 're+tail', 'Compound_Meaning': '再次切割', 'Final_Meaning': '零售', 'Sort_Order': 9},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_revolve', 'Compound_Form': 're+volve', 'Compound_Meaning': '一再滚动', 'Final_Meaning': '旋转', 'Sort_Order': 10},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_refresh', 'Compound_Form': 're+fresh', 'Compound_Meaning': '再次新鲜', 'Final_Meaning': '刷新', 'Sort_Order': 11},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_remark', 'Compound_Form': 're+mark', 'Compound_Meaning': '一再标记', 'Final_Meaning': '评论', 'Sort_Order': 12},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_remarkable', 'Compound_Form': 're+mark+able', 'Compound_Meaning': '值得一再标记的', 'Final_Meaning': '卓越的', 'Sort_Order': 13},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_recite', 'Compound_Form': 're+cite', 'Compound_Meaning': '再次唤起', 'Final_Meaning': '背诵', 'Sort_Order': 14},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_renaissance', 'Compound_Form': 're+naissance', 'Compound_Meaning': '重新诞生', 'Final_Meaning': '文艺复兴', 'Sort_Order': 15},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_recount', 'Compound_Form': 're+count', 'Compound_Meaning': '重新计算', 'Final_Meaning': '叙述', 'Sort_Order': 16},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_renovation', 'Compound_Form': 're+nov+ation', 'Compound_Meaning': '重新造新', 'Final_Meaning': '翻修', 'Sort_Order': 17},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_reinforce', 'Compound_Form': 're+inforce', 'Compound_Meaning': '再次加强', 'Final_Meaning': '强化', 'Sort_Order': 18},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_renew', 'Compound_Form': 're+new', 'Compound_Meaning': '重新变新', 'Final_Meaning': '更新', 'Sort_Order': 19},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_require', 'Compound_Form': 're+quire', 'Compound_Meaning': '一再寻求', 'Final_Meaning': '需要', 'Sort_Order': 20},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_replace', 'Compound_Form': 're+place', 'Compound_Meaning': '重新放置', 'Final_Meaning': '替换', 'Sort_Order': 21},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_register', 'Compound_Form': 're+gister', 'Compound_Meaning': '带回记录', 'Final_Meaning': '登记', 'Sort_Order': 22},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_resemble', 'Compound_Form': 're+semble', 'Compound_Meaning': '再次相似', 'Final_Meaning': '类似', 'Sort_Order': 23},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_resemblance', 'Compound_Form': 're+semblance', 'Compound_Meaning': '再次相似的状态', 'Final_Meaning': '相似之处', 'Sort_Order': 24},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_remain', 'Compound_Form': 're+main', 'Compound_Meaning': '向后停留', 'Final_Meaning': '保持', 'Sort_Order': 25},
    {'Root_ID': 'root_re', 'Concept_UUID': 'note_restrict', 'Compound_Form': 're+strict', 'Compound_Meaning': '往回拉紧', 'Final_Meaning': '限制', 'Sort_Order': 26},
    // trans 词根（15个派生词）
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transfer', 'Compound_Form': 'trans+fer', 'Compound_Meaning': '跨越携带', 'Final_Meaning': '转移', 'Sort_Order': 1},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_translate', 'Compound_Form': 'trans+late', 'Compound_Meaning': '跨越搬运', 'Final_Meaning': '翻译', 'Sort_Order': 2},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transmit', 'Compound_Form': 'trans+mit', 'Compound_Meaning': '跨越发送', 'Final_Meaning': '传输', 'Sort_Order': 3},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transport', 'Compound_Form': 'trans+port', 'Compound_Meaning': '跨越搬运', 'Final_Meaning': '运输', 'Sort_Order': 4},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transform', 'Compound_Form': 'trans+form', 'Compound_Meaning': '跨越改变形状', 'Final_Meaning': '变形', 'Sort_Order': 5},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transparent', 'Compound_Form': 'trans+parent', 'Compound_Meaning': '穿透显现', 'Final_Meaning': '透明的', 'Sort_Order': 6},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transplant', 'Compound_Form': 'trans+plant', 'Compound_Meaning': '跨越种植', 'Final_Meaning': '移植', 'Sort_Order': 7},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transaction', 'Compound_Form': 'trans+action', 'Compound_Meaning': '跨越交互行动', 'Final_Meaning': '交易', 'Sort_Order': 8},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transcend', 'Compound_Form': 'trans+scend', 'Compound_Meaning': '跨越攀爬', 'Final_Meaning': '超越', 'Sort_Order': 9},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transfuse', 'Compound_Form': 'trans+fuse', 'Compound_Meaning': '跨越倾倒', 'Final_Meaning': '输注', 'Sort_Order': 10},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transition', 'Compound_Form': 'trans+it+ion', 'Compound_Meaning': '跨越行走的状态', 'Final_Meaning': '过渡', 'Sort_Order': 11},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transgress', 'Compound_Form': 'trans+gress', 'Compound_Meaning': '跨越界限迈步', 'Final_Meaning': '越界', 'Sort_Order': 12},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_translucent', 'Compound_Form': 'trans+lucent', 'Compound_Meaning': '穿透发光', 'Final_Meaning': '半透明的', 'Sort_Order': 13},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transcribe', 'Compound_Form': 'trans+scribe', 'Compound_Meaning': '跨越写下', 'Final_Meaning': '转录', 'Sort_Order': 14},
    {'Root_ID': 'root_trans', 'Concept_UUID': 'note_transit', 'Compound_Form': 'trans+it', 'Compound_Meaning': '穿过走', 'Final_Meaning': '通行', 'Sort_Order': 15},
  ];

  for (final word in treeWords) {
    await db.insert(kTableTreeWord, word);
  }

  // --------------------------------------------------------------------------
  // Topic & Article 数据（仅保留科技阅读专题，语义阅读训练已移除）
  // 科技阅读专题通过 _seedSemanticReadingData 和 _ensureSemanticReadingDataSeeded 函数管理
}

// --------------------------------------------------------------------------
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
  final books = [
    {
      'Book_ID': 'cet4',
      'Book_Name': 'CET-4',
      'Book_Name_EN': 'College English Test Band 4',
      'Word_Count': 3000,
      'Tag_List': 'zk cet4',
      'Description': '大学英语四级词汇',
      'Sort_Order': 1,
      'Is_Default': 1,
    },
    {
      'Book_ID': 'cet6',
      'Book_Name': 'CET-6',
      'Book_Name_EN': 'College English Test Band 6',
      'Word_Count': 2500,
      'Tag_List': 'cet6',
      'Description': '大学英语六级词汇',
      'Sort_Order': 2,
      'Is_Default': 1,
    },
    {
      'Book_ID': 'kaoyan',
      'Book_Name': '考研',
      'Book_Name_EN': 'Graduate Entrance Exam',
      'Word_Count': 5500,
      'Tag_List': 'ky zk cet4 cet6',
      'Description': '考研英语词汇（含四六级核心词）',
      'Sort_Order': 3,
      'Is_Default': 1,
    },
    {
      'Book_ID': 'toefl',
      'Book_Name': 'TOEFL',
      'Book_Name_EN': 'Test of English as a Foreign Language',
      'Word_Count': 8000,
      'Tag_List': 'toefl',
      'Description': '托福学术英语词汇',
      'Sort_Order': 4,
      'Is_Default': 0,
    },
    {
      'Book_ID': 'ielts',
      'Book_Name': 'IELTS',
      'Book_Name_EN': 'International English Language Testing System',
      'Word_Count': 6000,
      'Tag_List': 'ielts',
      'Description': '雅思学术英语词汇',
      'Sort_Order': 5,
      'Is_Default': 0,
    },
    {
      'Book_ID': 'gre',
      'Book_Name': 'GRE',
      'Book_Name_EN': 'Graduate Record Examination',
      'Word_Count': 10000,
      'Tag_List': 'gre',
      'Description': 'GRE 学术类研究生入学考试词汇',
      'Sort_Order': 6,
      'Is_Default': 0,
    },
    {
      'Book_ID': 'kaoyan2027',
      'Book_Name': '2027考研',
      'Book_Name_EN': '2027 Graduate Entrance Exam',
      'Word_Count': 6000,
      'Tag_List': 'ky zk cet4 cet6',
      'Description': '2027届考研英语词汇',
      'Sort_Order': 0,
      'Is_Default': 1,
    },
  ];

  final batch = db.batch();
  for (final book in books) {
    batch.insert('WordBook', book, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await batch.commit(noResult: true);
  print('[DB] _seedWordBooks 完成，已写入 ${books.length} 个词书');
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
