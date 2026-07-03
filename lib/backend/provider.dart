library wordmemory.backend;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show InlineSpan, TextSpan, TextStyle, Color;
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

/// 规范化文本：统一换行符
String sanitizeText(String s) {
  return s.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}

/// 处理文本中的换行符：将字面 \n 字符串转换为真实换行，并规范化格式
String formatTextWithNewlines(String s) {
  if (s.isEmpty) return '';
  return s
    .replaceAll(r'\n', '\n')
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n');
}

/// 词根词缀 JSON → InlineSpan（数字部分为灰色上标）
/// 支持两种格式：
/// 1. roots 数组格式（数据库实际格式）：{"roots":[{...}],"compound":"","final":""}
/// 2. prefix/root/suffix 格式：{"prefix":"","root":"","suffix":""}
InlineSpan formatEtymologyAsSpans(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return const TextSpan(text: '');
  final lines = <InlineSpan>[];

  String? prefixPart;
  String? prefixMeaning;
  String? rootPart;
  String? rootMeaning;
  String? suffixPart;
  String? suffixMeaning;

  try {
    final dynamic d = jsonDecode(s);
    if (d is! Map) return const TextSpan(text: '');
    final map = d as Map<String, dynamic>;

    // 优先处理 roots 数组格式
    final roots = map['roots'] as List?;
    if (roots != null && roots.isNotEmpty) {
      for (int i = 0; i < roots.length; i++) {
        if (roots[i] is! Map) continue;
        final rootMap = roots[i] as Map<String, dynamic>;
        final root = rootMap['root']?.toString().trim() ?? '';
        final meaning = rootMap['meaning']?.toString().trim() ?? '';
        if (root.isNotEmpty) {
          lines.add(_buildLineSpan(root, meaning));
        }
      }
    }

    if (lines.isEmpty) {
      // 备用：处理 prefix/root/suffix 格式
      final prefix = map['prefix']?.toString().trim() ?? '';
      final prefixMeaning2 = map['prefixMeaning']?.toString().trim() ?? '';
      final root = map['root']?.toString().trim() ?? '';
      final rootMeaning2 = map['rootMeaning']?.toString().trim() ?? '';
      final suffix = map['suffix']?.toString().trim() ?? '';
      final suffixMeaning2 = map['suffixMeaning']?.toString().trim() ?? '';
      if (prefix.isNotEmpty) lines.add(_buildLineSpan(prefix, prefixMeaning2));
      if (root.isNotEmpty) lines.add(_buildLineSpan(root, rootMeaning2));
      if (suffix.isNotEmpty) lines.add(_buildLineSpan(suffix, suffixMeaning2));
    }
  } catch (e) {
    print('[formatEtymology] 解析失败: $e');
  }

  if (lines.isEmpty) return const TextSpan(text: '');

  return TextSpan(children: [
    for (int i = 0; i < lines.length; i++) ...[
      lines[i],
      if (i < lines.length - 1) const TextSpan(text: '\n'),
    ],
  ]);
}

/// 构建单行 InlineSpan：词根(数字上标+灰色) + 意思
InlineSpan _buildLineSpan(String root, String meaning) {
  if (meaning.isNotEmpty) {
    // "root — meaning"
    return TextSpan(children: [
      _buildEtymologySpans(root),
      TextSpan(text: ' — $meaning'),
    ]);
  }
  return _buildEtymologySpans(root);
}

/// 词根词缀 JSON → 纯文本（数字转为 Unicode 上标，用于纯文本场景）
String formatEtymologyForDisplay(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  final span = formatEtymologyAsSpans(s);
  if (span is TextSpan && span.children == null) {
    return (span as TextSpan).text ?? '';
  }
  // 手动拼接纯文本版本
  final buffer = StringBuffer();
  _extractTextFromSpan(span, buffer);
  return buffer.toString();
}

/// 从 InlineSpan 提取纯文本
void _extractTextFromSpan(InlineSpan span, StringBuffer buf) {
  if (span is TextSpan) {
    buf.write(span.text ?? '');
    if (span.children != null) {
      for (final child in span.children!) {
        _extractTextFromSpan(child, buf);
      }
    }
  }
}

