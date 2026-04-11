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
  bool _loading = false; // 防止 onInitialized 和 didUpdateWidget 的两次 _loadData 并发
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
    final articleId = widget?.articleId ?? 'art_tech_read_01';
    topicId = widget?.topicId ?? 'topic_tech_read';
    print('[TopicReading1] onInitialized articleId=$articleId');
    _loadData(articleId);
  }

  Future<void> refreshData(String articleId) async {
    if (_disposed) return;
    print('[TopicReading1] refreshData articleId=$articleId');
    await _loadData(articleId);
  }

  Future<void> _loadData(String articleId) async {
    if (_disposed) return;
    if (_loading) return;
    _loading = true;
    final ctx = context;
    if (ctx == null) { _loading = false; return; }
    print('[TopicReading1] _loadData 开始 articleId=$articleId _pageReady=$_pageReady');

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
        if (articlesInfo != null && articlesInfo.articles.isNotEmpty) {
          computedHasPrevious = articlesInfo.hasPrevious;
          computedHasNext = articlesInfo.hasNext;
          // 添加额外的边界检查，防止并发修改导致越界
          if (articlesInfo.hasNext && articlesInfo.currentIndex + 1 < articlesInfo.articles.length) {
            computedNext = articlesInfo.articles[articlesInfo.currentIndex + 1].articleId;
          }
          if (articlesInfo.hasPrevious && articlesInfo.currentIndex > 0) {
            computedPrev = articlesInfo.articles[articlesInfo.currentIndex - 1].articleId;
          }
        }
        print('[TopicReading1] 文章导航: hasPrevious=$computedHasPrevious hasNext=$computedHasNext next=$computedNext prev=$computedPrev');
      }

      if (_disposed) { _loading = false; return; }
      updatePage(() {
        pageData = data;
        nextArticleId = computedNext;
        previousArticleId = computedPrev;
        hasPrevious = computedHasPrevious;
        hasNext = computedHasNext;
        isLoading = false;
      });
      print('[TopicReading1] _loadData 完成: readCountText=${data?.readCountText} wordCountText=${data?.wordCountText}');
    } catch (e, st) {
      print('[TopicReading1] _loadData 异常: $e\n$st');
      if (!_disposed) {
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
      print('[TopicReading1] onWordTap uuid=$uuid');
      await BackendManager.instance.visitTopicWord(uuid);
      print('[TopicReading1] visitTopicWord 完成');
      final articleId = widget?.articleId ?? 'art_tech_read_01';
      final tid = widget?.topicId ?? 'topic_tech_read';
      await BackendManager.instance.startTopicReadingWordSession(uuid, articleId, tid);
      print('[TopicReading1] startTopicReadingWordSession 完成');
      ctx.pushNamed(RandomAskPageWidget.routeName);
      print('[TopicReading1] 跳转到 Ask 页面');
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
