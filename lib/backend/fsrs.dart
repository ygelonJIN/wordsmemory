library wordmemory.fsrs;

import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'database.dart' as db;

// ============================================================================
// WordMemory SRS - FSRS v4 Algorithm Implementation
// 对应文档：词汇SRS&SDD v2.1 第 5 节
// ============================================================================

/// FSRS v4 17 维权重常量数组
class FSRSWeights {
  static const List<double> defaultW = [
    0.4, 0.6, 2.4, 5.8, 4.93, 0.94, 0.86, 0.01,
    1.49, 0.14, 0.94, 2.18, 0.05, 0.34, 1.26, 0.29, 2.61
  ];

  // 各权重索引别名（方便代码可读性）
  static const int W4 = 4; // D 初始化系数
  static const int W5 = 5; // D 衰减系数
  static const int W6 = 6;
  static const int W7 = 7;
  static const int W8 = 8;
  static const int W9 = 9;
  static const int W10 = 10;
  static const int W11 = 11; // S_forget 系数
  static const int W12 = 12; // D 幂次
  static const int W13 = 13; // S 幂次
  static const int W14 = 14; // R 幂次
  static const int W15 = 15;
  static const int W16 = 16;
}

/// FSRS 评级
class FSRSCardRating {
  static const int again = 1;
  static const int hard = 2;
  static const int good = 3;
  static const int easy = 4;
}

/// FSRS 计算器
class FSRSCalculator {
  final List<double> w;

  FSRSCalculator({List<double>? weights}) : w = weights ?? FSRSWeights.defaultW;

  /// 可提取性 (Retrievability) 衰减函数
  /// t = 距离上次复习的过去天数
  /// S = Stability（稳定性）
  /// 返回值: 0.0 ~ 1.0
  double retrievability(double t, double S) {
    if (S <= 0) return 0.0;
    return 1.0 / (1.0 + t / (9.0 * S));
  }

  /// 难度 (Difficulty) 初始化函数
  /// G = 评级 (1=Again, 2=Hard, 3=Good, 4=Easy)
  /// D0(G) = w4 - e^(w5 * (G-1)) + 1
  double initialDifficulty(int G) {
    // D0(G) = w4 - exp(w5 * (G - 1)) + 1
    final expVal = exp(w[FSRSWeights.W5] * (G - 1));
    return w[FSRSWeights.W4] - expVal + 1.0;
  }

  /// 遗忘稳定性 (Forget Stability) 衰减函数
  /// S_forget = w11 * D^(-w12) * S^(w13) * e^(w14 * (1-R))
  double forgetStability(double D, double S, double R) {
    final dPow = pow(D, -w[FSRSWeights.W12]);
    final sPow = pow(S, w[FSRSWeights.W13]);
    final rExp = exp(w[FSRSWeights.W14] * (1.0 - R));
    return w[FSRSWeights.W11] * dPow * sPow * rExp;
  }

  /// 下限约束：任何涉及 S 的衰减计算后，必须执行 S = max(S, 0.1)
  double clampStability(double S) => max(S, 0.1);

  /// 时间戳转换计算
  /// Next_Review_Date = Current_Time + floor(S * 86400000)
  int nextReviewDate(int currentTime, double S) {
    return currentTime + (S * 86400000).floor();
  }

  /// 判断是否在宽容窗口内（Relearning 后 12 小时内成功）
  bool withinForgivenessWindow(int lastFailTime, int currentTime) {
    return (currentTime - lastFailTime) < 12 * 60 * 60 * 1000; // 12 小时
  }

