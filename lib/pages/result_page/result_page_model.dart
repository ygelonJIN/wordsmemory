import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'result_page_widget.dart' show ResultPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class ResultPageModel extends FlutterFlowModel<ResultPageWidget> {
  bool bgExpanded = false;
  String savingStatus = '正在保存中';
  String userName = '';
  String dailySummary = '';
  String sessionSummary = '';
  String learnedWords = '';
  bool _disposed = false;

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

      if (!_disposed) {
        updatePage(() {
          savingStatus = '已保存';
          userName = userNameSetting.userNameText;
        });

        if (fromQuickLearn == true) {
          // 快速筛选完成模式：显示本次标记的单词列表
          final spellings = await BackendManager.instance.getQuickMarkedSpellings();
          if (_disposed) return;
          updatePage(() {
            dailySummary = '本次已标注${spellings.length}词';
            learnedWords = spellings.isNotEmpty ? spellings.join('，') : '（无）';
            // 快速筛选模式不显示统计数据
            newCount = '';
            reviewCount = '';
            relearnCount = '';
            againPercent = '';
            hardPercent = '';
            goodPercent = '';
            easyPercent = '';
            avgStabilityChange = '';
            avgRetrievabilityChange = '';
          });
        } else if (fromSemanticReading == true) {
          // 语义阅读完成模式：调用 endSession 获取学习统计
          final stats = await BackendManager.instance.endSession();
          if (_disposed) return;
          updatePage(() {
            dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
            // 优先使用导航参数传入的 spellings（内存数据），避免数据库查询问题
            final spellings = learnedSpellings ?? stats.learnedSpellings;
            sessionSummary = '本次已学${spellings.length}词';
            learnedWords = spellings.isNotEmpty ? spellings.join('，') : '（无）';
            // 填充统计数据
            newCount = '新学数量:${stats.newCards}';
            reviewCount = '复习数量:${stats.reviewCards}';
            relearnCount = '重学数量:${stats.relearnCards}';
            againPercent = 'again:${stats.againPercent.toStringAsFixed(0)}%';
            hardPercent = 'hard:${stats.hardPercent.toStringAsFixed(0)}%';
            goodPercent = 'good:${stats.goodPercent.toStringAsFixed(0)}%';
            easyPercent = 'easy:${stats.easyPercent.toStringAsFixed(0)}%';
            avgStabilityChange = '平均stability${stats.avgStabilityChange >= 0 ? '+' : ''}${stats.avgStabilityChange.toStringAsFixed(1)}days';
            avgRetrievabilityChange = '平均retrievability${stats.avgRetrievabilityChange >= 0 ? '+' : ''}${stats.avgRetrievabilityChange.toStringAsFixed(0)}%';
          });
        } else if (fromRandomLearn == true) {
          // 随机学习总结模式
          final stats = await BackendManager.instance.endSession();
          if (_disposed) return;
          updatePage(() {
            dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
            // 优先使用导航参数传入的 spellings（内存数据）
            final spellings = learnedSpellings ?? stats.learnedSpellings;
            sessionSummary = '本次已学${spellings.length}词';
            learnedWords = spellings.isNotEmpty ? spellings.join('，') : '（无）';
            // 填充统计数据
            newCount = '新学数量:${stats.newCards}';
            reviewCount = '复习数量:${stats.reviewCards}';
            relearnCount = '重学数量:${stats.relearnCards}';
            againPercent = 'again:${stats.againPercent.toStringAsFixed(0)}%';
            hardPercent = 'hard:${stats.hardPercent.toStringAsFixed(0)}%';
            goodPercent = 'good:${stats.goodPercent.toStringAsFixed(0)}%';
            easyPercent = 'easy:${stats.easyPercent.toStringAsFixed(0)}%';
            avgStabilityChange = '平均stability${stats.avgStabilityChange >= 0 ? '+' : ''}${stats.avgStabilityChange.toStringAsFixed(1)}days';
            avgRetrievabilityChange = '平均retrievability${stats.avgRetrievabilityChange >= 0 ? '+' : ''}${stats.avgRetrievabilityChange.toStringAsFixed(0)}%';
          });
        } else if (fromTreeLearning == true) {
          // 结构树学习总结模式
          final stats = await BackendManager.instance.endSession();
          if (_disposed) return;
          updatePage(() {
            dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
            final spellings = learnedSpellings ?? stats.learnedSpellings;
            sessionSummary = '本次已学${spellings.length}词';
            learnedWords = spellings.isNotEmpty ? spellings.join('，') : '（无）';
            // 填充统计数据
            newCount = '新学数量:${stats.newCards}';
            reviewCount = '复习数量:${stats.reviewCards}';
            relearnCount = '重学数量:${stats.relearnCards}';
            againPercent = 'again:${stats.againPercent.toStringAsFixed(0)}%';
            hardPercent = 'hard:${stats.hardPercent.toStringAsFixed(0)}%';
            goodPercent = 'good:${stats.goodPercent.toStringAsFixed(0)}%';
            easyPercent = 'easy:${stats.easyPercent.toStringAsFixed(0)}%';
            avgStabilityChange = '平均stability${stats.avgStabilityChange >= 0 ? '+' : ''}${stats.avgStabilityChange.toStringAsFixed(1)}days';
            avgRetrievabilityChange = '平均retrievability${stats.avgRetrievabilityChange >= 0 ? '+' : ''}${stats.avgRetrievabilityChange.toStringAsFixed(0)}%';
          });
        } else {
          // 每日学习总结模式：调用 endSession 获取本次学习统计
          final stats = await BackendManager.instance.endSession();
          final totalMarked = await _queryTotalMarkedCount();
          if (_disposed) return;
          updatePage(() {
            dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
            sessionSummary = '本次已标${totalMarked}词，本课已学${stats.learnedSpellings.length}词';
            learnedWords = stats.learnedSpellings.isNotEmpty
                ? stats.learnedSpellings.join('，')
                : '（无）';
            // 填充统计数据
            newCount = '新学数量:${stats.newCards}';
            reviewCount = '复习数量:${stats.reviewCards}';
            relearnCount = '重学数量:${stats.relearnCards}';
            againPercent = 'again:${stats.againPercent.toStringAsFixed(0)}%';
            hardPercent = 'hard:${stats.hardPercent.toStringAsFixed(0)}%';
            goodPercent = 'good:${stats.goodPercent.toStringAsFixed(0)}%';
            easyPercent = 'easy:${stats.easyPercent.toStringAsFixed(0)}%';
            avgStabilityChange = '平均stability${stats.avgStabilityChange >= 0 ? '+' : ''}${stats.avgStabilityChange.toStringAsFixed(1)}days';
            avgRetrievabilityChange = '平均retrievability${stats.avgRetrievabilityChange >= 0 ? '+' : ''}${stats.avgRetrievabilityChange.toStringAsFixed(0)}%';
          });
        }
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

  Future<int> _queryTotalMarkedCount() async {
    try {
      // 返回所有已标记单词的数量（跨所有日期的累计数，非仅今日）
      final all = await BackendManager.instance.getQuickMarkedSpellings();
      return all.length;
    } catch (e) {
      // 查询失败时返回 0，便于调试时可开启日志
      // print('[ResultPage] _queryTotalMarkedCount 异常: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
