library wordmemory.study;

import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'fsrs.dart';

// ============================================================================
// WordMemory SRS - 学习会话管理
// ============================================================================

enum StudyMode {
  review,
  learn,
  quickScreen,
  favorite,
}

class StudySession {
  final StudyMode mode;
  final List<CardModel> queue;
  int currentIndex;
  int sessionStartTime;
  final List<CardModel> learnedCards;

  /// Ask 已选但未落盘的评级（Learn 确定后才写入 DB）
  int? pendingRating;
  /// pending 对应的预览计算结果（仅存在内存，不写 DB）
  CardModel? pendingPreviewCard;

  StudySession({
    required this.mode,
    required this.queue,
    this.currentIndex = 0,
    int? sessionStartTime,
  })  : sessionStartTime = sessionStartTime ?? DateTime.now().millisecondsSinceEpoch,
        learnedCards = [];

  CardModel? get currentCard =>
      currentIndex < queue.length ? queue[currentIndex] : null;

  bool get hasNext => currentIndex < queue.length - 1;
  bool get isEmpty => queue.isEmpty;
  int get progress => currentIndex + 1;
  int get total => queue.length;
  int get remaining => queue.length - currentIndex - 1;

  void advance() {
    if (hasNext) currentIndex++;
  }

  void addLearned(CardModel card) {
    learnedCards.add(card);
  }

  void clearPending() {
    pendingRating = null;
    pendingPreviewCard = null;
  }
}

class StudySessionManager {
  final Database hotDb;
  final Database romDb;
  final FSRSCalculator fsrs;

  StudySession? _currentSession;

  StudySessionManager({
    required this.hotDb,
    required this.romDb,
    FSRSCalculator? fsrsCalc,
  }) : fsrs = fsrsCalc ?? FSRSCalculator();

  StudySession? get currentSession => _currentSession;

  Future<StudySession> createReviewSession({int? limit}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dueCards = await queryDueCards(hotDb, now);
    final limited = limit != null && dueCards.length > limit
        ? dueCards.sublist(0, limit)
        : dueCards;
    _currentSession = StudySession(mode: StudyMode.review, queue: limited);
    return _currentSession!;
  }

  Future<StudySession> createLearnSession({int? limit}) async {
    print('[Study] createLearnSession 开始');
    final newCards = await queryNewCards(hotDb, limit: limit);
    print('[Study] queryNewCards 完成, 共 ${newCards.length} 张卡');
    _currentSession = StudySession(mode: StudyMode.learn, queue: newCards);
    return _currentSession!;
  }

  Future<StudySession> createQuickScreenSession({int? limit}) async {
    final newCards = await queryNewCards(hotDb, limit: limit);
    _currentSession = StudySession(mode: StudyMode.quickScreen, queue: newCards);
    return _currentSession!;
  }

  Future<StudySession> createFavoriteSession({int? limit}) async {
    var favCards = await queryFavoriteCards(hotDb);
    if (limit != null && favCards.length > limit) {
      favCards = favCards.sublist(0, limit);
    }
    _currentSession = StudySession(mode: StudyMode.favorite, queue: favCards);
    return _currentSession!;
  }