  /// 完整状态流转计算
  /// 输入：当前卡片状态、评级、当前时间、上次失败时间戳
  /// 返回：更新后的 db.CardModel
  db.CardModel calculateNextState({
    required db.CardModel card,
    required int rating,
    required int currentTime,
    int? lastFailTime,
  }) {
    // 备份当前状态（用于 Review_Log）
    final preStatus = card.status;
    final preR = card.r;
    final preS = card.s;

    // 计算当前 R
    // t = distance in days since last review; clamp to 0 when scheduled in future (t < 0)
    final double t = max(0.0, (currentTime - card.nextReviewDate) / 86400000.0);
    final double currentR = retrievability(t, card.s);

    db.CardModel newCard = db.CardModel(
      cardId: card.cardId,
      conceptUuid: card.conceptUuid,
      status: card.status,
      nextReviewDate: card.nextReviewDate,
      lastReviewDate: card.lastReviewDate,
      r: currentR,
      s: card.s,
      failCount: card.failCount,
      favorite: card.favorite,
      topicRead: card.topicRead,
      treeVisit: card.treeVisit,
      randomSortId: card.randomSortId,
    );

    // ---- 状态流转矩阵（对应文档 5.2 节）----
    switch (card.status) {
      case db.CardStatus.newCard:
        // 所有评级 (1-4)：Status -> 1 (Learning)
        // 初始化 S = w(G-1)，D = D0(G)
        newCard.status = db.CardStatus.learning;
        newCard.s = w[rating - 1]; // Again=1 -> w0, Good=3 -> w2
        newCard.s = clampStability(newCard.s);
        final D = initialDifficulty(rating);
        newCard.nextReviewDate = nextReviewDate(currentTime, newCard.s);
        break;

      case db.CardStatus.learning:
        if (rating == FSRSCardRating.good) {
          // Good(3)：Status -> 2 (Review)
          newCard.status = db.CardStatus.review;
          newCard.s = _calculateSuccessStability(rating, card.s, currentR);
          newCard.s = clampStability(newCard.s);
          newCard.nextReviewDate = nextReviewDate(currentTime, newCard.s);
        } else if (rating == FSRSCardRating.again) {
          // Again(1)：Status 维持 1，延后 5 分钟
          newCard.status = db.CardStatus.learning;
          newCard.nextReviewDate = currentTime + 300000; // 5 分钟
          newCard.s = clampStability(newCard.s);
        }
        // Hard(2) / Easy(4)：不绑定业务逻辑
        break;

      case db.CardStatus.review:
        if (rating == FSRSCardRating.again) {
          // Again(1)：Status -> 3 (Relearning)
          // Fail_Count 递增，S 执行 S_forget 衰减
          newCard.status = db.CardStatus.relearning;
          newCard.failCount = card.failCount + 1;
          newCard.s = forgetStability(card.s, card.s, currentR);
          newCard.s = clampStability(newCard.s);
          newCard.nextReviewDate = nextReviewDate(currentTime, newCard.s);
        } else if (rating == FSRSCardRating.hard) {
          // Hard(2)：Status 维持 2
          newCard.s = _calculateHardStability(card.s, currentR);
          newCard.s = clampStability(newCard.s);
          newCard.nextReviewDate = nextReviewDate(currentTime, newCard.s);
        } else {
          // Good(3) / Easy(4)：Status 维持 2，Fail_Count 重置为 0
          newCard.failCount = 0;
          newCard.s = _calculateSuccessStability(rating, card.s, currentR);
          newCard.s = clampStability(newCard.s);
          newCard.nextReviewDate = nextReviewDate(currentTime, newCard.s);
        }
        break;

      case db.CardStatus.relearning:
        if (rating == FSRSCardRating.good) {
          // Good(3)：Status -> 2 (Review)
          // 宽容窗口检查
          final inWindow = lastFailTime != null &&
              withinForgivenessWindow(lastFailTime, currentTime);
          if (inWindow) {
            // 宽容窗口内：S = min(S * 1.2, Max_S)
            newCard.s = min(newCard.s * 1.2, 100.0);
          } else {
            // 常规重算
            newCard.s = _calculateSuccessStability(rating, card.s, currentR);
          }
          newCard.s = clampStability(newCard.s);
          newCard.status = db.CardStatus.review;
          newCard.nextReviewDate = nextReviewDate(currentTime, newCard.s);
        } else if (rating == FSRSCardRating.again) {
          // Again(1)：Status 维持 3，延后 5 分钟，S 执行二次深度衰减
          newCard.nextReviewDate = currentTime + 300000;
          newCard.s = forgetStability(forgetStability(card.s, card.s, currentR), card.s, currentR);
          newCard.s = clampStability(newCard.s);
        }
        break;
    }

    return newCard;
  }