/// 将词根中末尾的数字转为带样式的 InlineSpan
/// 词根部分保持默认颜色，数字部分为灰色上标
/// 例如：cid2 → TextSpan("cid") + TextSpan("²", style: gray)
InlineSpan _buildEtymologySpans(String text) {
  const superscripts = {
    '0': '\u2070', '1': '\u00B9', '2': '\u00B2', '3': '\u00B3',
    '4': '\u2074', '5': '\u2075', '6': '\u2076', '7': '\u2077',
    '8': '\u2078', '9': '\u2079',
  };

  final regex = RegExp(r'([a-zA-Z-]+)(\d+)');
  final spans = <InlineSpan>[];
  int lastEnd = 0;

  for (final match in regex.allMatches(text)) {
    if (match.start > lastEnd) {
      spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
    }
    final prefix = match.group(1) ?? '';
    final digits = match.group(2) ?? '';
    final superscripted = digits.split('').map((c) => superscripts[c] ?? c).join();

    spans.add(TextSpan(text: prefix)); // 词根：默认颜色
    spans.add(TextSpan(
      text: superscripted,
      style: const TextStyle(color: Color(0xFF888888)), // 数字：灰色
    ));
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    spans.add(TextSpan(text: text.substring(lastEnd)));
  }

  if (spans.isEmpty) {
    return TextSpan(text: text);
  }
  return TextSpan(children: spans);
}

