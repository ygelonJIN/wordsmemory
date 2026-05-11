import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicReadingPage2Model extends FlutterFlowModel<TopicReadingPage2Widget> {
  TopicReadingPageData? pageData;
  bool isLoading = true;
  bool _disposed = false;
  String? _pendingArticleId;
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
    _pendingArticleId = widget?.articleId ?? 'art_tech_read_02';
    print('[TopicReading2] ★ onInitialized articleId=$_pendingArticleId topicId=$topicId');
    _loadData(widget?.articleId ?? 'art_tech_read_02');
  }

  Future<void> refreshData(String articleId) async {
    _disposed = false;
    _pendingArticleId = articleId;
    print('[TopicReading2] ★ refreshData articleId=$articleId _pendingArticleId=$_pendingArticleId _disposed=$_disposed');
    await _loadData(articleId);
  }

  void updateTopicId(String? newTopicId) {
    if (newTopicId == null) return;
    topicId = newTopicId;
  }

  Future<void> _loadData([String? articleIdOverride]) async {
    if (_disposed) {
      print('[TopicReading2] ★ _loadData BLOCKED _disposed=true articleId=$articleIdOverride');
      return;
    }
    final ctx = context;
    if (ctx == null) {
      print('[TopicReading2] ★ _loadData BLOCKED context=null');
      return;
    }

    final articleId = articleIdOverride ?? widget?.articleId ?? 'art_tech_read_02';

    print('[TopicReading2] ★ _loadData entry articleId=$articleId _pendingArticleId=$_pendingArticleId _disposed=$_disposed');

    // 忽略过期请求
    if (_pendingArticleId != articleId) {
      print('[TopicReading2] ★ _loadData 忽略过期结果 articleId=$articleId (期望=$_pendingArticleId)');
      return;
    }

    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadArticle(articleId);
      final tid = data?.topicId ?? widget?.topicId ?? topicId ?? 'topic_tech_read';

      // 计算是否有上一篇和下一篇
      String? computedNext;
      String? computedPrev;
      bool computedHasPrevious = false;
      bool computedHasNext = false;

      if (tid.isNotEmpty) {
        final articlesInfo = await BackendManager.instance.getTopicArticlesWithIndex(tid, articleId);
        print('[TopicReading2] ★ getTopicArticlesWithIndex tid=$tid articleId=$articleId --> articlesInfo=${articlesInfo == null ? "null" : "non-null: count=${articlesInfo.articles.length} index=${articlesInfo.currentIndex} hasNext=${articlesInfo.hasNext} hasPrev=${articlesInfo.hasPrevious}"}');
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
        print('[TopicReading2] ★ 导航计算: computedNext=$computedNext computedPrev=$computedPrev computedHasNext=$computedHasNext computedHasPrev=$computedHasPrevious');
      }

      // 双重检查：过期则丢弃
      if (_pendingArticleId != articleId) {
        print('[TopicReading2] ★ 结果已过期，跳过更新 articleId=$articleId');
        return;
      }

      if (_disposed) {
        print('[TopicReading2] ★ _loadData BLOCKED after await _disposed=true');
        return;
      }
      updatePage(() {
        pageData = data;
        nextArticleId = computedNext;
        previousArticleId = computedPrev;
        hasPrevious = computedHasPrevious;
        hasNext = computedHasNext;
        isLoading = false;
      });
      print('[TopicReading2] ★ _loadData 完成: nextArticleId=$nextArticleId previousArticleId=$previousArticleId hasNext=$hasNext hasPrevious=$hasPrevious');
    } catch (e) {
      if (!_disposed) {
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
      final articleId = pageData?.articleId ?? widget?.articleId ?? 'art_tech_read_02';
      final tid = widget?.topicId ?? topicId ?? 'topic_tech_read';
      await BackendManager.instance.startTopicReadingWordSession(uuid, articleId, tid);
      await ctx.pushNamed(RandomAskPageWidget.routeName);
    } catch (e) {
      print('[TopicReading2] onWordTap 异常: $e');
      ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  void onNextArticle() {
    final ctx = context;
    print('[TopicReading2] ★ onNextArticle called: nextArticleId=$nextArticleId context=${ctx != null}');
    if (ctx == null || nextArticleId == null) return;
    final tid = widget?.topicId ?? topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$nextArticleId&topicId=$tid');
  }

  void onBackArticle() {
    final ctx = context;
    print('[TopicReading2] ★ onBackArticle called: previousArticleId=$previousArticleId context=${ctx != null}');
    if (ctx == null || previousArticleId == null) return;
    final tid = widget?.topicId ?? topicId ?? 'topic_tech_read';
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
    print('[TopicReading2] ★ dispose called');
    _disposed = true;
  }
}
