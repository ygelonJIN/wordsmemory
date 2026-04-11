import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'topic_reading_page2_widget.dart' show TopicReadingPage2Widget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicReadingPage2Model extends FlutterFlowModel<TopicReadingPage2Widget> {
  TopicReadingPageData? pageData;
  bool isLoading = true;
  bool _disposed = false;
  bool _pageReady = false;
  bool _loading = false; // 防止并发 _loadData
  String? nextArticleId;
  String? previousArticleId;
  bool hasPrevious = false;
  bool hasNext = false;
  String? topicId;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    topicId = widget?.topicId ?? 'topic_tech_read';
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    if (_loading) return;
    _loading = true;
    final ctx = context;
    if (ctx == null) { _loading = false; return; }
    _pageReady = true;

    try {
      updatePage(() => isLoading = true);
      final articleId = widget?.articleId ?? 'art_tech_read_02';
      final data = await BackendManager.instance.loadArticle(articleId);
      final tid = topicId ?? 'topic_tech_read';

      // 计算是否有上一篇和下一篇
      String? computedNext;
      String? computedPrev;
      bool computedHasPrevious = false;
      bool computedHasNext = false;

      if (tid.isNotEmpty) {
        final articlesInfo = await BackendManager.instance.getTopicArticlesWithIndex(tid, articleId);
        if (articlesInfo != null) {
          computedHasPrevious = articlesInfo.hasPrevious;
          computedHasNext = articlesInfo.hasNext;
          if (articlesInfo.hasNext) {
            computedNext = articlesInfo.articles[articlesInfo.currentIndex + 1].articleId;
          }
          if (articlesInfo.hasPrevious) {
            computedPrev = articlesInfo.articles[articlesInfo.currentIndex - 1].articleId;
          }
        }
      }

      if (_disposed || !_pageReady) { _loading = false; return; }
      updatePage(() {
        pageData = data;
        nextArticleId = computedNext;
        previousArticleId = computedPrev;
        hasPrevious = computedHasPrevious;
        hasNext = computedHasNext;
        isLoading = false;
      });
    } catch (e) {
      if (!_disposed && _pageReady) {
        updatePage(() => isLoading = false);
        ctx.pushNamed(ErrorPageWidget.routeName);
      }
    }
    _loading = false;
  }

  Future<void> onWordTap(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return;
    final ctx = context;
    if (ctx == null) return;
    try {
      await BackendManager.instance.visitTopicWord(uuid);
      final articleId = widget?.articleId ?? 'art_tech_read_02';
      final tid = topicId ?? 'topic_tech_read';
      await BackendManager.instance.startTopicReadingWordSession(uuid, articleId, tid);
      await ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[TopicReading2] onWordTap 异常: $e');
      ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  void onNextArticle() {
    final ctx = context;
    if (ctx == null || nextArticleId == null) return;
    final tid = topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$nextArticleId&topicId=$tid');
  }

  void onBackArticle() {
    final ctx = context;
    if (ctx == null || previousArticleId == null) return;
    final tid = topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$previousArticleId&topicId=$tid');
  }

  Future<void> onFinish() async {
    final ctx = context;
    if (ctx == null) return;
    // 如果有活跃会话，获取本次学习的 UUID 列表后传给 ResultPage
    if (BackendManager.instance.hasSession) {
      final learnedUuids = BackendManager.instance.getStudySession()?.learnedCards
              .map((c) => c.conceptUuid)
              .toList() ??
          [];
      final spellings = await BackendManager.instance.getSpellingsByUuids(learnedUuids);
      final spellingsEncoded = Uri.encodeComponent(jsonEncode(spellings));
      ctx.push('${ResultPageWidget.routePath}?fromSemanticReading=true&learnedSpellings=$spellingsEncoded');
    } else {
      ctx.push('${ResultPageWidget.routePath}?fromSemanticReading=true');
    }
  }

  @override
  void dispose() {
    _pageReady = false;
    _disposed = true;
  }
}
