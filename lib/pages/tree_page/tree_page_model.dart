import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'tree_page_widget.dart' show TreePageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TreePageModel extends FlutterFlowModel<TreePageWidget> {
  TreePageData? pageData;
  bool isLoading = true;
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    final rootId = widget?.rootId ?? 're';
    _loadData(rootId);
  }

  Future<void> _loadData(String rootId) async {
    if (_disposed) return;
    final ctx = context;
    if (ctx == null) return;

    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadTreePageData(rootId);
      if (_disposed) return;
      updatePage(() {
        pageData = data;
        isLoading = false;
      });
    } catch (e) {
      if (!_disposed) {
        updatePage(() => isLoading = false);
        ctx.pushNamed(ErrorPageWidget.routeName);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
