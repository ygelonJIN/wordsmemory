import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'tree_page_widget.dart' show TreePageWidget;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:demo1red/backend/provider.dart';

class TreePageModel extends FlutterFlowModel<TreePageWidget> {
  TreePageData? pageData;
  bool isLoading = true;
  bool _disposed = false;
  /// 记录当前页面的 rootId，供 next 按钮使用
  String currentRootId = 're';

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    // 优先从 URL 查询参数解析 rootId，回退到 widget.rootId 或默认值 're'
    String rootId = widget?.rootId ?? 're';
    if (context != null) {
      final uri = GoRouter.of(context!).routeInformationProvider.value.uri;
      if (uri.queryParameters.containsKey('rootId')) {
        rootId = uri.queryParameters['rootId']!;
      }
    }
    currentRootId = rootId;
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

  /// Finish：提取当前会话中学过的单词，转为拼写列表，跳转到 ResultPage
  Future<void> finishLearning(BuildContext context) async {
    final ctx = context;
    if (ctx == null) return;
    try {
      final session = BackendManager.instance.getStudySession();
      final uuids = session?.learnedCards.map((c) => c.conceptUuid).toList() ?? [];
      final spellings = await BackendManager.instance.getSpellingsByUuids(uuids);
      final encoded = Uri.encodeComponent(jsonEncode(spellings));
      ctx.push('${ResultPageWidget.routePath}?fromTreeLearning=true&learnedSpellings=$encoded');
    } catch (e) {
      if (!_disposed) ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  /// Next：重新加载当前树页面（刷新）
  void reloadPage(BuildContext context) {
    final ctx = context;
    if (ctx == null) return;
    ctx.go('/treePage?rootId=$currentRootId');
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
