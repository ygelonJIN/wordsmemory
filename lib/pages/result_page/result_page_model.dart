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
  String learnedWords = '';
  String newCountText = '';
  String againPercentText = '';
  String reviewCountText = '';
  String hardPercentText = '';
  String relearnCountText = '';
  String goodPercentText = '';
  String easyPercentText = '';
  String avgStabilityText = '';
  String avgRetrievabilityText = '';
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    try {
      final stats = await BackendManager.instance.endSession();
      final userNameSetting = await BackendManager.instance.loadSettings();
      final homeData = await BackendManager.instance.loadHomePageData();
      if (!_disposed) {
        updatePage(() {
          savingStatus = '已保存';
          userName = userNameSetting.userNameText;
          final dailyTarget = homeData.dailyTarget;
          final todayCount = homeData.todayLearnedCount;
          dailySummary = '每日目标${dailyTarget}词，已学${todayCount}词';
          learnedWords = stats.learnedSpellings.join(', ');
          newCountText = '新学数量:${stats.newCards}';
          reviewCountText = '复习数量:${stats.reviewCards}';
          relearnCountText = '重学数量:${stats.relearnCards}';
          againPercentText = 'again:${stats.againPercent.toStringAsFixed(0)}%';
          hardPercentText = 'hard:${stats.hardPercent.toStringAsFixed(0)}%';
          goodPercentText = 'good:${stats.goodPercent.toStringAsFixed(0)}%';
          easyPercentText = 'easy:${stats.easyPercent.toStringAsFixed(0)}%';
          avgStabilityText = '平均stability+${stats.avgStabilityChange.toStringAsFixed(1)}days';
          avgRetrievabilityText = '平均retrievability+${stats.avgRetrievabilityChange.toStringAsFixed(0)}%';
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => savingStatus = '保存失败');
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
