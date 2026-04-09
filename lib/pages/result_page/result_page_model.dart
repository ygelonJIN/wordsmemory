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

  final bool? fromQuickLearn;
  final bool? fromRandomLearn;
  final bool? fromSemanticReading;

  ResultPageModel({
    this.fromQuickLearn,
    this.fromRandomLearn,
    this.fromSemanticReading,
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
        savingStatus = '已保存';
        userName = userNameSetting.userNameText;

        if (fromQuickLearn == true) {
          // 快速筛选完成模式：显示本次标记的单词列表
          final spellings = await BackendManager.instance.getQuickMarkedSpellings();
          dailySummary = '本次已标注${spellings.length}词';
          learnedWords = spellings.isNotEmpty ? spellings.join('，') : '（无）';
        } else if (fromSemanticReading == true) {
          // 语义阅读完成模式：调用 endSession 获取学习统计
          final stats = await BackendManager.instance.endSession();
          dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
          sessionSummary = '本次已学${stats.learnedSpellings.length}词';
          if (stats.learnedSpellings.isNotEmpty) {
            learnedWords = stats.learnedSpellings.join('，');
          } else {
            learnedWords = '（无）';
          }
        } else if (fromRandomLearn == true) {
          // 随机学习总结模式：不显示标注计数，sessionSummary 保持为空
          final stats = await BackendManager.instance.endSession();
          dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
          sessionSummary = '';
          if (stats.learnedSpellings.isNotEmpty) {
            learnedWords = stats.learnedSpellings.join('，');
          } else {
            learnedWords = '（无）';
          }
        } else {
          // 每日学习总结模式：调用 endSession 获取本次学习统计
          final stats = await BackendManager.instance.endSession();
          final quickCount = await _queryTodayQuickCount();

          dailySummary = '每日目标${homeData.dailyTarget}词，已学${homeData.todayLearnedCount}词';
          sessionSummary = '本次已标${quickCount}词，本课已学${stats.learnedSpellings.length}词';

          if (stats.learnedSpellings.isNotEmpty) {
            learnedWords = stats.learnedSpellings.join('，');
          } else {
            learnedWords = '（无）';
          }
        }
      }
    } catch (e) {
      if (!_disposed) {
        savingStatus = '保存失败';
        learnedWords = '';
      }
    }
  }

  Future<int> _queryTodayQuickCount() async {
    try {
      // 返回所有已标记单词的数量（跨所有日期的累计数）
      final all = await BackendManager.instance.getQuickMarkedSpellings();
      return all.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
