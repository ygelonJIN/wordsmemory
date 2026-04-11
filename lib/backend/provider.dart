library wordmemory.backend;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'fsrs.dart';
import 'study.dart';
import 'tts_service.dart';

export 'database.dart';
export 'fsrs.dart';
export 'study.dart';

/// 音标：统一为 `/内容/`，避免数据库已带斜杠时出现 `//`
String formatPhoneticForDisplay(String phonetic) {
  var p = phonetic.trim();
  while (p.startsWith('/')) {
    p = p.substring(1);
  }
  while (p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  p = p.trim();
  if (p.isEmpty) return '/ /';
  return '/$p/';
}

/// 词根词缀 JSON → 可读文本
String formatEtymologyForDisplay(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  try {
    final dynamic d = jsonDecode(s);
    if (d is Map) {
      final prefix = d['prefix']?.toString() ?? '';
      final root = d['root']?.toString() ?? '';
      final suffix = d['suffix']?.toString() ?? '';
      final parts = <String>[];
      if (prefix.isNotEmpty) parts.add('前缀：$prefix');
      if (root.isNotEmpty) parts.add('词根：$root');
      if (suffix.isNotEmpty) parts.add('后缀：$suffix');
      if (parts.isNotEmpty) return parts.join('\n');
    }
  } catch (e) {
    // JSON 解析失败时静默返回原始字符串，便于调试时可开启日志
    // print('[Backend] formatEtymologyForDisplay 解析失败: $e');
  }
  return s;
}

/// 例句 microContext JSON → 可读文本
String formatMicroContextForDisplay(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  try {
    final dynamic d = jsonDecode(s);
    if (d is Map) {
      final en = d['en']?.toString() ?? '';
      final zh = d['zh']?.toString() ?? '';
      if (en.isNotEmpty && zh.isNotEmpty) return '$en\n$zh';
      if (en.isNotEmpty) return en;
      if (zh.isNotEmpty) return zh;
    }
  } catch (e) {
    // JSON 解析失败时静默返回原始字符串，便于调试时可开启日志
    // print('[Backend] formatMicroContextForDisplay 解析失败: $e');
  }
  return s;
}

String _formatPct(double v) {
  if (v == v.roundToDouble()) return '${v.round()}%';
  return '${v.toStringAsFixed(1)}%';
}

// ============================================================================
// 全局实例（单例模式）
// ============================================================================

/// 全局数据库管理器
class BackendManager {
  static BackendManager? _instance;
  static BackendManager get instance => _instance ??= BackendManager._();

  BackendManager._();

  Database? _romDb;
  Database? _hotDb;
  StudySessionManager? _studyManager;
  QuickScreenManager? _quickScreenManager;
  TreeManager? _treeManager;
  TopicReadingManager? _topicManager;

  TreeManager get treeManager => _treeManager!;
  TopicReadingManager get topicManager => _topicManager!;

  final _loadingStatusController = StreamController<LoadingStatus>.broadcast();

  Stream<LoadingStatus> get loadingStatusStream => _loadingStatusController.stream;

  bool get isInitialized => _romDb != null && _hotDb != null;

  /// 应用启动时调用（对应 LoadingPage）
  /// 通过 loadingStatusStream 推送各阶段状态
  Future<void> initialize() async {
    print('[Backend] initialize() 被调用, 已初始化=$isInitialized');
    if (isInitialized) {
      print('[Backend] initialize: 已初始化，跳过');
      return;
    }

    _loadingStatusController.add(LoadingStatus(
      text: '正在初始化存储路径...',
      progress: 0.0,
      isDone: false,
    ));

    // Web：path_provider 的 getApplicationDocumentsDirectory 常出现 MissingPluginException
    final String dbDir;
    if (kIsWeb) {
      dbDir = '';
      print('[Backend] Web环境，dbDir=""');
    } else {
      print('[Backend] 非Web，获取应用文档目录...');
      final appDir = await getApplicationDocumentsDirectory();
      dbDir = appDir.path;
      print('[Backend] dbDir=$dbDir');
    }

    _loadingStatusController.add(LoadingStatus(
      text: '正在打开ROM数据库...',
      progress: 0.2,
      isDone: false,
    ));
    print('[Backend] 准备打开ROM数据库, dbDir=$dbDir');
    try {
      print('[Backend] 调用 openRomDatabase...');
      _romDb = await openRomDatabase(dbDir);
      print('[Backend] ROM数据库已打开');
    } catch (e) {
      print('[Backend] ROM数据库打开失败（继续尝试）: $e');
    }

    _loadingStatusController.add(LoadingStatus(
      text: '正在打开热数据库...',
      progress: 0.4,
      isDone: false,
    ));
    print('[Backend] 准备打开Hot数据库');
    try {
      print('[Backend] 调用 openHotDatabase...');
      _hotDb = await openHotDatabase(dbDir);
      print('[Backend] Hot数据库已打开');
    } catch (e) {
      print('[Backend] Hot数据库打开失败（继续尝试）: $e');
    }

    // 初始化 TTS 发音服务（SRS&SDD v2.1 第 7.1 节）
    print('[Backend] 初始化TTS发音服务...');
    try {
      await TTSService.instance.initialize();
      print('[Backend] TTS初始化完成: ${TTSService.instance.isAvailable}');
    } catch (e) {
      print('[Backend] TTS初始化失败（继续）: $e');
    }

    _loadingStatusController.add(LoadingStatus(
      text: '正在初始化学习会话...',
      progress: 0.6,
      isDone: false,
    ));
    try {
      if (_hotDb != null && _romDb != null) {
        _studyManager = StudySessionManager(hotDb: _hotDb!, romDb: _romDb!);
        _quickScreenManager = QuickScreenManager(hotDb: _hotDb!, romDb: _romDb!);
        _treeManager = TreeManager(hotDb: _hotDb!, romDb: _romDb!);
        _topicManager = TopicReadingManager(hotDb: _hotDb!, romDb: _romDb!);
      }
    } catch (e) {
      print('[Backend] 学习会话初始化失败（继续）: $e');
    }

    _loadingStatusController.add(LoadingStatus(
      text: '正在检查数据库完整性...',
      progress: 0.8,
      isDone: false,
    ));

    print('[Backend] 检查ROM完整性...');
    // 完整性探针（Web 环境下可能失败，加 try-catch 保护）
    try {
      final romOk = await probeRomIntegrity(_romDb!);
      print('[Backend] ROM完整性: $romOk');
      final hotOk = await probeHotIntegrity(_hotDb!);
      print('[Backend] Hot完整性: $hotOk');
      if (!romOk || !hotOk) {
        print('[Backend] 数据库完整性检查未通过，继续初始化（数据可能已存在）');
      }
    } catch (e) {
      print('[Backend] 数据库完整性检查异常（继续初始化）: $e');
    }

    print('[Backend] 运行迁移...');
    try {
      if (_hotDb != null && _romDb != null) {
        await runMigrations(_hotDb!, _romDb!);
        print('[Backend] 迁移完成');
      }
    } catch (e) {
      print('[Backend] 迁移失败（继续）: $e');
    }

    print('[Backend] 检查热库种子数据...');
    try {
      if (_hotDb != null && _romDb != null) {
        // 热库种子数据：如果 Card 表为空，重新创建
        await seedHotDataIfNeeded(_hotDb!, _romDb!);
        print('[Backend] 热库种子数据完成');
      }
    } catch (e) {
      print('[Backend] 热库种子数据失败（继续）: $e');
    }

    // 双重检查：确保 Card 表有数据（依赖于 ROM 数据库完整性）
    try {
      if (_hotDb != null) {
        final cardCount = Sqflite.firstIntValue(
            await _hotDb!.rawQuery('SELECT COUNT(*) FROM Card'));
        print('[Backend] Card数量: $cardCount');
        if (cardCount == null || cardCount == 0) {
          print('[Backend] Card为空，强制检查ROM完整性...');
          if (_romDb != null) {
            await ensureRomDataIntegrity(_romDb!);
          }
          if (_hotDb != null && _romDb != null) {
            await seedHotDataIfNeeded(_hotDb!, _romDb!);
          }
          print('[Backend] 强制补种完成');
        }
      }
    } catch (e) {
      print('[Backend] Card检查失败（继续）: $e');
    }

    _loadingStatusController.add(LoadingStatus(
      text: '初始化完成',
      progress: 1.0,
      isDone: true,
    ));
    print('[Backend] 初始化全部完成');
  }

  void dispose() {
    _loadingStatusController.close();
  }

  // -------------------------------------------------------------------------
  // HomePage 数据
  // -------------------------------------------------------------------------

  Future<HomePageData> loadHomePageData() async {
    _ensureInitialized();

    // 每日刷新逻辑
    await _checkAndApplyDailyRefresh();

    final now = DateTime.now().millisecondsSinceEpoch;

    final userName = await querySetting(_hotDb!, 'user_name') ?? '';
    final dailyTarget = int.tryParse(await querySetting(_hotDb!, 'daily_target') ?? '1000') ?? 1000;
    final bookCurrent = int.tryParse(await querySetting(_hotDb!, 'book_progress_current') ?? '0') ?? 0;
    final bookTotal = int.tryParse(await querySetting(_hotDb!, 'book_progress_total') ?? '5000') ?? 5000;
    final totalStudyCount = int.tryParse(await querySetting(_hotDb!, 'total_study_count') ?? '0') ?? 0;
    final totalDays = int.tryParse(await querySetting(_hotDb!, 'total_study_days') ?? '0') ?? 0;
    final lastExportTime = int.tryParse(await querySetting(_hotDb!, 'last_export_time') ?? '0') ?? 0;

    final todayCount = await queryLogCountByDate(_hotDb!, calculateLocalDateStr(now));
    final todayTimeMs = await _queryTodayStudyTimeMs(_hotDb!, calculateLocalDateStr(now));
    final dueCount = await queryTotalDueCount(_hotDb!, now);
    final newCount = await queryTotalNewCount(_hotDb!);

    // 计算今日逻辑日的毫秒区间，用于统计 Quick_Screen 中已标记单词
    final refreshHour = int.tryParse(await querySetting(_hotDb!, 'daily_refresh_hour') ?? '0') ?? 0;
    final nowDateTime = DateTime.now();
    final todayLocal = DateTime(nowDateTime.year, nowDateTime.month, nowDateTime.day);
    final todayStartMs = todayLocal.subtract(Duration(hours: refreshHour)).millisecondsSinceEpoch;
    final todayEndMs = todayStartMs + 86400000;
    final todayQuickKnown = await queryTodayQuickKnownCount(_hotDb!, todayStartMs, todayEndMs);

    final daysSinceExport = (now - lastExportTime) ~/ 86400000;
    final exportWarning = daysSinceExport >= 7;

    return HomePageData(
      userName: userName,
      todayLearnedCount: todayCount + todayQuickKnown,
      todayStudyTimeMs: todayTimeMs,
      dailyTarget: dailyTarget,
      remaining: dueCount,
      bookProgressCurrent: bookCurrent,
      bookProgressTotal: bookTotal,
      totalStudyCount: totalStudyCount,
      totalDays: totalDays,
      dueCount: dueCount,
      newCount: newCount,
      daysSinceExport: daysSinceExport,
      exportWarning: exportWarning,
    );
  }

  /// 检查并应用每日刷新
  Future<void> _checkAndApplyDailyRefresh() async {
    final refreshHour = int.tryParse(await querySetting(_hotDb!, 'daily_refresh_hour') ?? '0') ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final lastResetDate = await querySetting(_hotDb!, 'last_daily_reset_date') ?? '';

    if (lastResetDate == todayStr) return; // 今天已刷新

    final todayRefreshMs = DateTime(now.year, now.month, now.day, refreshHour).millisecondsSinceEpoch;
    final yesterday = today.subtract(Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    // 今日刷新时间未到，但昨天刷新时间已过
    final shouldReset = lastResetDate.isEmpty || (lastResetDate != todayStr && lastResetDate != yesterdayStr) ||
        (lastResetDate == yesterdayStr && now.millisecondsSinceEpoch >= todayRefreshMs);

    if (shouldReset) {
      await setSetting(_hotDb!, 'last_daily_reset_date', todayStr);
      // 重置今日数据
      await setSettingInt(_hotDb!, 'today_study_time_ms', 0);
      await setSettingInt(_hotDb!, 'today_new_count', 0);
    }
  }

  // -------------------------------------------------------------------------
  // RandomLearnPage 数据
  // -------------------------------------------------------------------------

  /// 加载一张卡片用于学习（从指定会话）
  Future<RandomLearnPageData?> loadRandomLearnCard() async {
    print('[Provider] loadRandomLearnCard 开始');
    _ensureInitialized();
    final details = await _studyManager!.getCurrentCardWithDetails();
    print('[Provider] getCurrentCardWithDetails 完成, details=$details');
    if (details == null) return null;

    final note = details['note'] as NoteModel;
    final card = details['card'] as CardModel;

    return RandomLearnPageData(
      conceptUuid: note.conceptUuid,
      spelling: note.spelling,
      phonetic: note.phonetic,
      etymology: formatEtymologyForDisplay(note.etymologyJson ?? ''),
      definition: note.definition,
      microContext: formatMicroContextForDisplay(note.microContextJson),
      stability: card.s,
      retrievability: card.r,
      ratingDistribution: details['ratingDistribution'] as Map<String, double>,
      isFavorite: card.favorite == 1,
      progress: details['progress'] as String,
      cardStatus: details['status'] as String,
      nextReviewDays: details['nextReviewDays'] as int,
      stabilityDays: details['stabilityDays'] as double,
      retrievabilityPct: details['retrievabilityPct'] as double,
      againPct: details['againPct'] as double,
      hardPct: details['hardPct'] as double,
      goodPct: details['goodPct'] as double,
      easyPct: details['easyPct'] as double,
      nextReviewText: details['nextReview'] as String,
      bncText: note.bnc > 0 ? 'bnc:${note.bnc}' : '',
      frqText: note.frq > 0 ? 'frq:${note.frq}' : '',
      synonymText: '',
      collinsStar: note.collinsStar,
      definitionEn: note.definitionEn,
      pastTense: note.pastTense,
      pastParticiple: note.pastParticiple,
    );
  }

  Future<RandomLearnPageData?> loadRandomAskCard() async {
    return loadRandomLearnCard();
  }

  Future<RandomLearnPageData?> loadRandomAsk2Card() async {
    return loadRandomLearnCard();
  }

  Future<RandomLearnPageData?> loadRandomLearn2Card() async {
    return loadRandomLearnCard();
  }

  /// Ask 页面：纯预览，不落盘
  /// 返回 Learn 页面的卡片数据（含预览后的 s/r/status）
  Future<RandomLearnPageData?> previewRating(int rating) async {
    _ensureInitialized();
    final details = await _studyManager!.previewRating(rating);
    if (details == null) return null;

    final note = details['note'] as NoteModel;
    final card = details['card'] as CardModel;

    return RandomLearnPageData(
      conceptUuid: note.conceptUuid,
      spelling: note.spelling,
      phonetic: note.phonetic,
      etymology: formatEtymologyForDisplay(note.etymologyJson ?? ''),
      definition: note.definition,
      microContext: formatMicroContextForDisplay(note.microContextJson),
      stability: card.s,
      retrievability: card.r,
      ratingDistribution: details['ratingDistribution'] as Map<String, double>,
      isFavorite: card.favorite == 1,
      progress: details['progress'] as String,
      cardStatus: details['status'] as String,
      nextReviewDays: details['nextReviewDays'] as int,
      stabilityDays: details['stabilityDays'] as double,
      retrievabilityPct: details['retrievabilityPct'] as double,
      againPct: details['againPct'] as double,
      hardPct: details['hardPct'] as double,
      goodPct: details['goodPct'] as double,
      easyPct: details['easyPct'] as double,
      nextReviewText: details['nextReview'] as String,
      bncText: note.bnc > 0 ? 'bnc:${note.bnc}' : '',
      frqText: note.frq > 0 ? 'frq:${note.frq}' : '',
      synonymText: '',
      collinsStar: note.collinsStar,
      definitionEn: note.definitionEn,
      pastTense: note.pastTense,
      pastParticiple: note.pastParticiple,
    );
  }

  /// Learn 页面：确定评级，落盘 + 推进
  Future<CardModel?> confirmPendingRating(int rating) async {
    _ensureInitialized();
    return _studyManager!.confirmPendingRating(rating);
  }

  /// 提交评级（保留，兼容 quickScreen 等其他模式）
  /// [shouldAdvance] = true 时推进到下一张卡，= false 时保持在当前卡（用于 Ask→Learn 场景）
  Future<void> submitRating(int rating, {bool shouldAdvance = true}) async {
    _ensureInitialized();
    await _studyManager!.submitRating(rating, shouldAdvance: shouldAdvance);
  }

  /// 会话是否还有未学习的卡
  bool get hasNextCard {
    _ensureInitialized();
    return _studyManager!.currentSession?.hasNext ?? false;
  }

  /// 会话是否为空
  bool get hasSession {
    _ensureInitialized();
    return _studyManager!.currentSession != null;
  }

  /// 获取当前学习会话（用于外部读取 session 状态）
  StudySession? getStudySession() {
    _ensureInitialized();
    return _studyManager!.currentSession;
  }

  /// 创建学习会话（复习/学习按钮跳页前必须调用）
  Future<void> createLearnSession({int? limit}) async {
    _ensureInitialized();
    await _studyManager!.createLearnSession(limit: limit);
  }

  /// 从语义阅读页点词进入：创建单卡学习会话，携带恢复用 articleId / topicId
  Future<void> startTopicReadingWordSession(String conceptUuid, String resumeArticleId, String resumeTopicId) async {
    _ensureInitialized();
    print('[Provider] startTopicReadingWordSession uuid=$conceptUuid articleId=$resumeArticleId');
    await _studyManager!.createSingleCardLearnSession(
      conceptUuid,
      resumeArticleId: resumeArticleId,
      resumeTopicId: resumeTopicId,
    );
  }

  /// 从结构树页点词进入：创建单卡学习会话，携带恢复用 rootId
  Future<void> startTreeLearnSession(String conceptUuid, String rootId) async {
    _ensureInitialized();
    print('[Provider] startTreeLearnSession uuid=$conceptUuid rootId=$rootId');
    await _studyManager!.createTreeLearnSession(conceptUuid, rootId);
  }

  /// 创建复习会话
  Future<void> createReviewSession({int? limit}) async {
    _ensureInitialized();
    await _studyManager!.createReviewSession(limit: limit);
  }

  /// 撤销
  Future<void> undo() async {
    _ensureInitialized();
    await _studyManager!.undo();
  }

  /// 切换收藏状态
  Future<bool> toggleFavorite(String uuid) async {
    _ensureInitialized();
    final card = await queryCardByUuid(_hotDb!, uuid);
    if (card == null) return false;
    final newVal = card.favorite == 1 ? 0 : 1;
    await updateCardFavorite(_hotDb!, uuid, newVal);
    return newVal == 1;
  }

  /// 标记专题阅读中的词为已读（设置 Topic_Read=1），使文章页 readCount 包含此卡
  Future<void> markTopicWordRead(String uuid) async {
    _ensureInitialized();
    await updateCardTopicRead(_hotDb!, uuid);
  }

  // -------------------------------------------------------------------------
  // QuickLearnPage 数据
  // -------------------------------------------------------------------------

  Future<void> initQuickLearnSession({int? limit}) async {
    _ensureInitialized();
    await _quickScreenManager!.initSession(limit: limit);
  }

  List<QuickLearnItemData> getQuickLearnItems() {
    return _quickScreenManager!.items.asMap().entries.map((e) {
      return QuickLearnItemData(
        index: e.key,
        conceptUuid: e.value.conceptUuid,
        spelling: e.value.spelling,
        isKnown: e.value.status == QuickScreenItemStatus.known,
      );
    }).toList();
  }

  String getQuickLearnProgress() => _quickScreenManager!.progressText;

  Future<void> toggleQuickLearnKnown(int index) async {
    await _quickScreenManager!.toggleKnown(index);
  }

  Future<void> loadNextQuickLearnPage() async {
    await _quickScreenManager!.nextPage();
  }

  Future<void> loadPrevQuickLearnPage() async {
    await _quickScreenManager!.prevPage();
  }

  bool hasNextQuickLearnPage() => _quickScreenManager!.hasNextPage;

  bool hasPrevQuickLearnPage() => _quickScreenManager!.hasPrevPage;

  bool getQuickLearnIsAllDone() => _quickScreenManager!.isAllDone;

  Future<List<String>> getQuickMarkedSpellings() async {
    _ensureInitialized();
    final knownUuids = await queryKnownUuids(_hotDb!);
    final spellings = <String>[];
    for (final uuid in knownUuids) {
      final note = await queryNoteByUuid(_romDb!, uuid);
      if (note != null) spellings.add(note.spelling);
    }
    return spellings;
  }

  /// 根据 UUID 列表查询对应单词的拼写列表
  Future<List<String>> getSpellingsByUuids(List<String> uuids) async {
    _ensureInitialized();
    final spellings = <String>[];
    for (final uuid in uuids) {
      final note = await queryNoteByUuid(_romDb!, uuid);
      if (note != null) spellings.add(note.spelling);
    }
    return spellings;
  }

  // -------------------------------------------------------------------------
  // TreePage 数据
  // -------------------------------------------------------------------------

  Future<TreePageData?> loadTreePageData(String rootId) async {
    _ensureInitialized();
    final root = await _treeManager!.getRootById(rootId);
    if (root == null) return null;
    final words = await _treeManager!.getWordsByRoot(root.rootId);

    return TreePageData(
      rootId: root.rootId,
      rootName: root.rootName,
      rootDefinition: root.rootDefinition,
      words: words,
    );
  }

  Future<void> visitTreeWord(String conceptUuid) async {
    _ensureInitialized();
    await _treeManager!.visitWord(conceptUuid);
  }

  // -------------------------------------------------------------------------
  // TopicReadingPage 数据
  // -------------------------------------------------------------------------

  Future<List<TopicItemData>> loadTopics() async {
    _ensureInitialized();
    final topics = await _topicManager!.getAllTopics();
    return topics.map((t) => TopicItemData(
      topicId: t.topicId,
      topicName: t.topicName,
      topicNameEn: t.topicNameEn,
      wordCount: t.wordCount,
    )).toList();
  }

  Future<TopicReadingPageData?> loadArticle(String articleId) async {
    try {
      _ensureInitialized();
      print('[Provider] loadArticle articleId=$articleId');
      final display = await _topicManager!.getArticleDisplay(articleId);
      print('[Provider] getArticleDisplay 返回: ${display == null ? "null" : "非null"}');
      if (display == null) return null;

      return TopicReadingPageData(
        articleId: display.articleId,
        topicName: display.topicName,
        wordCountText: display.wordCountText,
        readCountText: display.readCountText,
        segments: display.segments.map((s) => TextSpanData(
          text: s['t'] as String? ?? '',
          isHighlighted: s['c'] == 1,
          uuid: s['u'] as String?,
        )).toList(),
      );
    } catch (e, st) {
      print('[Provider] loadArticle 异常: $e\n$st');
      print('[Provider] loadArticle 返回: null');
      return null;
    }
  }

  Future<void> visitTopicWord(String conceptUuid) async {
    _ensureInitialized();
    await _topicManager!.visitWord(conceptUuid);
  }

  /// 获取专题中当前文章的下一篇 articleId（Next 按钮用）
  Future<String?> getNextArticleId(String topicId, String currentArticleId) async {
    _ensureInitialized();
    return _topicManager!.getNextArticleId(topicId, currentArticleId);
  }

  /// 获取专题中当前文章的上一篇 articleId（Back 按钮用）
  Future<String?> getPreviousArticleId(String topicId, String currentArticleId) async {
    _ensureInitialized();
    return _topicManager!.getPreviousArticleId(topicId, currentArticleId);
  }

  /// 获取专题的所有文章列表及当前索引（用于条件显示 Back/Next 按钮）
  Future<TopicArticlesResult?> getTopicArticlesWithIndex(String topicId, String currentArticleId) async {
    _ensureInitialized();
    return _topicManager!.getTopicArticlesWithIndex(topicId, currentArticleId);
  }

  // -------------------------------------------------------------------------
  // ResultPage 数据
  // -------------------------------------------------------------------------

  Future<SessionStats> endSession() async {
    _ensureInitialized();
    return _studyManager!.endSession();
  }

  // -------------------------------------------------------------------------
  // FavoritePage 数据
  // -------------------------------------------------------------------------

  Future<List<FavoriteItemData>> loadFavorites() async {
    _ensureInitialized();
    final cards = await queryFavoriteCards(_hotDb!);
    final items = <FavoriteItemData>[];
    for (final card in cards) {
      final note = await queryNoteByUuid(_romDb!, card.conceptUuid);
      if (note == null) continue;
      items.add(FavoriteItemData(
        conceptUuid: card.conceptUuid,
        spelling: note.spelling,
        phonetic: note.phonetic,
        definition: note.definition,
      ));
    }
    return items;
  }

  // -------------------------------------------------------------------------
  // SettingsPage 数据
  // -------------------------------------------------------------------------

  Future<SettingsData> loadSettings() async {
    _ensureInitialized();
    return SettingsData(
      userName: await querySetting(_hotDb!, 'user_name') ?? '',
      currentBook: await querySetting(_hotDb!, 'current_book') ?? 'cet6',
      singleSessionLimit: int.tryParse(await querySetting(_hotDb!, 'single_session_limit') ?? '70') ?? 70,
      showEtymology: (await querySetting(_hotDb!, 'show_etymology') ?? '1') == '1',
      showDefinition: (await querySetting(_hotDb!, 'show_definition') ?? '1') == '1',
      showExample: (await querySetting(_hotDb!, 'show_example') ?? '1') == '1',
      dailyRefreshHour: int.tryParse(await querySetting(_hotDb!, 'daily_refresh_hour') ?? '0') ?? 0,
    );
  }

  Future<void> updateSetting(String key, String value) async {
    _ensureInitialized();
    await setSetting(_hotDb!, key, value);
  }

  // -------------------------------------------------------------------------
  // 词书数据（对应 SRS&SDD v2.1 附录 B）
  // -------------------------------------------------------------------------

  /// 加载所有词书列表
  Future<List<WordBookModel>> loadWordBooks() async {
    _ensureInitialized();
    return queryAllWordBooks(_hotDb!);
  }

  // -------------------------------------------------------------------------
  // ReportsPage 数据
  // -------------------------------------------------------------------------

  Future<ReportsPageData> loadReportsData() async {
    _ensureInitialized();

    final totalStudyTimeMs = int.tryParse(await querySetting(_hotDb!, 'total_study_time_ms') ?? '0') ?? 0;
    final totalStudyCount = int.tryParse(await querySetting(_hotDb!, 'total_study_count') ?? '0') ?? 0;
    final totalDays = int.tryParse(await querySetting(_hotDb!, 'total_study_days') ?? '0') ?? 0;
    final userName = await querySetting(_hotDb!, 'user_name') ?? '';
    final currentBook = await querySetting(_hotDb!, 'current_book') ?? 'cet6';
    final bookProgressCurrent = int.tryParse(await querySetting(_hotDb!, 'book_progress_current') ?? '0') ?? 0;
    final bookProgressTotal = int.tryParse(await querySetting(_hotDb!, 'book_progress_total') ?? '5000') ?? 5000;

    final monthlyStats = await queryMonthlyStats(_hotDb!, 6);
    final yearlyStats = await queryYearlyStats(_hotDb!, 3);

    return ReportsPageData(
      userName: userName,
      totalStudyTimeMs: totalStudyTimeMs,
      totalStudyCount: totalStudyCount,
      totalDays: totalDays,
      currentBook: currentBook,
      bookProgressCurrent: bookProgressCurrent,
      bookProgressTotal: bookProgressTotal,
      monthlyStats: monthlyStats,
      yearlyStats: yearlyStats,
    );
  }

  // -------------------------------------------------------------------------
  // 导入导出
  // -------------------------------------------------------------------------

  Future<String> exportData() async {
    _ensureInitialized();
    final json = await exportProgressJson(_hotDb!);
    final now = DateTime.now().millisecondsSinceEpoch;
    await setSettingInt(_hotDb!, 'last_export_time', now);
    return json;
  }

  Future<ImportResult> importData(String json) async {
    _ensureInitialized();
    return importProgressJson(_hotDb!, json);
  }

  // -------------------------------------------------------------------------
  // TreeCatelogPage 数据（分组词根目录）
  // -------------------------------------------------------------------------

  Future<List<String>> getAllTreeGroups() async {
    _ensureInitialized();
    return _treeManager!.getAllGroups();
  }

  Future<List<TreeRootDisplayModel>> loadTreeRootsForGroup(String group) async {
    _ensureInitialized();
    final roots = await _treeManager!.getRootsByGroup(group);
    return roots.map((r) => TreeRootDisplayModel(
      rootId: r.rootId,
      rootName: r.rootName,
      rootDefinition: r.rootDefinition,
    )).toList();
  }

  // -------------------------------------------------------------------------
  // 辅助
  // -------------------------------------------------------------------------

  void _ensureInitialized() {
    if (!isInitialized) {
      print('[Backend] _ensureInitialized: 未初始化，抛出异常');
      throw Exception('BACKEND_NOT_INITIALIZED: 请先调用 BackendManager.instance.initialize()');
    }
    print('[Backend] _ensureInitialized: 已初始化，通过');
  }

  Future<int> _queryTodayStudyTimeMs(Database hotDb, String localDate) async {
    // 直接读取已累加的今日学习时长
    final v = await querySetting(hotDb, 'today_study_time_ms');
    return int.tryParse(v ?? '0') ?? 0;
  }
}

// ============================================================================
// 数据模型定义（FlutterFlow 前端直接引用这些类）
// ============================================================================

class HomePageData {
  final String userName;
  final int todayLearnedCount;
  final int todayStudyTimeMs;
  final int dailyTarget;
  final int remaining;
  final int bookProgressCurrent;
  final int bookProgressTotal;
  final int totalStudyCount;
  final int totalDays;
  final int dueCount;
  final int newCount;
  final int daysSinceExport;
  final bool exportWarning;

  HomePageData({
    required this.userName,
    required this.todayLearnedCount,
    required this.todayStudyTimeMs,
    required this.dailyTarget,
    required this.remaining,
    required this.bookProgressCurrent,
    required this.bookProgressTotal,
    required this.totalStudyCount,
    required this.totalDays,
    required this.dueCount,
    required this.newCount,
    required this.daysSinceExport,
    required this.exportWarning,
  });

  String _formatDuration(int ms) {
    if (ms <= 0) return '0min';
    final h = ms ~/ 3600000;
    final m = (ms % 3600000) ~/ 60000;
    if (h > 0) return '${h}h${m > 0 ? '${m}min' : ''}';
    return '${m}min';
  }

  // 格式化字段（前端直接显示）
  String get greetingText => userName.isEmpty ? 'Hi,' : 'Hi,$userName';
  String get todayLearnedText => '今日已学${todayLearnedCount}词，${_formatDuration(todayStudyTimeMs)}';
  String get exportWarningText => '已${daysSinceExport}天未备份';
  String get remainingText => '剩余：$remaining';
  String get bookProgressText => '当前词书：$bookProgressCurrent/$bookProgressTotal';
  String get totalStudyCountText => '累计学习$totalStudyCount次';
  String get totalDaysText => '累计${totalDays}天';
  String get dueCountText => '待复习$dueCount词';
  String get newCountText => '新词$newCount个';
}

class RandomLearnPageData {
  final String conceptUuid;
  final String spelling;
  final String phonetic;
  final String etymology;
  final String definition;
  final String microContext;
  final double stability;
  final double retrievability;
  final Map<String, double> ratingDistribution;
  final bool isFavorite;
  final String progress;
  final String cardStatus;
  final int nextReviewDays;
  final double stabilityDays;
  final double retrievabilityPct;
  final double againPct;
  final double hardPct;
  final double goodPct;
  final double easyPct;
  final String nextReviewText;
  final String bncText;
  final String frqText;
  final String synonymText;
  final int collinsStar;
  final String? definitionEn;
  final String? pastTense;
  final String? pastParticiple;

  RandomLearnPageData({
    required this.conceptUuid,
    required this.spelling,
    required this.phonetic,
    required this.etymology,
    required this.definition,
    required this.microContext,
    required this.stability,
    required this.retrievability,
    required this.ratingDistribution,
    required this.isFavorite,
    required this.progress,
    required this.cardStatus,
    required this.nextReviewDays,
    required this.stabilityDays,
    required this.retrievabilityPct,
    required this.againPct,
    required this.hardPct,
    required this.goodPct,
    required this.easyPct,
    required this.nextReviewText,
    this.bncText = '',
    this.frqText = '',
    this.synonymText = '',
    this.collinsStar = 0,
    this.definitionEn,
    this.pastTense,
    this.pastParticiple,
  });

  String get statusText => 'status:$cardStatus';
  String get againText => 'again:${_formatPct(againPct)}';
  String get hardText => 'hard:${_formatPct(hardPct)}';
  String get goodText => 'good:${_formatPct(goodPct)}';
  String get easyText => 'easy:${_formatPct(easyPct)}';
  String get stabilityText =>
      'stability:${stabilityDays == stabilityDays.roundToDouble() ? stabilityDays.toInt() : stabilityDays.toStringAsFixed(1)}days';
  String get retrievabilityText =>
      'retrievability:${_formatPct(retrievabilityPct)}';
  String get nextReviewDisplayText => '下次复习时间：${nextReviewDays}天后';
  String get spellingText => spelling;
  String get phoneticText => formatPhoneticForDisplay(phonetic);
  String get etymologyText => etymology;
  String get definitionText => definition;
  String get favoriteButtonText => isFavorite ? '已收藏' : '收藏';
  String get againPercentText => _formatPct(againPct);
  String get hardPercentText => _formatPct(hardPct);
  String get goodPercentText => _formatPct(goodPct);
  String get easyPercentText => _formatPct(easyPct);
  String get contextText => microContext;
  String get progressText => progress;
  String get collinsStarText => collinsStar > 0 ? 'collinsStar:$collinsStar' : '';
  String get tenseText {
    if (pastTense == null && pastParticiple == null) return '';
    final pt = pastTense ?? '';
    final pp = pastParticiple ?? '';
    if (pt.isEmpty && pp.isEmpty) return '';
    return '过去式: $pt  过去分词: $pp';
  }
}

class QuickLearnItemData {
  final int index;
  final String conceptUuid;
  final String spelling;
  final bool isKnown;

  QuickLearnItemData({
    required this.index,
    required this.conceptUuid,
    required this.spelling,
    required this.isKnown,
  });

  String get spellingText => spelling;
  String get statusText => isKnown ? '已认识' : '认识';
}

class TreePageData {
  final String rootId;
  final String rootName;
  final String rootDefinition;
  final List<TreeWordDisplayModel> words;

  TreePageData({
    required this.rootId,
    required this.rootName,
    required this.rootDefinition,
    required this.words,
  });

  String get rootNameText => rootName;
  String get rootDefinitionText => rootDefinition;
}

class TreeRootDisplayModel {
  final String rootId;
  final String rootName;
  final String rootDefinition;

  TreeRootDisplayModel({
    required this.rootId,
    required this.rootName,
    required this.rootDefinition,
  });
}

class TopicItemData {
  final String topicId;
  final String topicName;
  final String topicNameEn;
  final int wordCount;

  TopicItemData({
    required this.topicId,
    required this.topicName,
    required this.topicNameEn,
    required this.wordCount,
  });
}

class TopicReadingPageData {
  final String articleId;
  final String topicName;
  final String wordCountText;
  final String readCountText;
  final List<TextSpanData> segments;

  TopicReadingPageData({
    required this.articleId,
    required this.topicName,
    required this.wordCountText,
    required this.readCountText,
    required this.segments,
  });
}

class TextSpanData {
  final String text;
  final bool isHighlighted;
  final String? uuid;

  TextSpanData({
    required this.text,
    required this.isHighlighted,
    this.uuid,
  });
}

class FavoriteItemData {
  final String conceptUuid;
  final String spelling;
  final String phonetic;
  final String definition;

  FavoriteItemData({
    required this.conceptUuid,
    required this.spelling,
    required this.phonetic,
    required this.definition,
  });

  String get phoneticText => '/$phonetic /';
  String get definitionText => definition;
}

class SettingsData {
  final String userName;
  final String currentBook;
  final int singleSessionLimit;
  final bool showEtymology;
  final bool showDefinition;
  final bool showExample;
  final int dailyRefreshHour;

  SettingsData({
    required this.userName,
    required this.currentBook,
    required this.singleSessionLimit,
    required this.showEtymology,
    required this.showDefinition,
    required this.showExample,
    required this.dailyRefreshHour,
  });

  String get userNameText => userName.isEmpty ? 'Hi,' : 'Hi,$userName';
}

class ReportsPageData {
  final String userName;
  final int totalStudyTimeMs;
  final int totalStudyCount;
  final int totalDays;
  final String currentBook;
  final int bookProgressCurrent;
  final int bookProgressTotal;
  final List<MonthlyStat> monthlyStats;
  final Map<int, MonthlyStat> yearlyStats;

  ReportsPageData({
    required this.userName,
    required this.totalStudyTimeMs,
    required this.totalStudyCount,
    required this.totalDays,
    required this.currentBook,
    required this.bookProgressCurrent,
    required this.bookProgressTotal,
    required this.monthlyStats,
    required this.yearlyStats,
  });

  String get userNameText => userName.isEmpty ? 'Hi,' : 'Hi,$userName';

  String get totalStudyTimeText {
    if (totalStudyTimeMs <= 0) return '总学习时长：0h 0min';
    final h = totalStudyTimeMs ~/ 3600000;
    final m = (totalStudyTimeMs % 3600000) ~/ 60000;
    return '总学习时长：${h}h ${m}min';
  }

  String get totalStudyCountText => '累计学习：${totalStudyCount}词';
  String get totalDaysText => '共学习：${totalDays}天';
  String get bookProgressText => '已学词书：${_bookLabel(currentBook)}，$bookProgressCurrent/$bookProgressTotal';

  /// 月度总结文字（例如 "2024-03: 120词/80%良"）
  String get monthlySummaryText {
    if (monthlyStats.isEmpty) return '';
    final latest = monthlyStats.last;
    final rate = (latest.goodRate * 100).toStringAsFixed(0);
    return '${latest.yearMonth}: ${latest.reviewCount}词/$rate%良';
  }

  /// 年度总结文字（例如 "2024: 3600词"）
  String get yearlySummaryText {
    if (yearlyStats.isEmpty) return '';
    final currentYear = DateTime.now().year;
    final stat = yearlyStats[currentYear];
    if (stat == null) return '';
    return '$currentYear: ${stat.reviewCount}词';
  }

  String _bookLabel(String book) {
    switch (book) {
      case 'kaoyan2027': return '2027考研';
      case 'cet6': return 'CET6';
      case 'cet4': return 'CET4';
      default: return book;
    }
  }
}

class LoadingStatus {
  final String text;
  final double progress;
  final bool isDone;

  LoadingStatus({
    required this.text,
    required this.progress,
    required this.isDone,
  });
}

// ============================================================================
// FlutterFlow StateNotifier（接入层）
// ============================================================================
//
// FlutterFlow 中的自定义代码 widget 引用示例：
//
// ```dart
// import 'package:wordmemory/backend/provider.dart';
//
// class HomePageModel extends FlutterFlowModel {
//   BackendManager get backend => BackendManager.instance;
//
//   Future<String> getGreetingText() async {
//     final data = await backend.loadHomePageData();
//     return data.greetingText;
//   }
//
//   Future<String> getTodayLearnedText() async {
//     final data = await backend.loadHomePageData();
//     return data.todayLearnedText;
//   }
// }
// ```
//
// ============================================================================
