import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'quick_learn_page2_widget.dart' show QuickLearnPage2Widget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class QuickLearnPage2Model extends FlutterFlowModel<QuickLearnPage2Widget> {
  List<QuickLearnItemData> items = [];
  String progressText = '本次已标注: 0 个';
  bool isLoading = true;
  bool _disposed = false;

  bool get hasNext => BackendManager.instance.hasNextQuickLearnPage();
  bool get hasPrev => BackendManager.instance.hasPrevQuickLearnPage();

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    try {
      final settings = await BackendManager.instance.loadSettings();
      await BackendManager.instance.initQuickLearnSession(limit: 70);
      if (!_disposed) {
        final loadedItems = await BackendManager.instance.getSessionCardsWithNote();
        if (!_disposed) {
          updatePage(() {
            items = loadedItems;
            progressText = BackendManager.instance.getQuickLearnProgress();
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  Future<void> refreshItems() async {
    final loadedItems = await BackendManager.instance.getSessionCardsWithNote();
    if (!_disposed) {
      updatePage(() {
        items = loadedItems;
        progressText = BackendManager.instance.getQuickLearnProgress();
      });
    }
  }

  /// 切换认识/默认状态（两个状态来回切换）
  Future<void> toggleKnown(int index) async {
    await BackendManager.instance.toggleQuickLearnKnown(index);
    await refreshItems();
  }

  /// 加载下一页
  Future<void> nextPage() async {
    await BackendManager.instance.loadNextQuickLearnPage();
    await refreshItems();
  }

  /// 加载上一页
  Future<void> prevPage() async {
    await BackendManager.instance.loadPrevQuickLearnPage();
    await refreshItems();
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
