import '/flutter_flow/flutter_flow_util.dart';
import 'setting_page_widget.dart' show SettingPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

enum SettingPageActionResult {
  success,
  cancelled,
  error,
}

class SettingPageActionResponse {
  final SettingPageActionResult result;
  final String? errorCode;
  final int? importedCount;
  final int? skippedCount;

  SettingPageActionResponse.success()
      : result = SettingPageActionResult.success,
        errorCode = null,
        importedCount = null,
        skippedCount = null;

  SettingPageActionResponse.cancelled()
      : result = SettingPageActionResult.cancelled,
        errorCode = null,
        importedCount = null,
        skippedCount = null;

  SettingPageActionResponse.error(this.errorCode)
      : result = SettingPageActionResult.error,
        importedCount = null,
        skippedCount = null;

  SettingPageActionResponse.importResult({required this.importedCount, required this.skippedCount})
      : result = SettingPageActionResult.success,
        errorCode = null;
}

class SettingPageModel extends FlutterFlowModel<SettingPageWidget> {
  SettingsData? settingsData;
  bool isLoading = true;
  bool isExporting = false;
  bool isImporting = false;
  bool _disposed = false;

  /// 动态加载的词书列表（从数据库 WordBook 表读取）
  List<WordBookModel> wordBooks = [];

  /// 词库诊断统计
  Map<String, int> dbStats = {};

  /// 加载错误状态
  String? loadError;

  // 直接暴露状态字段，避免每次读 DB；set 时直接修改 + updatePage 刷新
  String currentBook = 'cet4';
  int singleSessionLimit = 70;
  bool showEtymology = true;
  bool showDefinition = true;
  bool showExample = true;
  int dailyRefreshHour = 0;

  String get userName => settingsData?.userNameText ?? 'Hi,';

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    print('[SettingPage] _loadData 开始');
    try {
      print('[SettingPage] BackendManager.instance: ${BackendManager.instance}');
      print('[SettingPage] isInitialized: ${BackendManager.instance.isInitialized}');

      // 先确保 BackendManager 完成初始化，再加载数据
      if (!BackendManager.instance.isInitialized) {
        print('[SettingPage] BackendManager 未初始化，等待 initialize()...');
        await BackendManager.instance.initialize();
        print('[SettingPage] BackendManager.initialize() 完成');
      }

      // 加载设置
      final data = await BackendManager.instance.loadSettings();
      print('[SettingPage] loadSettings 返回: ${data}');

      // 初始化完成后 hotDb 就绪，再调用 loadWordBooks
      // 增加重试逻辑：如果词书为空，延迟后重试最多 3 次
      List<WordBookModel> books = [];
      for (int retry = 0; retry < 3; retry++) {
        books = await BackendManager.instance.loadWordBooks();
        print('[SettingPage] loadWordBooks 第 ${retry + 1} 次返回: ${books.length} 个词书');
        if (books.isNotEmpty) break;
        if (retry < 2) {
          await Future.delayed(Duration(milliseconds: 500 * (retry + 1)));
          print('[SettingPage] 词书列表为空，${(retry + 1) * 500}ms 后重试...');
        }
      }
      if (books.isEmpty) {
        print('[SettingPage] 警告：词书列表仍然为空');
      }

      // 获取词库统计，增加异常处理
      Map<String, int> stats = {};
      try {
        stats = await BackendManager.instance.getDatabaseStats();
        print('[SettingPage] getDatabaseStats 返回: $stats');
      } catch (statsError) {
        print('[SettingPage] getDatabaseStats 异常: $statsError');
        stats = {'error': -1};
      }

      if (!_disposed) {
        updatePage(() {
          settingsData = data;
          wordBooks = books;
          dbStats = stats;
          isLoading = false;
          loadError = null;
          currentBook = data.currentBook;
          singleSessionLimit = data.singleSessionLimit;
          showEtymology = data.showEtymology;
          showDefinition = data.showDefinition;
          showExample = data.showExample;
          dailyRefreshHour = data.dailyRefreshHour;
        });
      }
    } catch (e, st) {
      print('[SettingPage] _loadData 异常: $e\n$st');
      if (!_disposed) {
        updatePage(() {
          isLoading = false;
          dbStats = {'error': -1};
          loadError = e.toString();
        });
      }
    }
  }

  Future<void> setCurrentBook(String book) async {
    await BackendManager.instance.updateSetting('current_book', book);
    updatePage(() => currentBook = book);
  }

  Future<void> setSingleSessionLimit(int limit) async {
    await BackendManager.instance.updateSetting('single_session_limit', limit.toString());
    updatePage(() => singleSessionLimit = limit);
  }

  Future<void> setShowEtymology(bool value) async {
    await BackendManager.instance.updateSetting('show_etymology', value ? '1' : '0');
    updatePage(() => showEtymology = value);
  }

  Future<void> setShowDefinition(bool value) async {
    await BackendManager.instance.updateSetting('show_definition', value ? '1' : '0');
    updatePage(() => showDefinition = value);
  }

  Future<void> setShowExample(bool value) async {
    await BackendManager.instance.updateSetting('show_example', value ? '1' : '0');
    updatePage(() => showExample = value);
  }

  Future<void> setDailyRefreshHour(int hour) async {
    await BackendManager.instance.updateSetting('daily_refresh_hour', hour.toString());
    updatePage(() => dailyRefreshHour = hour);
  }

  Future<void> saveUserName(String name) async {
    final trimmed = name.trim();
    await BackendManager.instance.updateSetting('user_name', trimmed);
    await _loadData();
  }

  /// 导出存档；成功返回 true，失败返回 false（失败时 errorCode 字段有效）
  Future<SettingPageActionResponse> exportArchive() async {
    updatePage(() => isExporting = true);
    try {
      final json = await BackendManager.instance.exportData();

      final result = await FilePicker.platform.saveFile(
        dialogTitle: '备份存档',
        fileName: 'wordmemory_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(json);
        updatePage(() {
          isExporting = false;
        });
        return SettingPageActionResponse.success();
      } else {
        updatePage(() => isExporting = false);
        return SettingPageActionResponse.cancelled();
      }
    } catch (e) {
      updatePage(() => isExporting = false);
      return SettingPageActionResponse.error('EXPORT_ERROR');
    }
  }

  /// 导入存档；返回结果描述（用于 ErrorPage）
  /// result: success=有有效导入,cancelled=用户取消,error=导入失败
  Future<SettingPageActionResponse> importArchive() async {
    updatePage(() => isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: '导入存档',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final json = await file.readAsString();
        final importResult = await BackendManager.instance.importData(json);
        updatePage(() => isImporting = false);

        if (importResult.skipped > 0) {
          return SettingPageActionResponse.importResult(
            importedCount: importResult.imported,
            skippedCount: importResult.skipped,
          );
        }
        return SettingPageActionResponse.success();
      }

      updatePage(() => isImporting = false);
      return SettingPageActionResponse.cancelled();
    } on FormatException {
      updatePage(() => isImporting = false);
      return SettingPageActionResponse.error('IMPORT_FORMAT_ERROR');
    } catch (e) {
      updatePage(() => isImporting = false);
      return SettingPageActionResponse.error('IMPORT_FORMAT_ERROR');
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