/// 兼容旧调用：将数字转为 Unicode 上标文本（用于纯文本场景）
String applySuperscriptToText(String text) {
  const superscripts = {
    '0': '\u2070', '1': '\u00B9', '2': '\u00B2', '3': '\u00B3',
    '4': '\u2074', '5': '\u2075', '6': '\u2076', '7': '\u2077',
    '8': '\u2078', '9': '\u2079',
  };
  final regex = RegExp(r'([a-zA-Z-]+)(\d+)');
  return text.replaceAllMapped(regex, (m) {
    final prefix = m.group(1) ?? '';
    final digits = m.group(2) ?? '';
    final superscripted = digits.split('').map((c) => superscripts[c] ?? c).join();
    return '$prefix$superscripted';
  });
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
class BackendManager extends ChangeNotifier {
  static BackendManager? _instance;
  static BackendManager get instance => _instance ??= BackendManager._();

  BackendManager._();

  Database? _romDb;
  Database? _hotDb;
  StudySessionManager? _studyManager;
  TreeManager? _treeManager;
  TopicReadingManager? _topicManager;

  TreeManager get treeManager => _treeManager!;
  TopicReadingManager get topicManager => _topicManager!;

  final _loadingStatusController = StreamController<LoadingStatus>.broadcast();

  Stream<LoadingStatus> get loadingStatusStream => _loadingStatusController.stream;

  bool get isInitialized => _romDb != null && _hotDb != null;

  Database? get hotDb => _hotDb;

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

  @override
  void dispose() {
    super.dispose();
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
    final totalStudyCount = int.tryParse(await querySetting(_hotDb!, 'total_study_count') ?? '0') ?? 0;
    final totalDays = int.tryParse(await querySetting(_hotDb!, 'total_study_days') ?? '0') ?? 0;
    final lastExportTime = int.tryParse(await querySetting(_hotDb!, 'last_export_time') ?? '0') ?? 0;
    final currentBook = await querySetting(_hotDb!, 'current_book') ?? 'cet4';

    // 从 Book_Progress 表查当前词书的进度，Total 从 WordBook 表取
    print('[Provider] loadHomePageData: currentBook=$currentBook');
    int bookTotal;
    int bookCurrent;

  // 从 WordBook 表取总词数和显示名称
    final book = await queryWordBookById(_hotDb!, currentBook);
    String? bookDisplayName;
    if (book != null) {
      bookTotal = book.wordCount;
      bookDisplayName = book.bookName;
    } else {
      bookTotal = 0;
      bookDisplayName = null;
    }

    // 始终从 Card 表按词书标签统计已学数量（不过度依赖 Book_Progress 表）
    bookCurrent = await queryLearnedCountByBook(_hotDb!, currentBook);
    print('[Provider] loadHomePageData: bookTotal=$bookTotal bookCurrent=$bookCurrent bookDisplayName=$bookDisplayName');

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
      currentBook: currentBook,
      bookDisplayName: bookDisplayName,
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
      bncText: note.bnc > 0 ? 'bnc:${note.bnc}' : 'bnc:no',
      frqText: note.frq > 0 ? 'frq:${note.frq}' : 'frq:no',
      collinsStar: note.collinsStar,
      definitionEn: note.definitionEn,
      pastTense: note.pastTense,
      pastParticiple: note.pastParticiple,
      presentParticiple: note.presentParticiple,
      thirdPerson: note.thirdPerson,
      comparative: note.comparative,
      superlative: note.superlative,
      plural: note.plural,
      lemma: note.lemma,
      lemmaVariant: note.lemmaVariant,
      tagList: note.tagList,
      synonymJson: note.synonymJson,
      isOxford: note.isOxford,
      oxford3000: note.oxford3000,
      oxford5000: note.oxford5000,
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
      bncText: note.bnc > 0 ? 'bnc:${note.bnc}' : 'bnc:no',
      frqText: note.frq > 0 ? 'frq:${note.frq}' : 'frq:no',
      collinsStar: note.collinsStar,
      definitionEn: note.definitionEn,
      pastTense: note.pastTense,
      pastParticiple: note.pastParticiple,
      presentParticiple: note.presentParticiple,
      thirdPerson: note.thirdPerson,
      comparative: note.comparative,
      superlative: note.superlative,
      plural: note.plural,
      lemma: note.lemma,
      lemmaVariant: note.lemmaVariant,
      tagList: note.tagList,
      synonymJson: note.synonymJson,
      isOxford: note.isOxford,
      oxford3000: note.oxford3000,
      oxford5000: note.oxford5000,
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
  Future<void> createLearnSession({int? limit, String? bookId}) async {
    _ensureInitialized();
    await _studyManager!.createLearnSession(limit: limit, bookId: bookId);
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

  /// 从快速筛选页点词进入：创建单卡学习会话，不修改 Quick_Screen 状态
  Future<void> startQuickLearnWordSession(String conceptUuid) async {
    _ensureInitialized();
    print('[Provider] startQuickLearnWordSession uuid=$conceptUuid');
    await _studyManager!.createSingleCardLearnSession(
      conceptUuid,
      resumeArticleId: 'quick_learn',
      resumeTopicId: 'quick_learn',
    );
  }

  /// 从收藏夹点词进入：创建单卡学习会话，计入总进度
  Future<void> startFavoriteWordSession(String conceptUuid) async {
    _ensureInitialized();
    print('[Provider] startFavoriteWordSession uuid=$conceptUuid');
    await _studyManager!.createSingleCardLearnSession(
      conceptUuid,
      resumeArticleId: 'favorite',
      resumeTopicId: 'favorite',
    );
  }

  /// 创建复习会话
  Future<void> createReviewSession({int? limit}) async {
    _ensureInitialized();
    await _studyManager!.createReviewSession(limit: limit);
  }

  /// 创建收藏夹复习会话
  Future<void> createFavoriteReviewSession({int? limit}) async {
    _ensureInitialized();
    await _studyManager!.createFavoriteReviewSession(limit: limit);
  }

  /// 创建收藏夹学习会话（学习收藏夹里的所有卡，不区分状态）
  /// 进度计入总进度（endSession 会累加 learnedCards.length）
  Future<void> createFavoriteLearnSession({int? limit}) async {
    _ensureInitialized();
    await _studyManager!.createFavoriteLearnSession(limit: limit);
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
    print('[Provider] toggleFavorite uuid=$uuid card=${card?.conceptUuid ?? 'NULL'}');
    if (card == null) return false;
    final newVal = card.favorite == 1 ? 0 : 1;
    print('[Provider] toggleFavorite newVal=$newVal');
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
    final settings = await loadSettings();
    await _studyManager!.createLearnSession(limit: limit, bookId: settings.currentBook);
  }

  List<QuickLearnItemData> getQuickLearnItems() {
    return getSessionCards();
  }

  String getQuickLearnProgress() {
    final session = _studyManager?.currentSession;
    if (session == null) return '已标注 0/0 张';
    final known = session.learnedCards.length;
    return '已标注 $known/${session.total} 张';
  }

  Future<void> toggleQuickLearnKnown(int index) async {
    final session = _studyManager?.currentSession;
    if (session == null || index < 0 || index >= session.queue.length) return;

    final card = session.queue[index];
    final uuid = card.conceptUuid;

    // 查当前认识状态：优先查 learnedCards（已落盘的），其次查 Quick_Screen 表（仅内存标记的）
    final learnedSet = session.learnedCards.map((c) => c.conceptUuid).toSet();
    final screenRows = await _hotDb!.query(
      kTableQuickScreen,
      columns: ['Status'],
      where: 'Concept_UUID = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final isCurrentlyKnown = learnedSet.contains(uuid) ||
        (screenRows.isNotEmpty && (screenRows.first['Status'] as int) == 1);

    final willBeKnown = !isCurrentlyKnown;
    await toggleWordScreenStatus(_hotDb!, uuid, willBeKnown);
  }

  Future<void> loadNextQuickLearnPage() async {
    // QuickScreen 不需要翻页，全量在 queue 中通过列表显示
  }

  Future<void> loadPrevQuickLearnPage() async {
    // QuickScreen 不需要翻页，全量在 queue 中通过列表显示
  }

  bool hasNextQuickLearnPage() => false;

  bool hasPrevQuickLearnPage() => false;

  bool getQuickLearnIsAllDone() {
    final session = _studyManager?.currentSession;
    if (session == null) return true;
    return session.learnedCards.length >= session.total;
  }

  /// 从当前 StudySession 读取所有卡片，批量查询 Note，返回 QuickLearnItemData 列表
  /// 与 Ask 页面共用同一数据源（createLearnSession → queryNewCardsByBook）
  List<QuickLearnItemData> getSessionCards() {
    final session = _studyManager?.currentSession;
    if (session == null) return [];

    final learnedSet = session.learnedCards.map((c) => c.conceptUuid).toSet();
    return session.queue.asMap().entries.map((e) {
      final card = e.value;
      return QuickLearnItemData(
        index: e.key,
        conceptUuid: card.conceptUuid,
        spelling: '', // spelling 从 Note 中查询，异步加载
        isKnown: learnedSet.contains(card.conceptUuid),
      );
    }).toList();
  }

  /// 异步批量加载 Note 的 spelling，填充到 QuickLearnItemData 中
  Future<List<QuickLearnItemData>> getSessionCardsWithNote() async {
    final session = _studyManager?.currentSession;
    if (session == null) return [];

    final allUuids = session.queue.map((c) => c.conceptUuid).toList();
    final noteMap = await queryNotesBatch(_romDb!, allUuids);
    final learnedSet = session.learnedCards.map((c) => c.conceptUuid).toSet();

    // 查 Quick_Screen 表中的标记状态（仅内存标记，未落盘的）
    final screenRows = await _hotDb!.query(
      kTableQuickScreen,
      columns: ['Concept_UUID', 'Status'],
      where: 'Concept_UUID IN (${List.filled(allUuids.length, '?').join(',')})',
      whereArgs: allUuids,
    );
    final screenMap = <String, int>{};
    for (final row in screenRows) {
      final uuid = row['Concept_UUID'] as String;
      screenMap[uuid] = row['Status'] as int;
    }

    final items = <QuickLearnItemData>[];
    for (int i = 0; i < session.queue.length; i++) {
      final card = session.queue[i];
      final note = noteMap[card.conceptUuid];
      final learned = learnedSet.contains(card.conceptUuid);
      final screenStatus = screenMap[card.conceptUuid];
      final isKnown = learned || (screenStatus == 1);
      items.add(QuickLearnItemData(
        index: i,
        conceptUuid: card.conceptUuid,
        spelling: note?.spelling ?? '',
        isKnown: isKnown,
      ));
    }
    return items;
  }

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
      rootOrigin: root.origin,
      rootFunction: root.rootFunction,
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
        topicId: display.topicId,
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

  Future<bool> checkConceptExists(String conceptUuid) async {
    _ensureInitialized();
    return _topicManager!.conceptExists(conceptUuid);
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

  /// 根据专题和索引获取文章ID（0-based index）
  Future<String?> getArticleIdByIndex(String topicId, int index) async {
    _ensureInitialized();
    return _topicManager!.getArticleIdByIndex(topicId, index);
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
      if (note == null) {
        continue;
      }
      items.add(FavoriteItemData(
        conceptUuid: card.conceptUuid,
        spelling: note.spelling,
        phonetic: note.phonetic,
        definition: note.definition,
        isLearned: card.favoriteLearned == 1,
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
      currentBook: await querySetting(_hotDb!, 'current_book') ?? 'cet4',
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
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 词书数据（对应 SRS&SDD v2.1 附录 B）
  // -------------------------------------------------------------------------

  /// 加载所有词书列表
  Future<List<WordBookModel>> loadWordBooks() async {
    // 直接检查数据库引用，不调用 _ensureInitialized()（后者会抛异常）
    if (_hotDb == null) {
      print('[Backend] loadWordBooks: hotDb 未就绪，返回空列表');
      return [];
    }
    try {
      return await queryAllWordBooks(_hotDb!);
    } catch (e) {
      print('[Backend] loadWordBooks 异常: $e');
      return [];
    }
  }

  /// 获取词库诊断统计
  Future<Map<String, int>> getDatabaseStats() async {
    _ensureInitialized();
    return queryNoteStats(_romDb!);
  }

  // -------------------------------------------------------------------------
  // ReportsPage 数据
  // -------------------------------------------------------------------------

  Future<ReportsPageData> loadReportsData() async {
    _ensureInitialized();

    final now = DateTime.now().millisecondsSinceEpoch;
    final totalStudyTimeMs = int.tryParse(await querySetting(_hotDb!, 'total_study_time_ms') ?? '0') ?? 0;
    final totalStudyCount = int.tryParse(await querySetting(_hotDb!, 'total_study_count') ?? '0') ?? 0;
    final totalDays = int.tryParse(await querySetting(_hotDb!, 'total_study_days') ?? '0') ?? 0;
    final userName = await querySetting(_hotDb!, 'user_name') ?? '';
    final currentBook = await querySetting(_hotDb!, 'current_book') ?? 'cet4';
    final bookProgress = await queryBookProgress(_hotDb!, currentBook);
    final bookProgressCurrent = bookProgress?.current ?? 0;
    final bookProgressTotal = bookProgress?.total ?? 0;
    final allBookProgress = await queryAllBookProgress(_hotDb!);
    final dbStats = await queryNoteStats(_romDb!);

    final totalReviewCount = await queryTotalReviewCount(_hotDb!);
    final ratingDist = await queryTotalRatingDistribution(_hotDb!);
    final matureCount = await queryMatureCardCount(_hotDb!);
    final forgottenMatureCount = await queryMatureForgottenCount(_hotDb!);
    final backlogCount = await queryHistoricalBacklogCount(_hotDb!, now);

    return ReportsPageData(
      userName: userName,
      totalStudyTimeMs: totalStudyTimeMs,
      totalStudyCount: totalStudyCount,
      totalDays: totalDays,
      currentBook: currentBook,
      bookProgressCurrent: bookProgressCurrent,
      bookProgressTotal: bookProgressTotal,
      totalReviewCount: totalReviewCount,
      ratingDist: ratingDist,
      matureCount: matureCount,
      forgottenMatureCount: forgottenMatureCount,
      backlogCount: backlogCount,
      allBookProgress: allBookProgress,
      dbStats: dbStats,
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
  final String currentBook;
  final String? bookDisplayName;

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
    required this.currentBook,
    this.bookDisplayName,
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
  String get bookProgressText {
    final label = bookDisplayName ?? _bookLabel(currentBook);
    return '$label：$bookProgressCurrent/$bookProgressTotal';
  }
  String get totalStudyCountText => '累计学习$totalStudyCount次';
  String get totalDaysText => '累计${totalDays}天';
  String get dueCountText => '待复习$dueCount词';
  String get newCountText => '新词$newCount个';

  static String _bookLabel(String book) {
    switch (book) {
      case 'zk': return '中考';
      case 'gk': return '高考';
      case 'cet4': return 'CET4';
      case 'cet6': return 'CET6';
      case 'ky': return '考研';
      case 'kaoyan': return '考研';
      case 'kaoyan2027': return '2027考研';
      case 'toefl': return 'TOEFL';
      case 'ielts': return 'IELTS';
      case 'gre': return 'GRE';
      default: return book;
    }
  }
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
  final int collinsStar;
  final String? definitionEn;
  final String? pastTense;
  final String? pastParticiple;
  final String? presentParticiple;
  final String? thirdPerson;
  final String? comparative;
  final String? superlative;
  final String? plural;
  final String? lemma;
  final String? lemmaVariant;
  final String? tagList;      // JSON 数组字符串
  final String? synonymJson;   // 近义词辨析 JSON
  final int isOxford;
  final int oxford3000;
  final int oxford5000;

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
    this.collinsStar = 0,
    this.definitionEn,
    this.pastTense,
    this.pastParticiple,
    this.presentParticiple,
    this.thirdPerson,
    this.comparative,
    this.superlative,
    this.plural,
    this.lemma,
    this.lemmaVariant,
    this.tagList,
    this.synonymJson,
    this.isOxford = 0,
    this.oxford3000 = 0,
    this.oxford5000 = 0,
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

  /// 词根词缀 InlineSpan（数字部分为灰色上标），用于 RichText 显示
  InlineSpan get etymologySpans => formatEtymologyAsSpans(etymology);

  String get definitionText => formatTextWithNewlines(definition);

  /// 英语释义（处理 \n 换行）
  String? get definitionEnText =>
      definitionEn != null ? formatTextWithNewlines(definitionEn!) : null;
  String get favoriteButtonText => isFavorite ? '已收藏' : '收藏';
  String get againPercentText => _formatPct(againPct);
  String get hardPercentText => _formatPct(hardPct);
  String get goodPercentText => _formatPct(goodPct);
  String get easyPercentText => _formatPct(easyPct);
  String get contextText => formatTextWithNewlines(microContext);
  String get progressText => progress;

  /// 科林斯星级（始终显示）
  String get collinsStarText => 'collinsStar:$collinsStar';

  /// 完整时态显示（过去式/过去分词/现在分词/三单/比较级/最高级/复数）
  String get fullTenseText {
    final parts = <String>[];
    if (pastTense?.isNotEmpty == true) parts.add('过去式: $pastTense');
    if (pastParticiple?.isNotEmpty == true) parts.add('过去分词: $pastParticiple');
    if (presentParticiple?.isNotEmpty == true) parts.add('现在分词: $presentParticiple');
    if (thirdPerson?.isNotEmpty == true) parts.add('三单: $thirdPerson');
    if (comparative?.isNotEmpty == true) parts.add('比较级: $comparative');
    if (superlative?.isNotEmpty == true) parts.add('最高级: $superlative');
    if (plural?.isNotEmpty == true) parts.add('复数: $plural');
    if (lemma?.isNotEmpty == true) parts.add('原型: $lemma');
    return parts.join('  ');
  }

  /// 兼容旧字段（保留用于现有 widget）
  String get tenseText => fullTenseText;

  /// 近义词分组标题
  String? get synonymGroupTitleText {
    if (synonymJson == null || synonymJson!.isEmpty) return null;
    try {
      final Map<String, dynamic> data = jsonDecode(synonymJson!);
      return data['title'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// 近义词辨析详情（格式化后的文本）
  String? get synonymDetailText {
    if (synonymJson == null || synonymJson!.isEmpty) return null;
    try {
      final Map<String, dynamic> data = jsonDecode(synonymJson!);
      final detail = data['detail'] as Map<String, dynamic>?;
      if (detail == null || detail.isEmpty) return null;
      return detail.entries.map((e) => '- ${e.key}: ${e.value}').join('\n');
    } catch (_) {
      return null;
    }
  }

  /// 词书标签显示
  String? get tagListText {
    if (tagList == null || tagList!.isEmpty) return null;
    try {
      final List<dynamic> tags = jsonDecode(tagList!);
      return tags.map((t) => '[$t]').join(' ');
    } catch (_) {
      return null;
    }
  }

  /// Oxford 徽章文字
  String? get oxfordBadgeText {
    if (oxford5000 > 0) return '牛津5000';
    if (oxford3000 > 0) return '牛津3000';
    if (isOxford > 0) return 'Oxford';
    return null;
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
  final String rootOrigin;
  final String rootFunction;   // 构词说明（新增）
  final List<TreeWordDisplayModel> words;

  TreePageData({
    required this.rootId,
    required this.rootName,
    required this.rootDefinition,
    required this.rootOrigin,
    required this.rootFunction,
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
  final String topicId;
  final String topicName;
  final String wordCountText;
  final String readCountText;
  final List<TextSpanData> segments;

  TopicReadingPageData({
    required this.articleId,
    required this.topicId,
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
  final bool isLearned;

  FavoriteItemData({
    required this.conceptUuid,
    required this.spelling,
    required this.phonetic,
    required this.definition,
    required this.isLearned,
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
  final int totalReviewCount;
  final Map<int, int> ratingDist;
  final int matureCount;
  final int forgottenMatureCount;
  final int backlogCount;
  final List<BookProgressModel> allBookProgress;
  final Map<String, int> dbStats;

  ReportsPageData({
    required this.userName,
    required this.totalStudyTimeMs,
    required this.totalStudyCount,
    required this.totalDays,
    required this.currentBook,
    required this.bookProgressCurrent,
    required this.bookProgressTotal,
    required this.totalReviewCount,
    required this.ratingDist,
    required this.matureCount,
    required this.forgottenMatureCount,
    required this.backlogCount,
    required this.allBookProgress,
    required this.dbStats,
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
  String get bookProgressText {
    final books = allBookProgress;
    if (books.isEmpty) return '--';
    final total = dbStats['total'] ?? 0;
    return books.map((b) => '${_bookLabel(b.bookId)} ${b.current}/$total').join(' | ');
  }

  int get _again => ratingDist[1] ?? 0;
  int get _hard => ratingDist[2] ?? 0;
  int get _good => ratingDist[3] ?? 0;
  int get _easy => ratingDist[4] ?? 0;

  String get totalReviewCountText => '累计复习：${totalReviewCount}词';

  String get ratingDistributionText {
    if (totalReviewCount == 0) return 'again:0% | hard:0% | good:0% | easy:0%';
    final againP = (_again * 100 / totalReviewCount).toStringAsFixed(0);
    final hardP = (_hard * 100 / totalReviewCount).toStringAsFixed(0);
    final goodP = (_good * 100 / totalReviewCount).toStringAsFixed(0);
    final easyP = (_easy * 100 / totalReviewCount).toStringAsFixed(0);
    return 'again:$againP% | hard:$hardP% | good:$goodP% | easy:$easyP%';
  }

  /// 成熟转化率 = 成熟词汇数 / 累计学习数
  /// 含义："新词"平均需要经历多少次按键才能转化为"成熟"状态
  String get matureRateText {
    if (totalStudyCount == 0) return '成熟转化率：--%';
    final rate = (matureCount * 100 / totalStudyCount).toStringAsFixed(1);
    return '成熟转化率：$rate%';
  }

  /// 成熟词汇失忆率 = 成熟卡被 Again 的次数 / 成熟卡总数
  /// 含义：已经进入长期记忆区（间隔 > 21天）的词被遗忘的概率
  String get forgotRateText {
    if (matureCount == 0) return '成熟词汇失忆率：--%';
    final rate = (forgottenMatureCount * 100 / matureCount).toStringAsFixed(1);
    return '成熟词汇失忆率：$rate%';
  }

  /// 认知吞吐量 = 累计复习次数 / 学习时长（分钟）
  /// 含义：每分钟处理的词条数
  String get throughputText {
    final minutes = totalStudyTimeMs / 60000;
    if (minutes <= 0) return '认知吞吐量：--词/min';
    final t = totalReviewCount / minutes;
    return '认知吞吐量：${t.toStringAsFixed(1)}词/min';
  }

  /// 历史积压复习量：超过理想复习时间但仍未复习的词汇绝对数量
  String get backlogText => '历史积压复习量：${backlogCount}词';

  String _bookLabel(String book) {
    switch (book) {
      case 'zk': return '中考';
      case 'gk': return '高考';
      case 'cet4': return 'CET4';
      case 'cet6': return 'CET6';
      case 'ky': return '考研';
      case 'kaoyan': return '考研';
      case 'kaoyan2027': return '2027考研';
      case 'toefl': return 'TOEFL';
      case 'ielts': return 'IELTS';
      case 'gre': return 'GRE';
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