  Future<CardModel?> submitRating(int rating, {bool shouldAdvance = true}) async {
    if (_currentSession == null) return null;
    final current = _currentSession!.currentCard;
    if (current == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;

    if (_currentSession!.mode == StudyMode.quickScreen) {
      await markWordAsKnown(hotDb, current.conceptUuid, now);
      if (shouldAdvance) _currentSession!.advance();
      _currentSession!.addLearned(current);
      return shouldAdvance ? _currentSession!.currentCard : current;
    }

    final nextCard = fsrs.calculateNextState(
      card: current,
      rating: rating,
      currentTime: now,
    );
    // 记录本次复习时间，用于后续计算 R 值：R(t,S) = 1/(1+t/(9S))，t = now - lastReviewDate
    nextCard.lastReviewDate = now;

    final log = createReviewLog(
      card: current,
      rating: rating,
      currentTime: now,
    );
    final logId = await insertReviewLog(hotDb, log);
    nextCard.lastReviewLogId = logId;

    await upsertCard(hotDb, nextCard);

    final currentCount = await querySettingInt(hotDb, 'total_study_count') ?? 0;
    await setSettingInt(hotDb, 'total_study_count', currentCount + 1);

    _currentSession!.addLearned(nextCard);

    // 无论是否 advance，都要把新卡写回队列，这样后续 getCurrentCardWithDetails
    // 能读到更新后的 s/r 值；advance 时再把指针移到下一张
    _currentSession!.queue[_currentSession!.currentIndex] = nextCard;

    if (shouldAdvance) {
      _currentSession!.advance();
      return _currentSession!.currentCard;
    }
    return nextCard;
  }

  Future<CardModel?> undo() async {
    if (_currentSession == null) return null;

    // Ask 评级后未确认就 undo：仅清除 pending，无 DB 操作
    if (_currentSession!.pendingPreviewCard != null) {
      _currentSession!.clearPending();
      return _currentSession!.currentCard;
    }

    if (_currentSession!.currentIndex > 0) {
      _currentSession!.currentIndex--;
      // 内存撤销：当前队列的卡已被 submitRating 覆盖为新卡，
      // 需要从数据库恢复旧状态（lastReviewDate / s / r 均回退到评级前）
      final prevCard = _currentSession!.currentCard;
      final restored = await queryCardByUuid(hotDb, prevCard!.conceptUuid);
      if (restored != null) {
        // 删除本次评级写入的 Review_Log 条目（精准删除，不影响其他条）
        if (prevCard.lastReviewLogId != null) {
          await deleteReviewLogById(hotDb, prevCard.lastReviewLogId!);
        }
        _currentSession!.queue[_currentSession!.currentIndex] = restored;
      }
      return _currentSession!.currentCard;
    }
    return undoLastOperation(hotDb);
  }

  Future<SessionStats> endSession() async {
    if (_currentSession == null) {
      return SessionStats(
        totalCards: 0,
        newCards: 0,
        reviewCards: 0,
        relearnCards: 0,
        ratingDistribution: {},
        avgStabilityChange: 0,
        avgRetrievabilityChange: 0,
        learnedSpellings: [],
      );
    }

    final session = _currentSession!;
    final endTime = DateTime.now().millisecondsSinceEpoch;

    final stats = await calculateSessionStats(
      hotDb: hotDb,
      romDb: romDb,
      sessionStartTime: session.sessionStartTime,
      sessionEndTime: endTime,
    );

    final duration = endTime - session.sessionStartTime;
    final totalTime = await querySettingInt(hotDb, 'total_study_time_ms') ?? 0;
    await setSettingInt(hotDb, 'total_study_time_ms', totalTime + duration);

    final localDate = calculateLocalDateStr(endTime);
    final lastStudyDate = await querySetting(hotDb, 'last_study_date');
    if (lastStudyDate != localDate) {
      // 新逻辑日：重置今日时长
      await setSettingInt(hotDb, 'today_study_time_ms', duration);
      final days = await querySettingInt(hotDb, 'total_study_days') ?? 0;
      await setSettingInt(hotDb, 'total_study_days', days + 1);
      await setSetting(hotDb, 'last_study_date', localDate);
    } else {
      // 同一逻辑日：累加今日时长
      final todayTime = await querySettingInt(hotDb, 'today_study_time_ms') ?? 0;
      await setSettingInt(hotDb, 'today_study_time_ms', todayTime + duration);
    }

    final bookCurrent = await querySettingInt(hotDb, 'book_progress_current') ?? 0;
    await setSettingInt(hotDb, 'book_progress_current',
        bookCurrent + session.learnedCards.length);

    _currentSession = null;

    return stats;
  }

  /// Ask 评级（纯预览，只读不落盘）
  /// 计算预览结果存入 pendingPreviewCard，返回详情供 Learn 页面显示
  Future<Map<String, dynamic>?> previewRating(int rating) async {
    if (_currentSession == null) return null;
    final card = _currentSession!.currentCard;
    if (card == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;

    // 纯计算，无 DB 写入
    final previewCard = fsrs.calculateNextState(
      card: card,
      rating: rating,
      currentTime: now,
    );
    previewCard.lastReviewDate = now;
    // pendingPreviewCard 仅存内存，不写 lastReviewLogId

    _currentSession!.pendingRating = rating;
    _currentSession!.pendingPreviewCard = previewCard;

    // 构建详情（preview 时 R 固定 100%）
    return _buildCardDetails(previewCard, card, _currentSession!.progress, isPreview: true);
  }

  /// Learn 确定评级（落盘 + 推进）
  /// 无论用户选的 rating 是否与 Ask 相同，都走这里落盘
  Future<CardModel?> confirmPendingRating(int rating) async {
    if (_currentSession == null) return null;

    print('[Confirm] pendingPreviewCard=${_currentSession?.pendingPreviewCard != null}, rating=$rating, mode=${_currentSession?.mode}');

    if (_currentSession!.pendingPreviewCard != null) {
      // 新流程：Ask→Learn 单落盘
      final current = _currentSession!.currentCard;
      if (current == null) return null;
      final now = DateTime.now().millisecondsSinceEpoch;

      // 重新计算（可能用户在 Learn 换了评级）
      final confirmedCard = fsrs.calculateNextState(
        card: current,
        rating: rating,
        currentTime: now,
      );
      confirmedCard.lastReviewDate = now;

      // 落盘：生成 Review_Log 快照并写入
      final log = createReviewLog(card: current, rating: rating, currentTime: now);
      final logId = await insertReviewLog(hotDb, log);
      print('[Confirm] Log created, logDate=$now');
      confirmedCard.lastReviewLogId = logId;
      await upsertCard(hotDb, confirmedCard);

      final currentCount = await querySettingInt(hotDb, 'total_study_count') ?? 0;
      await setSettingInt(hotDb, 'total_study_count', currentCount + 1);

      _currentSession!.learnedCards.add(confirmedCard);
      _currentSession!.queue[_currentSession!.currentIndex] = confirmedCard;

      // 清除 pending，推进到下一张
      _currentSession!.clearPending();
      _currentSession!.advance();
      return _currentSession!.currentCard;
    }

    // Fallback：没有 pendingPreviewCard，说明 Ask 评级流程未执行，
    // 此时走旧 submitRating 逻辑（shouldAdvance=true）
    return submitRating(rating, shouldAdvance: true);
  }

  Future<Map<String, dynamic>?> getCurrentCardWithDetails() async {
    if (_currentSession == null) return null;
    final card = _currentSession!.currentCard;
    if (card == null) return null;

    // Ask 已评级但 Learn 尚未确定：显示预览卡（此时 R=100%）
    if (_currentSession!.pendingPreviewCard != null) {
      return _buildCardDetails(
          _currentSession!.pendingPreviewCard!, card, _currentSession!.progress, isPreview: true);
    }

    // 正常显示（Ask/Learn 两页面共用）
    final note = await queryNoteByUuid(romDb, card.conceptUuid);
    if (note == null) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final status = _getCardStatus(card);
    final nextReview = fsrs.formatNextReview(card.nextReviewDate, now);

    // 全新卡（首次见）：R=100%
    if (card.status == CardStatus.newCard) {
      return {
        'card': card,
        'note': note,
        'progress': '${_currentSession!.progress}/${_currentSession!.total}',
        'nextReview': nextReview,
        'nextReviewDays': _daysUntilReview(card.nextReviewDate, now),
        'ratingDistribution': <String, double>{
          'again': 0,
          'hard': 0,
          'good': 0,
          'easy': 0,
        },
        'stabilityDays': 0.0,
        'retrievabilityPct': 100.0,
        'status': status,
        'againPct': 0.0,
        'hardPct': 0.0,
        'goodPct': 0.0,
        'easyPct': 0.0,
      };
    }

    // 查询历史评级分布
    final ratingDistMap = await queryRatingDistributionByUuid(hotDb, card.conceptUuid);
    int total = 0;
    for (final v in ratingDistMap.values) {
      total += v;
    }
    Map<String, double> ratingDist;
    if (total == 0) {
      ratingDist = <String, double>{
        'again': 0.0,
        'hard': 0.0,
        'good': 0.0,
        'easy': 0.0,
      };
    } else {
      ratingDist = {
        'again': total > 0 ? (ratingDistMap[FSRSCardRating.again] ?? 0) / total * 100 : 0,
        'hard':  total > 0 ? (ratingDistMap[FSRSCardRating.hard]  ?? 0) / total * 100 : 0,
        'good':  total > 0 ? (ratingDistMap[FSRSCardRating.good]  ?? 0) / total * 100 : 0,
        'easy':  total > 0 ? (ratingDistMap[FSRSCardRating.easy]  ?? 0) / total * 100 : 0,
      };
    }

    print('[CardDetails] conceptUuid=${card.conceptUuid}, ratingDist=$ratingDist');

    // 复习卡：R 按 FSRS 公式实时计算
    final lastReviewLog = await queryLastReviewLogByUuid(hotDb, card.conceptUuid);
    final double lastReviewMs = (lastReviewLog?.logDate ?? card.lastReviewDate).toDouble();
    final double t = lastReviewMs > 0 ? (now - lastReviewMs) / 86400000.0 : 0.0;
    final double retrievabilityPct = fsrs.retrievability(t, card.s);

    return {
      'card': card,
      'note': note,
      'progress': '${_currentSession!.progress}/${_currentSession!.total}',
      'nextReview': nextReview,
      'nextReviewDays': _daysUntilReview(card.nextReviewDate, now),
      'ratingDistribution': ratingDist,
      'stabilityDays': card.s,
      'retrievabilityPct': retrievabilityPct,
      'status': status,
      'againPct': ratingDist['again'] ?? 0,
      'hardPct': ratingDist['hard'] ?? 0,
      'goodPct': ratingDist['good'] ?? 0,
      'easyPct': ratingDist['easy'] ?? 0,
    };
  }

  /// 构建卡片详情 Map（由 getCurrentCardWithDetails 和 previewRating 共享）
  Future<Map<String, dynamic>> _buildCardDetails(
    CardModel baseCard,
    CardModel originalCard,
    int progress, {
    bool isPreview = false,
  }) async {
    final note = await queryNoteByUuid(romDb, baseCard.conceptUuid);
    if (note == null) {
      return {};
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final status = _getCardStatus(baseCard);
    final nextReview = fsrs.formatNextReview(baseCard.nextReviewDate, now);

    // preview 状态（遗忘尚未发生）：R 固定 100%，但评级分布从 DB 查真实历史
    if (isPreview) {
      final ratingDistMap = await queryRatingDistributionByUuid(hotDb, baseCard.conceptUuid);
      int total = 0;
      for (final v in ratingDistMap.values) total += v;
      final ratingDist = <String, double>{
        'again': total > 0 ? (ratingDistMap[FSRSCardRating.again] ?? 0) / total * 100 : 0.0,
        'hard':  total > 0 ? (ratingDistMap[FSRSCardRating.hard]  ?? 0) / total * 100 : 0.0,
        'good':  total > 0 ? (ratingDistMap[FSRSCardRating.good]  ?? 0) / total * 100 : 0.0,
        'easy':  total > 0 ? (ratingDistMap[FSRSCardRating.easy]  ?? 0) / total * 100 : 0.0,
      };
      // 全新卡无历史：preview 时按当前用户选中的评级填充分布
      if (total == 0 && _currentSession!.pendingRating != null) {
        final pr = _currentSession!.pendingRating!;
        ratingDist['again'] = pr == FSRSCardRating.again ? 100.0 : 0.0;
        ratingDist['hard']  = pr == FSRSCardRating.hard  ? 100.0 : 0.0;
        ratingDist['good']  = pr == FSRSCardRating.good  ? 100.0 : 0.0;
        ratingDist['easy']  = pr == FSRSCardRating.easy  ? 100.0 : 0.0;
      }
      return {
        'card': baseCard,
        'note': note,
        'progress': '$progress/${_currentSession!.total}',
        'nextReview': nextReview,
        'nextReviewDays': _daysUntilReview(baseCard.nextReviewDate, now),
        'ratingDistribution': ratingDist,
        'stabilityDays': baseCard.s,
        'retrievabilityPct': 100.0,
        'status': status,
        'againPct': ratingDist['again'] ?? 0,
        'hardPct': ratingDist['hard'] ?? 0,
        'goodPct': ratingDist['good'] ?? 0,
        'easyPct': ratingDist['easy'] ?? 0,
      };
    }

    // 正常复习卡：R 按公式算
    final ratingDistMap = await queryRatingDistributionByUuid(hotDb, baseCard.conceptUuid);
    int total = 0;
    for (final v in ratingDistMap.values) total += v;
    Map<String, double> ratingDist = {
      'again': total > 0 ? (ratingDistMap[FSRSCardRating.again] ?? 0) / total * 100 : 0.0,
      'hard':  total > 0 ? (ratingDistMap[FSRSCardRating.hard]  ?? 0) / total * 100 : 0.0,
      'good':  total > 0 ? (ratingDistMap[FSRSCardRating.good]  ?? 0) / total * 100 : 0.0,
      'easy':  total > 0 ? (ratingDistMap[FSRSCardRating.easy]  ?? 0) / total * 100 : 0.0,
    };
    final lastReviewLog = await queryLastReviewLogByUuid(hotDb, baseCard.conceptUuid);
    final double lastReviewMs = (lastReviewLog?.logDate ?? baseCard.lastReviewDate).toDouble();
    final double t = lastReviewMs > 0 ? (now - lastReviewMs) / 86400000.0 : 0.0;
    final double retrievabilityPct = fsrs.retrievability(t, baseCard.s);

    return {
      'card': baseCard,
      'note': note,
      'progress': '$progress/${_currentSession!.total}',
      'nextReview': nextReview,
      'nextReviewDays': _daysUntilReview(baseCard.nextReviewDate, now),
      'ratingDistribution': ratingDist,
      'stabilityDays': baseCard.s,
      'retrievabilityPct': retrievabilityPct,
      'status': status,
      'againPct': ratingDist['again'] ?? 0,
      'hardPct': ratingDist['hard'] ?? 0,
      'goodPct': ratingDist['good'] ?? 0,
      'easyPct': ratingDist['easy'] ?? 0,
    };
  }

  String _getCardStatus(CardModel card) {
    if (card.status == 0) return 'new';
    if (card.status == 1) return 'learning';
    if (card.status == 2) return 'reviewing';
    return 'relearning';
  }

  int _daysUntilReview(int nextReviewDate, int now) {
    final diffMs = nextReviewDate - now;
    if (diffMs <= 0) return 0;
    return (diffMs / 86400000).ceil();
  }
}

// ============================================================================
// QuickLearn 快速筛选
// ============================================================================

enum QuickScreenItemStatus { unmarked, known }

class QuickScreenItem {
  final String conceptUuid;
  final String spelling;
  QuickScreenItemStatus status;

  QuickScreenItem({
    required this.conceptUuid,
    required this.spelling,
    this.status = QuickScreenItemStatus.unmarked,
  });
}

class QuickScreenManager {
  final Database hotDb;
  final Database romDb;

  QuickScreenManager({required this.hotDb, required this.romDb});

  List<QuickScreenItem> _items = [];
  int _knownCount = 0;

  List<QuickScreenItem> get items => _items;
  int get knownCount => _knownCount;
  int get total => _items.length;
  int get remaining => _items.length - _knownCount;

  Future<void> initSession({int? limit}) async {
    final newCards = await queryNewCards(hotDb, limit: limit);
    final knownUuids = await queryKnownUuids(hotDb);

    _items = [];
    _knownCount = 0;

    for (final card in newCards) {
      final note = await queryNoteByUuid(romDb, card.conceptUuid);
      if (note == null) continue;

      final isKnown = knownUuids.contains(card.conceptUuid);
      _items.add(QuickScreenItem(
        conceptUuid: card.conceptUuid,
        spelling: note.spelling,
        status: isKnown
            ? QuickScreenItemStatus.known
            : QuickScreenItemStatus.unmarked,
      ));
      if (isKnown) _knownCount++;
    }
  }

  Future<void> markAsKnown(int index) async {
    if (index < 0 || index >= _items.length) return;
    if (_items[index].status == QuickScreenItemStatus.known) return;

    _items[index].status = QuickScreenItemStatus.known;
    _knownCount++;

    final now = DateTime.now().millisecondsSinceEpoch;
    await markWordAsKnown(hotDb, _items[index].conceptUuid, now);
  }

  String get progressText => '已筛选:$_knownCount/$total';
  bool get isAllDone => _knownCount >= _items.length;
}

// ============================================================================
// 结构树访问（仅供浏览，不计入进度）
// ============================================================================

class TreeManager {
  final Database hotDb;
  final Database romDb;

  TreeManager({required this.hotDb, required this.romDb});

  Future<List<String>> getAllGroups() async {
    final roots = await queryAllTreeRoots(romDb);
    final groups = roots.map((r) => r.rootGroup).toSet().toList();
    groups.sort();
    return groups;
  }

  Future<List<TreeRootModel>> getRootsByGroup(String group) async {
    return queryTreeRootsByGroup(romDb, group);
  }

  Future<TreeRootModel?> getRootById(String rootId) async {
    return queryTreeRootById(romDb, rootId);
  }

  Future<List<TreeWordDisplayModel>> getWordsByRoot(String rootId) async {
    final words = await queryTreeWordsByRoot(romDb, rootId);
    final displays = <TreeWordDisplayModel>[];

    for (final word in words) {
      final note = await queryNoteByUuid(romDb, word.conceptUuid);
      displays.add(TreeWordDisplayModel(
        conceptUuid: word.conceptUuid,
        compoundForm: word.compoundForm,
        compoundMeaning: word.compoundMeaning,
        finalMeaning: word.finalMeaning,
        spelling: note?.spelling ?? word.compoundForm,
      ));
    }

    return displays;
  }

  Future<void> visitWord(String conceptUuid) async {
    await updateCardTreeVisit(hotDb, conceptUuid);
  }
}

class TreeWordDisplayModel {
  final String conceptUuid;
  final String compoundForm;
  final String compoundMeaning;
  final String finalMeaning;
  final String spelling;

  TreeWordDisplayModel({
    required this.conceptUuid,
    required this.compoundForm,
    required this.compoundMeaning,
    required this.finalMeaning,
    required this.spelling,
  });

  String get renderString =>
      '$compoundForm=$compoundMeaning=$finalMeaning';
}

// ============================================================================
// 话题阅读（仅供浏览，不计入进度）
// ============================================================================

class TopicReadingManager {
  final Database hotDb;
  final Database romDb;

  TopicReadingManager({required this.hotDb, required this.romDb});

  Future<List<TopicModel>> getAllTopics() async {
    return queryAllTopics(romDb);
  }

  Future<List<ArticleModel>> getArticlesByTopic(String topicId) async {
    return queryArticlesByTopic(romDb, topicId);
  }

  Future<ArticleDisplayModel?> getArticleDisplay(String articleId) async {
    final articles = await romDb.query(
      kTableArticle,
      where: 'Article_ID = ?',
      whereArgs: [articleId],
      limit: 1,
    );
    if (articles.isEmpty) return null;

    final article = ArticleModel.fromMap(articles.first);
    final topic = await romDb.query(
      kTableTopic,
      where: 'Topic_ID = ?',
      whereArgs: [article.topicId],
      limit: 1,
    );
    if (topic.isEmpty) return null;

    final topicModel = TopicModel.fromMap(topic.first);
    final readCount = await _countTopicReadUuids(article.contentJson);
    final segments = _parseContentJson(article.contentJson);

    return ArticleDisplayModel(
      articleId: article.articleId,
      topicName: topicModel.topicName,
      wordCount: article.wordCount,
      readCount: readCount,
      segments: segments,
    );
  }

  Future<int> _countTopicReadUuids(String contentJson) async {
    try {
      final segments = _parseContentJson(contentJson);
      int count = 0;
      for (final seg in segments) {
        if (seg['c'] == 1 && seg['u'] != null) {
          final card = await queryCardByUuid(hotDb, seg['u'] as String);
          if (card != null && card.topicRead == 1) count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  List<Map<String, dynamic>> _parseContentJson(String json) {
    try {
      final decoded = _jsonDecode(json);
      if (decoded is! List) return [];
      return decoded.map((e) {
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> visitWord(String conceptUuid) async {
    await updateCardTopicRead(hotDb, conceptUuid);
  }
}

class ArticleDisplayModel {
  final String articleId;
  final String topicName;
  final int wordCount;
  final int readCount;
  final List<Map<String, dynamic>> segments;

  ArticleDisplayModel({
    required this.articleId,
    required this.topicName,
    required this.wordCount,
    required this.readCount,
    required this.segments,
  });

  String get wordCountText => '词汇命中数:$wordCount';
  String get readCountText => '已学习$readCount/$wordCount';
}

// ============================================================================
// 简单 JSON 解析器
// ============================================================================

dynamic _jsonDecode(String str) {
  return _jsonDecodeImpl(str, 0).value;
}

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
    if (pos < s.length && s[pos] == '\\' && pos + 1 < s.length) {
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