  /// 成功评级（Good/Easy）的 S 计算
  double _calculateSuccessStability(int rating, double currentS, double currentR) {
    if (rating == FSRSCardRating.easy) {
      // Easy: S *= 1.3
      return clampStability(currentS * 1.3);
    }
    // Good: 标准成功函数
    // S_new = S * (1 + exp(w8) * (1 - exp(w9 * (G - 1))) * (11 - D) / 100)
    final gFactor = 1.0 - exp(w[8] * (rating - 1));
    final dFactor = (11.0 - initialDifficulty(rating)) / 100.0;
    return clampStability(currentS * (1.0 + exp(w[8]) * gFactor * dFactor));
  }

  /// Hard 评级的 S 计算
  double _calculateHardStability(double currentS, double currentR) {
    // Hard: S *= exp(-w7) = S * 0.86
    return clampStability(currentS * w[FSRSWeights.W6]);
  }

  /// 预览各评级分布（用于 UI 显示）
  /// 返回 Map: {again: %, hard: %, good: %, easy: %}
  Map<String, double> previewRatingDistribution({
    required db.CardModel card,
    required int currentTime,
    int? lastFailTime,
  }) {
    final results = <String, double>{};
    final t = (currentTime - card.nextReviewDate) / 86400000.0;
    final currentR = retrievability(t > 0 ? t : 0, card.s);

    for (final rating in [
      FSRSCardRating.again,
      FSRSCardRating.hard,
      FSRSCardRating.good,
      FSRSCardRating.easy,
    ]) {
      final nextCard = calculateNextState(
        card: card,
        rating: rating,
        currentTime: currentTime,
        lastFailTime: lastFailTime,
      );
      final nextT = (nextCard.nextReviewDate - currentTime) / 86400000.0;
      final nextR = retrievability(nextT > 0 ? nextT : 0, nextCard.s);
      results[_ratingName(rating)] = (nextR * 100).clamp(0, 100);
    }

    return results;
  }

  String _ratingName(int rating) {
    switch (rating) {
      case FSRSCardRating.again: return 'again';
      case FSRSCardRating.hard: return 'hard';
      case FSRSCardRating.good: return 'good';
      case FSRSCardRating.easy: return 'easy';
      default: return 'unknown';
    }
  }

  /// 创建新卡片（Status=0，初始状态）
  db.CardModel createNewCard({
    required String conceptUuid,
    required int randomSortId,
  }) {
    return db.CardModel(
      conceptUuid: conceptUuid,
      status: db.CardStatus.newCard,
      nextReviewDate: DateTime.now().millisecondsSinceEpoch,
      lastReviewDate: 0, // 尚未复习
      r: 1.0, // 全新卡片 R=1
      s: 0.0, // 全新卡片 S=0
      randomSortId: randomSortId,
    );
  }

  /// 计算下次复习时间（人类可读格式）
  String formatNextReview(int nextReviewDate, int currentTime) {
    final diff = nextReviewDate - currentTime;
    if (diff <= 0) return '立即复习';

    final days = diff ~/ (24 * 60 * 60 * 1000);
    final hours = (diff % (24 * 60 * 60 * 1000)) ~/ (60 * 60 * 1000);
    final minutes = (diff % (60 * 60 * 1000)) ~/ (60 * 1000);

    if (days > 0) {
      return '$days天${hours > 0 ? '${hours}h' : ''}';
    } else if (hours > 0) {
      return '${hours}h${minutes > 0 ? '${minutes}min' : ''}';
    } else {
      return '${minutes}min';
    }
  }
}

// ============================================================================
// Review_Log 写入辅助（对应文档 6.2 节撤销机制）
// ============================================================================

