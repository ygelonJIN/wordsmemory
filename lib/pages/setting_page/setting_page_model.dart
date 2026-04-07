import '/flutter_flow/flutter_flow_util.dart';
import 'setting_page_widget.dart' show SettingPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SettingPageModel extends FlutterFlowModel<SettingPageWidget> {
  SettingsData? settingsData;
  bool isLoading = true;
  bool isExporting = false;
  bool isImporting = false;
  bool _disposed = false;

  // 直接暴露状态字段，避免每次读 DB；set 时直接修改 + updatePage 刷新
  String currentBook = 'cet6';
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
    if (isLoading || _disposed) return;
    try {
      final data = await BackendManager.instance.loadSettings();
      if (!_disposed) {
        updatePage(() {
          settingsData = data;
          isLoading = false;
          currentBook = data.currentBook;
          singleSessionLimit = data.singleSessionLimit;
          showEtymology = data.showEtymology;
          showDefinition = data.showDefinition;
          showExample = data.showExample;
          dailyRefreshHour = data.dailyRefreshHour;
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
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

  Future<String?> exportArchive() async {
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
      }

      updatePage(() => isExporting = false);
      return result;
    } catch (e) {
      updatePage(() => isExporting = false);
      return null;
    }
  }

  Future<ImportResult?> importArchive() async {
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
        return importResult;
      }

      updatePage(() => isImporting = false);
      return null;
    } catch (e) {
      updatePage(() => isImporting = false);
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}