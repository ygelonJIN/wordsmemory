import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'random_learn_page_widget.dart' show RandomLearnPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class RandomLearnPageModel extends FlutterFlowModel<RandomLearnPageWidget> {
  RandomLearnPageData? cardData;
  bool isLoading = true;
  bool isFavorite = false;
  bool hasError = false;
  bool _disposed = false;

  // 学习辅助显示开关
  bool showEtymology = true;
  bool showDefinition = true;
  bool showExample = true;

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
      final data = await BackendManager.instance.loadRandomLearnCard();
      final settings = await BackendManager.instance.loadSettings();
      if (_disposed) return;
      updatePage(() {
        if (data == null) {
          hasError = true;
        } else {
          cardData = data;
          isFavorite = data.isFavorite;
          hasError = false;
          showEtymology = settings.showEtymology;
          showDefinition = settings.showDefinition;
          showExample = settings.showExample;
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

  Future<void> submitRating(int rating) async {
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      final session = BackendManager.instance.getStudySession();
      final pendingRating = session?.pendingRating;
      if (pendingRating == null) return; // No pending rating, should not happen
      await BackendManager.instance.confirmPendingRating(pendingRating);
      if (BackendManager.instance.hasSession &&
          BackendManager.instance.hasNextCard) {
        ctx.pushNamed(RandomAskPageWidget.routeName);
      } else {
        ctx.pushNamed(ResultPageWidget.routeName);
      }
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

  Future<void> undoRating() async {
    final ctx = context;
    if (ctx == null || _disposed) return;
    try {
      await BackendManager.instance.undo();
      await _loadData();
      if (!_disposed) {
        ctx.pop(); // 返回 Ask 页面重新显示同一张卡
      }
    } catch (e) {
      if (!_disposed) ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
