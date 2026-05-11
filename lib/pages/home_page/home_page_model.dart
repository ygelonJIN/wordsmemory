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
  String remaining = '';
  String bookProgress = '';
  int dailyTarget = 1000;
  bool _isLoading = false;
  String? loadError;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      await BackendManager.instance.initialize().timeout(
        Duration(seconds: 5),
        onTimeout: () => print('[HomePage] initialize() 超时！'),
      );
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
          loadError = null;
        });
      }
    } catch (e) {
      print('[HomePage] _loadData 异常: $e');
      if (!_disposed) {
        updatePage(() {
          loadError = e.toString();
        });
      }
    } finally {
      _isLoading = false;
    }
  }

  /// 公开刷新方法，供页面从设置页返回时调用
  Future<void> refresh() async {
    _disposed = false;
    _isLoading = false;
    await _loadData();
  }

  /// 保存用户名
  Future<void> saveUserName(String name) async {
    final trimmed = name.trim();
    await BackendManager.instance.updateSetting('user_name', trimmed);
    await _loadData();
  }

  Future<void> saveDailyTarget(int target) async {
    if (target <= 0) return;
    // 先更新本地状态（避免依赖 _loadData 导致的 DB 竞态，参考 SettingPageModel 的 setter 模式）
    updatePage(() => dailyTarget = target);
    // 异步持久化到数据库
    await BackendManager.instance.updateSetting('daily_target', target.toString());
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
  }
}
