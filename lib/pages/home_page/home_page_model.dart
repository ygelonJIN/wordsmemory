import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'home_page_widget.dart' show HomePageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class HomePageModel extends FlutterFlowModel<HomePageWidget> {
  /// 用户名（空则首页显示下划线占位）
  String userName = '';
  String greeting = 'Hi,';
  String todayLearned = '今日已学0词，0min';
  String exportWarning = '已0天未备份';
  String remaining = '剩余：0';
  String bookProgress = '当前词书：0/5000';
  int dailyTarget = 1000;
  bool _isLoading = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      if (!BackendManager.instance.isInitialized) {
        await BackendManager.instance.initialize();
      }
      final data = await BackendManager.instance.loadHomePageData();
      if (!_disposed) {
        updatePage(() {
          userName = data.userName;
          greeting = data.greetingText;
          todayLearned = data.todayLearnedText;
          exportWarning = data.exportWarningText;
          remaining = data.remainingText;
          bookProgress = data.bookProgressText;
          dailyTarget = data.dailyTarget;
        });
      }
    } catch (e) {
      // 数据加载失败，保持占位符不变
    } finally {
      _isLoading = false;
    }
  }

  Future<void> saveUserName(String name) async {
    final trimmed = name.trim();
    await BackendManager.instance.updateSetting('user_name', trimmed);
    await _loadData();
  }

  Future<void> saveDailyTarget(int target) async {
    if (target <= 0) return;
    await BackendManager.instance.updateSetting('daily_target', target.toString());
    await _loadData();
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
  }
}
