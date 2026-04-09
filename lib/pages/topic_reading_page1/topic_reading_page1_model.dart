import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'topic_reading_page1_widget.dart' show TopicReadingPage1Widget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicReadingPage1Model extends FlutterFlowModel<TopicReadingPage1Widget> {
  TopicReadingPageData? pageData;
  bool isLoading = true;
  bool _disposed = false;
  bool _pageReady = false;
  String? nextArticleId;
  String? previousArticleId;
  bool hasPrevious = false;
  bool hasNext = false;
  String? topicId;
  String? _lastArticleId;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    final articleId = widget?.articleId ?? 'art_tech_read_01';
    topicId = widget?.topicId ?? 'topic_tech_read';
    _lastArticleId = articleId;
    _loadData(articleId);
  }

  Future<void> refreshData(String articleId) async {
    if (_disposed) return;
    if (articleId != _lastArticleId) {
      _lastArticleId = articleId;
      await _loadData(articleId);
    }
  }

  Future<void> _loadData(String articleId) async {
    if (_disposed) return;
    final ctx = context;
    if (ctx == null) return;
    _pageReady = true;
    print('[TopicReading1] _loadData articleId=$articleId');

    try {
      final data = await BackendManager.instance.loadArticle(articleId);
      print('[TopicReading1] loadArticle 返回: ${data == null ? "null" : "非null, articleId=${data.articleId}"}');

      final tid = widget?.topicId ?? 'topic_tech_read';

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
        print('[TopicReading1] 文章导航: hasPrevious=$computedHasPrevious hasNext=$computedHasNext next=$computedNext prev=$computedPrev');
      }

      if (_disposed || !_pageReady) return;
      updatePage(() {
        pageData = data;
        nextArticleId = computedNext;
        previousArticleId = computedPrev;
        hasPrevious = computedHasPrevious;
        hasNext = computedHasNext;
        isLoading = false;
      });
    } catch (e, st) {
      print('[TopicReading1] _loadData 异常: $e\n$st');
      if (!_disposed && _pageReady) {
        updatePage(() => isLoading = false);
        ctx.pushNamed(ErrorPageWidget.routeName);
      }
    }
  }

  Future<void> onWordTap(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return;
    final ctx = context;
    if (ctx == null) return;
    try {
      await BackendManager.instance.visitTopicWord(uuid);
      final articleId = widget?.articleId ?? 'art_tech_read_01';
      final tid = widget?.topicId ?? 'topic_tech_read';
      await BackendManager.instance.startTopicReadingWordSession(uuid, articleId, tid);
      ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[TopicReading1] onWordTap 异常: $e');
      ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  void onNextArticle() {
    final ctx = context;
    if (ctx == null || nextArticleId == null) return;
    final tid = widget?.topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$nextArticleId&topicId=$tid');
  }

  void onBackArticle() {
    final ctx = context;
    if (ctx == null || previousArticleId == null) return;
    final tid = widget?.topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$previousArticleId&topicId=$tid');
  }

  void onFinish() {
    final ctx = context;
    if (ctx == null) return;
    ctx.push('${ResultPageWidget.routePath}?fromSemanticReading=true');
  }

  @override
  void dispose() {
    _pageReady = false;
    _disposed = true;
  }
}
