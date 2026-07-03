import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'quick_learn_page_widget.dart' show QuickLearnPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class QuickLearnPageModel extends FlutterFlowModel<QuickLearnPageWidget> {
  bool _disposed = false;

  List<QuickLearnItemData> items = [];
  String progressText = '本次已标注: 0 个';
  bool isLoading = true;
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
    refreshItems();
  }

  /// 点击单词，跳转到 Learn 页面
  Future<void> onWordTap(String conceptUuid) async {
    final ctx = context;
    if (ctx == null) return;
    try {
      await BackendManager.instance.startQuickLearnWordSession(conceptUuid);
      ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[QuickLearn] onWordTap 异常: $e');
      ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  /// 加载下一页
  Future<void> nextPage() async {
    await BackendManager.instance.loadNextQuickLearnPage();
    refreshItems();
  }

  /// 加载上一页
  Future<void> prevPage() async {
    await BackendManager.instance.loadPrevQuickLearnPage();
    refreshItems();
  }

  /// 结束快速筛选：仅当列表非空时允许进入结果页
  Future<void> onFinish() async {
    final ctx = context;
    if (ctx == null) return;
    if (items.isEmpty || isLoading) return;
    ctx.push('${ResultPageWidget.routePath}?fromQuickLearn=true');
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
