import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'random_ask_page2_widget.dart' show RandomAskPage2Widget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class RandomAskPage2Model extends FlutterFlowModel<RandomAskPage2Widget> {
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

  Future<void> _loadData() async {
    if (_disposed) return;
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadRandomAsk2Card();
      if (_disposed) return;
      updatePage(() {
        if (data == null) {
          hasError = true;
          ctx.pushNamed(ResultPageWidget.routeName);
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
