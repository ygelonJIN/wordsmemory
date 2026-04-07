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
    final rootId = widget?.rootId ?? 're';
    _loadData(rootId);
  }

  Future<void> _loadData(String rootId) async {
    if (isLoading || _disposed) return;
    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadTreePageData(rootId);
      if (!_disposed) {
        updatePage(() {
          pageData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
