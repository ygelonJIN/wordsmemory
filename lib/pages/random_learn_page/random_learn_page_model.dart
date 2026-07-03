import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:demo1red/backend/provider.dart';
import 'package:demo1red/backend/tts_service.dart';

class RandomLearnPageModel extends FlutterFlowModel<RandomLearnPageWidget> {
  bool _disposed = false;

  RandomLearnPageData? cardData;
  bool isLoading = true;
  bool isFavorite = false;
  bool hasError = false;
  String? errorMessage;

  // 学习辅助显示开关
  bool showEtymology = true;
  bool showDefinition = true;
  bool showExample = true;
  bool showEnglishDefinition = true;
  bool showSynonym = true;
  bool showTense = true;

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
          showEnglishDefinition = settings.showEnglishDefinition;
          showSynonym = settings.showSynonym;
          showTense = settings.showTense;
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
      print('[Learn] submitRating rating=$rating pendingRating=$pendingRating isSingleCard=${session?.isSingleCardSource}');
      if (pendingRating == null) {
        print('[Learn] ERROR: pendingRating 为 null，这不应该发生');
        updatePage(() {
          errorMessage = '学习状态异常，请返回重试';
        });
        return;
      }

      // 步骤 1：唯一确认落盘点
      await BackendManager.instance.confirmPendingRating(pendingRating);
      print('[Learn] confirmPendingRating 完成');

      // 步骤 2：按来源回流
      if (session != null) {
        final uuid = session.currentCard?.conceptUuid;

        if (session.isFavoriteSource) {
          if (uuid != null) await BackendManager.instance.markTopicWordRead(uuid);
          print('[Learn] 回流到收藏夹');
          ctx.go('/favoritePage');
          return;
        }

        if (session.isQuickLearnSource) {
          if (uuid != null) await BackendManager.instance.markTopicWordRead(uuid);
          print('[Learn] 回流到快速筛选');
          ctx.go('/quickLearnPage');
          return;
        }

        if (session.isTopicReadingSource) {
          if (uuid != null) await BackendManager.instance.markTopicWordRead(uuid);
          final articleId = session.resumeArticleId ?? 'art_tech_read_01';
          final topicId = session.resumeTopicId ?? 'topic_tech_read';
          print('[Learn] 回流到阅读页 articleId=$articleId');
          GoRouter.of(ctx).go('/topicReadingPage1?articleId=$articleId&topicId=$topicId');
          return;
        }

        if (session.isTreeSource) {
          print('[Learn] 回流到结构树 rootId=${session.treeResumeRootId}');
          ctx.go('/treePage?rootId=${session.treeResumeRootId}');
          return;
        }
      }

      // 步骤 3：普通学习 — 有下一张则回 Ask，否则进 ResultPage
      if (BackendManager.instance.hasSession &&
          BackendManager.instance.hasNextCard) {
        ctx.pushNamed(RandomAskPageWidget.routeName);
      } else {
        final learnedUuids = session?.learnedCards.map((c) => c.conceptUuid).toList() ?? [];
        final spellings = await BackendManager.instance.getSpellingsByUuids(learnedUuids);
        final spellingsEncoded = Uri.encodeComponent(jsonEncode(spellings));
        ctx.push('${ResultPageWidget.routePath}?fromRandomLearn=true&learnedSpellings=$spellingsEncoded');
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
