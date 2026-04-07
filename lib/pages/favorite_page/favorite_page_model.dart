import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'favorite_page_widget.dart' show FavoritePageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class FavoritePageModel extends FlutterFlowModel<FavoritePageWidget> {
  List<FavoriteItemData> items = [];
  String collectionCount = '已收藏:0';
  String remaining = '剩余：0';
  String currentCollection = '当前收藏夹：0/0';
  bool isLoading = false;
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (isLoading || _disposed) return;
    try {
      final items = await BackendManager.instance.loadFavorites();
      if (!_disposed) {
        updatePage(() {
          this.items = items;
          collectionCount = '已收藏:${items.length}';
          final remainingCount = 100 - items.length;
          remaining = '剩余：$remainingCount';
          currentCollection = '当前收藏夹：${items.length}/100';
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  Future<void> removeFavorite(String uuid) async {
    await BackendManager.instance.toggleFavorite(uuid);
    await _loadData();
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
