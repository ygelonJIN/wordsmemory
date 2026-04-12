import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'random_ask_page_widget.dart' show RandomAskPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class RandomAskPageModel extends FlutterFlowModel<RandomAskPageWidget> {
  RandomLearnPageData? cardData;
  bool isLoading = true;
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

  Future<void> refreshData() async {
    await _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      updatePage(() => isLoading = true);
      var data = await BackendManager.instance.loadRandomAskCard();
      // 仅当会话为空时才创建全局学习会话（避免覆盖从阅读页注入的单卡会话）
      if (data == null) {
        final hasSession = BackendManager.instance.hasSession;
        if (!hasSession) {
          final settings = await BackendManager.instance.loadSettings();
          await BackendManager.instance.createLearnSession(
            limit: settings.singleSessionLimit,
            bookId: settings.currentBook,
          );
          data = await BackendManager.instance.loadRandomAskCard();
        }
      }
      if (_disposed) return;
      updatePage(() {
        if (data == null) {
          hasError = true;
          ctx.push('${ResultPageWidget.routePath}?fromRandomLearn=true');
        } else {
          cardData = data;
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

  /// Ask 页面点击评级：纯预览，只读不落盘
  /// 设置 pendingPreviewCard 后跳转 Learn，Learn 的 getCurrentCardWithDetails 会返回预览结果
  Future<void> submitRating(int rating) async {
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      updatePage(() => isLoading = true);
      final previewData = await BackendManager.instance.previewRating(rating);
      if (_disposed) return;
      if (previewData == null) {
        updatePage(() {
          isLoading = false;
          hasError = true;
        });
        ctx.pushNamed(ErrorPageWidget.routeName);
        return;
      }
      updatePage(() {
        cardData = previewData;
        hasError = false;
        isLoading = false;
      });
      if (!_disposed) ctx.pushNamed(RandomLearnPageWidget.routeName);
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

  @override
  void dispose() {
    _disposed = true;
  }
}