/// 计算逻辑日字符串（基于 4:00 跨日分割线）
/// 对应文档 10.2 节日志逻辑日计算
String calculateLocalDateStr(int utcTimestamp, {int dayRefreshHour = 0}) {
  // dayRefreshHour 默认为 0，代表凌晨 0:00 为分割线
  // 文档规定分割线为 4:00，故 dayRefreshHour=0 对应逻辑日 = UTC+4
  final offsetHours = dayRefreshHour; // 实际应用中 dayRefreshHour=0，UTC+4 逻辑日
  // 为简化，这里直接使用 UTC+8 本地日（用户实际使用场景）
  final localDate = DateTime.fromMillisecondsSinceEpoch(utcTimestamp);
  final year = localDate.year;
  final month = localDate.month.toString().padLeft(2, '0');
  final day = localDate.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// 生成 Review_Log 记录
db.ReviewLogModel createReviewLog({
  required db.CardModel card,
  required int rating,
  required int currentTime,
  int dayRefreshHour = 0,
}) {
  return db.ReviewLogModel(
    conceptUuid: card.conceptUuid,
    rating: rating,
    logDate: currentTime,
    localDateStr: calculateLocalDateStr(currentTime, dayRefreshHour: dayRefreshHour),
    preStatus: card.status,
    preR: card.r,
    preS: card.s,
  );
}

/// 撤销最后一次操作（从 Review_Log 恢复）
/// 返回被撤销的卡片状态快照
Future<db.CardModel?> undoLastOperation(Database hotDb) async {
  final lastLog = await db.queryLastReviewLog(hotDb);
  if (lastLog == null) return null;

  // 读取当前卡片
  final currentCard = await db.queryCardByUuid(hotDb, lastLog.conceptUuid);
  if (currentCard == null) return null;

  // 找倒数第二条 Review_Log 的 logDate，用于恢复 lastReviewDate。
  // （每次评级后 Card.lastReviewDate = Review_Log.Log_Date，
  //  撤销后应回到倒数第二条记录的时间，若无则置 0）
  final allLogs = await hotDb.query(
    db.kTableReviewLog,
    where: 'Concept_UUID = ? AND Log_ID < ?',
    whereArgs: [lastLog.conceptUuid, lastLog.logId ?? 999999999],
    orderBy: 'Log_ID DESC',
    limit: 1,
  );
  final restoredLastReviewDate = allLogs.isNotEmpty
      ? (allLogs.first['Log_Date'] as int)
      : 0;

  final restoredCard = db.CardModel(
    cardId: currentCard.cardId,
    conceptUuid: currentCard.conceptUuid,
    status: lastLog.preStatus,
    nextReviewDate: currentCard.nextReviewDate, // Next_Review_Date 由时间决定，不回滚
    lastReviewDate: restoredLastReviewDate,
    r: lastLog.preR,
    s: lastLog.preS,
    failCount: currentCard.failCount,
    favorite: currentCard.favorite,
    topicRead: currentCard.topicRead,
    treeVisit: currentCard.treeVisit,
    randomSortId: currentCard.randomSortId,
  );

  await db.upsertCard(hotDb, restoredCard);
  await db.deleteLastReviewLog(hotDb);

  return restoredCard;
}

// ============================================================================
// 批次统计计算（对应文档 10.2 节）
// ============================================================================

class SessionStats {
  final int totalCards;
  final int newCards;
  final int reviewCards;
  final int relearnCards;
  final Map<int, int> ratingDistribution;
  final double avgStabilityChange;
  final double avgRetrievabilityChange;
  final List<String> learnedSpellings;
  final int totalRatings; // 本次会话总评级次数（分母：评级占比）

  SessionStats({
    required this.totalCards,
    required this.newCards,
    required this.reviewCards,
    required this.relearnCards,
    required this.ratingDistribution,
    required this.avgStabilityChange,
    required this.avgRetrievabilityChange,
    required this.learnedSpellings,
    this.totalRatings = 0,
  });

  int get againCount => ratingDistribution[FSRSCardRating.again] ?? 0;
  int get hardCount => ratingDistribution[FSRSCardRating.hard] ?? 0;
  int get goodCount => ratingDistribution[FSRSCardRating.good] ?? 0;
  int get easyCount => ratingDistribution[FSRSCardRating.easy] ?? 0;

  int get _ratingDenom => totalRatings > 0 ? totalRatings : (totalCards > 0 ? totalCards : 1);
  double get againPercent => _ratingDenom > 0 ? (againCount / _ratingDenom * 100) : 0;
  double get hardPercent => _ratingDenom > 0 ? (hardCount / _ratingDenom * 100) : 0;
  double get goodPercent => _ratingDenom > 0 ? (goodCount / _ratingDenom * 100) : 0;
  double get easyPercent => _ratingDenom > 0 ? (easyCount / _ratingDenom * 100) : 0;

  String get spellingsList => learnedSpellings.join(', ');
}

/// 计算本次 Session 的统计数据
/// 以 Review_Log 为唯一真实数据源，过滤已撤销的记录
Future<SessionStats> calculateSessionStats({
  required Database hotDb,
  required Database romDb,
  required int sessionStartTime,
  required int sessionEndTime,
}) async {
  // 查询本次会话时间范围内的所有 Review_Log
  final logs = await hotDb.query(
    db.kTableReviewLog,
    where: 'Log_Date >= ? AND Log_Date <= ?',
    whereArgs: [sessionStartTime, sessionEndTime],
    orderBy: 'Log_Date ASC',
  );

  print('[Stats] sessionStartTime=$sessionStartTime, sessionEndTime=$sessionEndTime');

  final allLogs = logs.map((e) {
    final m = Map<String, dynamic>.from(e);
    return db.ReviewLogModel(
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

  // 评级分布（按本次会话所有日志）
  final ratingDist = <int, int>{};
  for (final log in allLogs) {
    ratingDist[log.rating] = (ratingDist[log.rating] ?? 0) + 1;
  }

  final totalRatings = allLogs.length;
  final againPercent = totalRatings > 0 ? (ratingDist[FSRSCardRating.again] ?? 0) / totalRatings * 100 : 0.0;
  print('[Stats] allLogs.length=${allLogs.length}');
  print('[Stats] ratingDist=$ratingDist');
  print('[Stats] totalRatings=$totalRatings (allLogs.length)');
  print('[Stats] againPercent=${againPercent.toStringAsFixed(2)}%');

  // 按 UUID 分组（一个 UUID 可能有多条日志，取该 UUID 的最后一条用于判断流转类型）
  final logByUuid = <String, List<db.ReviewLogModel>>{};
  for (final log in allLogs) {
    logByUuid.putIfAbsent(log.conceptUuid, () => []).add(log);
  }

  // 流转计数：基于每个 UUID 的最后一条 Review_Log 的 preStatus
  int newCount = 0;
  int reviewCount = 0;
  int relearnCount = 0;
  double totalSChange = 0;
  double totalRChange = 0;
  final sessionCardUuids = logByUuid.keys.toList();

  for (final uuid in sessionCardUuids) {
    final cardLogs = logByUuid[uuid]!;
    final latestLog = cardLogs.last; // 该卡本次会话最后一条

    if (latestLog.preStatus == db.CardStatus.newCard) {
      newCount++;
    } else if (latestLog.preStatus == db.CardStatus.relearning) {
      relearnCount++;
    } else {
      reviewCount++;
    }

    // 平均 S/R 变化：最后一次评级后的 s/r 减去评级前的 pre_S/pre_R
    // 从 Card 表读当前（最新）s/r
    final currentCard = await db.queryCardByUuid(hotDb, uuid);
    if (currentCard != null) {
      totalSChange += currentCard.s - latestLog.preS;
      totalRChange += currentCard.r - latestLog.preR;
    }
  }

  final totalCards = sessionCardUuids.length;
  print('[Stats] newCount=$newCount, reviewCount=$reviewCount, relearnCount=$relearnCount');

  // 拼写列表
  final spellings = <String>[];
  for (final uuid in sessionCardUuids) {
    final note = await db.queryNoteByUuid(romDb, uuid);
    spellings.add(note?.spelling ?? uuid);
  }

  return SessionStats(
    totalCards: totalCards,
    newCards: newCount,
    reviewCards: reviewCount,
    relearnCards: relearnCount,
    ratingDistribution: ratingDist,
    avgStabilityChange: totalCards > 0 ? totalSChange / totalCards : 0,
    avgRetrievabilityChange: totalCards > 0 ? totalRChange / totalCards : 0,
    learnedSpellings: spellings,
    totalRatings: allLogs.length, // 评级百分比分母 = 评级总次数
  );
}
