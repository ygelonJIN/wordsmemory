import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'quick_learn_page_widget.dart' show QuickLearnPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class QuickLearnPageModel extends FlutterFlowModel<QuickLearnPageWidget> {
  List<QuickLearnItemData> items = [];
  String progressText = '已筛选:0/0';
  bool isLoading = true;
  bool _disposed = false;

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
      await BackendManager.instance.initQuickLearnSession();
      if (!_disposed) {
        updatePage(() {
          items = BackendManager.instance.getQuickLearnItems();
          progressText = BackendManager.instance.getQuickLearnProgress();
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  Future<void> markKnown(int index) async {
    await BackendManager.instance.markQuickLearnKnown(index);
    updatePage(() {
      items = BackendManager.instance.getQuickLearnItems();
      progressText = BackendManager.instance.getQuickLearnProgress();
    });
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
