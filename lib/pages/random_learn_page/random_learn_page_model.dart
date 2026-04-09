import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'random_learn_page_widget.dart' show RandomLearnPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';
import 'package:demo1red/backend/tts_service.dart';
import 'package:demo1red/backend/tts_service.dart';

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

      // 从语义阅读页点词进来的单卡会话：学完后返回同一篇文章
      if (session != null && session.canResumeTopicReading) {
        final articleId = session.resumeArticleId ?? 'art_tech_read_01';
        final topicId = session.resumeTopicId ?? 'topic_tech_read';
        print('[Learn] 回流到阅读页 articleId=$articleId');
        ctx.go('/topicReadingPage1?articleId=$articleId&topicId=$topicId');
        return;
      }

      // 普通学习流程
      if (BackendManager.instance.hasSession &&
          BackendManager.instance.hasNextCard) {
        ctx.pushNamed(RandomAskPageWidget.routeName);
      } else {
        ctx.push('${ResultPageWidget.routePath}?fromRandomLearn=true');
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

  /// 播放单词发音（SRS&SDD v2.1 第 7.1 节）
  Future<void> speakWord() async {
    if (cardData == null) return;
    final word = cardData!.spelling;
    if (word.isEmpty) return;
    final ok = await TTSService.instance.speak(word);
    if (!ok && !_disposed) {
      // TTS 不可用，静默失败（不打断学习流程）
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
