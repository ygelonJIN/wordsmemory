import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'result_page_widget.dart' show ResultPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class ResultPageModel extends FlutterFlowModel<ResultPageWidget> {
  bool _disposed = false;

  bool bgExpanded = false;
  String savingStatus = '正在保存中';
  String userName = '';
  String dailySummary = '';
  String sessionSummary = '';
  String learnedWords = '';

  // 数据统计字段
  String newCount = '';
  String reviewCount = '';
  String relearnCount = '';
  String againPercent = '';
  String hardPercent = '';
  String goodPercent = '';
  String easyPercent = '';
  String avgStabilityChange = '';
  String avgRetrievabilityChange = '';

  final bool? fromQuickLearn;
  final bool? fromRandomLearn;
  final bool? fromSemanticReading;
  final bool? fromTreeLearning;
  final List<String>? learnedSpellings;

  ResultPageModel({
    this.fromQuickLearn,
    this.fromRandomLearn,
    this.fromSemanticReading,
    this.fromTreeLearning,
    this.learnedSpellings,
  });

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    try {
      final userNameSetting = await BackendManager.instance.loadSettings();
      final homeData = await BackendManager.instance.loadHomePageData();
      // 兜底结算（幂等安全：endSession 已内置 finalized 保护）
      final stats = await BackendManager.instance.endSession();

      if (_disposed) return;

      // 用户信息
      final resolvedUserName = userNameSetting.userNameText.isNotEmpty
          ? userNameSetting.userNameText
          : '用户';

      // 按来源构建展示字段
      final spellings = _resolveSpellings(stats);

      if (fromQuickLearn == true) {
        final markedSpellings = await BackendManager.instance.getQuickMarkedSpellings();
        if (_disposed) return;
        _applyStats(
          stats, homeData, spellings, resolvedUserName,
          dailySummaryOverride: '本次已标注${markedSpellings.length}词',
        );
      } else {
        final totalMarked = fromQuickLearn != true && fromSemanticReading != true &&
            fromRandomLearn != true && fromTreeLearning != true
            ? await _queryTotalMarkedCount()
            : null;
        if (_disposed) return;
        _applyStats(
          stats, homeData, spellings, resolvedUserName,
          sessionSummaryOverride: totalMarked != null
              ? '本次已标${totalMarked}词，本课已学${stats.learnedSpellings.length}词'
              : '本次已学${spellings.length}词',
        );
      }
    } catch (e) {
      if (!_disposed) {
        updatePage(() {
          savingStatus = '保存失败';
          learnedWords = '';
        });
      }
    }
  }

  List<String> _resolveSpellings(SessionStats stats) {
    // 优先使用导航参数传入的 spellings（内存数据），避免数据库查询问题
    return learnedSpellings ?? stats.learnedSpellings;
  }

  void _applyStats(
    SessionStats stats,
    HomePageData homeData,
    List<String> spellings,
    String userNameText, {
    String? dailySummaryOverride,
    String? sessionSummaryOverride,
  }) {
    updatePage(() {
      savingStatus = '已保存';
      userName = userNameText;
      dailySummary = dailySummaryOverride ??
          '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
      sessionSummary = sessionSummaryOverride ??
          '本次已学${spellings.length}词';
      learnedWords = spellings.isNotEmpty ? spellings.join('，') : '（无）';

      // 统一统计字段填充
      newCount = '新学数量:${stats.newCards}';
      reviewCount = '复习数量:${stats.reviewCards}';
      relearnCount = '重学数量:${stats.relearnCards}';
      againPercent = 'again:${stats.againPercent.toStringAsFixed(0)}%';
      hardPercent = 'hard:${stats.hardPercent.toStringAsFixed(0)}%';
      goodPercent = 'good:${stats.goodPercent.toStringAsFixed(0)}%';
      easyPercent = 'easy:${stats.easyPercent.toStringAsFixed(0)}%';
      final stabilitySign = stats.avgStabilityChange >= 0 ? '+' : '';
      avgStabilityChange = '平均stability${stabilitySign}${stats.avgStabilityChange.toStringAsFixed(1)}days';
      final retrievSign = stats.avgRetrievabilityChange >= 0 ? '+' : '';
      avgRetrievabilityChange = '平均retrievability${retrievSign}${stats.avgRetrievabilityChange.toStringAsFixed(0)}%';
    });
  }

  Future<int> _queryTotalMarkedCount() async {
    try {
      final all = await BackendManager.instance.getQuickMarkedSpellings();
      return all.length;
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
