import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class RandomLearnPage2Model extends FlutterFlowModel<RandomLearnPage2Widget> {
  RandomLearnPageData? cardData;
  bool isLoading = true;
  bool isFavorite = false;
  bool hasError = false;
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
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadRandomLearn2Card();
      if (_disposed) return;
      updatePage(() {
        if (data == null) {
          hasError = true;
          ctx.pushNamed(ResultPageWidget.routeName);
        } else {
          cardData = data;
          isFavorite = data.isFavorite;
          hasError = false;
        }
        isLoading = false;
      });
    } catch (e) {
      if (!_disposed) {
        updatePage(() {
          isLoading = false;
          hasError = true;
        });
        ctx.pushNamed(ErrorPageWidget.routeName);
      }
    }
  }

  /// Learn 页面点击评级：确定评级，落盘 + 推进
  Future<void> submitRating(int rating) async {
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      await BackendManager.instance.confirmPendingRating(rating);
      await _loadData();
    } catch (e) {
      if (!_disposed) ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  Future<void> toggleFavorite() async {
    if (cardData == null || _disposed) return;
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      await BackendManager.instance.toggleFavorite(cardData!.conceptUuid);
      updatePage(() => isFavorite = !isFavorite);
    } catch (e) {
      if (!_disposed) ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  Future<void> undo() async {
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      await BackendManager.instance.undo();
      await _loadData();
    } catch (e) {
      if (!_disposed) ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
