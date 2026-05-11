import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TreePageModel extends FlutterFlowModel<TreePageWidget> {
  bool _disposed = false;

  TreePageData? pageData;
  bool isLoading = true;
  String currentRootId = 're';

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    // 仅初始化 currentRootId，不加载数据
    // 注意：此时 widget 尚未设置到 _widget，故不能在此调用 _loadData
    final initialRootId = widget?.rootId;
    if (initialRootId != null && initialRootId.isNotEmpty) {
      currentRootId = initialRootId;
    }
  }

  @override
  void onInitialized() {
    // _widget 在此时已就绪，可安全读取 rootId 并加载数据
    final safeRootId = widget?.rootId;
    if (safeRootId != null && safeRootId.isNotEmpty) {
      currentRootId = safeRootId;
    }
    _loadData(currentRootId);
  }

  Future<void> _loadData(String rootId) async {
    if (_disposed) return;
    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadTreePageData(rootId);
      if (_disposed) return;
      updatePage(() {
        pageData = data;
        isLoading = false;
      });
    } catch (e) {
      if (!_disposed && context != null) {
        updatePage(() => isLoading = false);
        final ctx = context;
        if (ctx != null) ctx.pushNamed(ErrorPageWidget.routeName);
      }
    }
  }

  Future<void> finishLearning(BuildContext context) async {
    try {
      final session = BackendManager.instance.getStudySession();
      final uuids = session?.learnedCards.map((c) => c.conceptUuid).toList() ?? [];
      final spellings = await BackendManager.instance.getSpellingsByUuids(uuids);
      final encoded = Uri.encodeComponent(jsonEncode(spellings));
      context.push('${ResultPageWidget.routePath}?fromTreeLearning=true&learnedSpellings=$encoded');
    } catch (e) {
      if (!_disposed) context.pushNamed(ErrorPageWidget.routeName);
    }
  }

  void reloadPage(BuildContext context) {
    context.go('/treePage?rootId=$currentRootId');
  }

  /// 重新加载指定词根的数据（用于路由参数变化时）
  Future<void> reloadData(String rootId) async {
    if (rootId.isEmpty) return;
    currentRootId = rootId;
    await _loadData(rootId);
  }

  String get rootName => pageData?.rootName ?? '';
  String get rootDefinition => pageData?.rootDefinition ?? '';
  String get rootOrigin => pageData?.rootOrigin ?? '';
  String get rootFunction => pageData?.rootFunction ?? '';
  List get words => pageData?.words ?? [];

  @override
  void dispose() {
    _disposed = true;
  }
}
