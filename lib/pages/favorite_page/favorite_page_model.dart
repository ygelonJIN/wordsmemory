import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'favorite_page_widget.dart' show FavoritePageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class FavoritePageModel extends FlutterFlowModel<FavoritePageWidget> {
  bool _disposed = false;

  List<FavoriteItemData> items = [];
  String collectionCount = '已收藏:0';
  String currentCollection = '0/0';
  String remaining = '0';
  bool isLoading = false;

  bool get isEmpty => items.isEmpty && !isLoading;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (isLoading || _disposed) return;
    try {
      isLoading = true;
      final items = await BackendManager.instance.loadFavorites();
      final totalCount = await queryFavoriteCount(BackendManager.instance.hotDb!);
      final learned = await queryFavoriteLearnedCount(BackendManager.instance.hotDb!);
      final now = DateTime.now().millisecondsSinceEpoch;
      final dueCount = await queryDueFavoriteLearnedCount(BackendManager.instance.hotDb!, now);
      if (!_disposed) {
        updatePage(() {
          this.items = items;
          collectionCount = '已收藏:$totalCount';
          remaining = '$dueCount';
          currentCollection = '$learned/$totalCount';
          isLoading = false;
        });
      }
    } catch (e, st) {
      print('[Favorite] _loadData 异常: $e $st');
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  Future<void> refresh() async {
    await _loadData();
  }

  Future<void> removeFavorite(String uuid) async {
    await BackendManager.instance.toggleFavorite(uuid);
    await _loadData();
  }

  Future<void> onWordTap(String conceptUuid) async {
    final ctx = context;
    if (ctx == null) return;
    try {
      await BackendManager.instance.startFavoriteWordSession(conceptUuid);
      ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[Favorite] onWordTap 异常: $e');
    }
  }

  Future<void> startFavoriteReviewSession() async {
    final ctx = context;
    if (ctx == null) return;
    if (isEmpty) return;
    try {
      await BackendManager.instance.createFavoriteReviewSession();
      ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[Favorite] startFavoriteReviewSession 异常: $e');
    }
  }

  Future<void> startFavoriteLearnSession() async {
    final ctx = context;
    if (ctx == null) return;
    if (isEmpty) return;
    try {
      await BackendManager.instance.createFavoriteLearnSession();
      ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[Favorite] startFavoriteLearnSession 异常: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
