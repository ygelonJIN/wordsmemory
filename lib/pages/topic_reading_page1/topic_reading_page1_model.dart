import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicReadingPage1Model extends FlutterFlowModel<TopicReadingPage1Widget> {
  TopicReadingPageData? pageData;
  bool isLoading = true;
  bool _disposed = false;
  String? _pendingArticleId;
  String? nextArticleId;
  String? previousArticleId;
  bool hasPrevious = false;
  bool hasNext = false;
  String? topicId;
  int currentIndex = 0;
  int totalCount = 0;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
  }

  @override
  void onInitialized() {
    final articleId = widget?.articleId ?? 'art_tech_read_01';
    topicId = widget?.topicId ?? 'topic_tech_read';
    _pendingArticleId = articleId;
    print('[TopicReading1] ★ onInitialized articleId=$articleId topicId=$topicId');
    _loadData(articleId);
  }

  Future<void> refreshData(String articleId) async {
    _disposed = false;  // 重置，允许重新进入
    _pendingArticleId = articleId;
    print('[TopicReading1] ★ refreshData articleId=$articleId _pendingArticleId=$_pendingArticleId _disposed=$_disposed');
    await _loadData(articleId);
  }

  void updateTopicId(String? newTopicId) {
    if (newTopicId == null) return;
    topicId = newTopicId;
  }

  Future<void> _loadData(String articleId) async {
    if (_disposed) {
      print('[TopicReading1] ★ _loadData BLOCKED _disposed=true articleId=$articleId');
      return;
    }
    final ctx = context;
    if (ctx == null) {
      print('[TopicReading1] ★ _loadData BLOCKED context=null articleId=$articleId');
      return;
    }

    print('[TopicReading1] ★ _loadData entry articleId=$articleId _pendingArticleId=$_pendingArticleId _disposed=$_disposed');

    // 忽略过期请求
    if (_pendingArticleId != articleId) {
      print('[TopicReading1] ★ _loadData 忽略过期结果 articleId=$articleId (期望=$_pendingArticleId)');
      return;
    }

    print('[TopicReading1] _loadData 开始 articleId=$articleId');

    try {
      final data = await BackendManager.instance.loadArticle(articleId);
      print('[TopicReading1] loadArticle 返回: ${data == null ? "null" : "非null, articleId=${data.articleId}"}');

      final tid = data?.topicId ?? widget?.topicId ?? 'topic_tech_read';

      // 计算是否有上一篇和下一篇
      String? computedNext;
      String? computedPrev;
      bool computedHasPrevious = false;
      bool computedHasNext = false;

      if (tid.isNotEmpty) {
        final articlesInfo = await BackendManager.instance.getTopicArticlesWithIndex(tid, articleId);
        print('[TopicReading1] ★ getTopicArticlesWithIndex tid=$tid articleId=$articleId --> articlesInfo=${articlesInfo == null ? "null" : "non-null: count=${articlesInfo.articles.length} index=${articlesInfo.currentIndex} hasNext=${articlesInfo.hasNext} hasPrev=${articlesInfo.hasPrevious}"}');
        if (articlesInfo != null && articlesInfo.articles.isNotEmpty) {
          computedHasPrevious = articlesInfo.hasPrevious;
          computedHasNext = articlesInfo.hasNext;
          currentIndex = articlesInfo.currentIndex;
          totalCount = articlesInfo.articles.length;
          if (articlesInfo.hasNext && articlesInfo.currentIndex + 1 < articlesInfo.articles.length) {
            computedNext = articlesInfo.articles[articlesInfo.currentIndex + 1].articleId;
          }
          if (articlesInfo.hasPrevious && articlesInfo.currentIndex > 0) {
            computedPrev = articlesInfo.articles[articlesInfo.currentIndex - 1].articleId;
          }
        }
        print('[TopicReading1] ★ 导航计算: computedNext=$computedNext computedPrev=$computedPrev computedHasNext=$computedHasNext computedHasPrev=$computedHasPrevious');
      }

      // 双重检查：过期则丢弃
      if (_pendingArticleId != articleId) {
        print('[TopicReading1] ★ 结果已过期，跳过更新 articleId=$articleId');
        return;
      }

      if (_disposed) {
        print('[TopicReading1] ★ _loadData BLOCKED after await _disposed=true');
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
      print('[TopicReading1] ★ _loadData 完成: nextArticleId=$nextArticleId previousArticleId=$previousArticleId hasNext=$hasNext hasPrevious=$hasPrevious');
    } catch (e, st) {
      print('[TopicReading1] _loadData 异常: $e\n$st');
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
      print('[TopicReading1] onWordTap uuid=$uuid');
      // 验证 uuid 是否为有效概念词
      final conceptExists = await BackendManager.instance.checkConceptExists(uuid);
      if (!conceptExists) {
        print('[TopicReading1] uuid $uuid 不在词库中，取消跳转');
        return;
      }
      await BackendManager.instance.visitTopicWord(uuid);
      print('[TopicReading1] visitTopicWord 完成');
      final articleId = pageData?.articleId ?? widget?.articleId ?? 'art_tech_read_01';
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
    print('[TopicReading1] ★ onNextArticle called: nextArticleId=$nextArticleId context=${ctx != null}');
    if (ctx == null || nextArticleId == null) return;
    final tid = widget?.topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$nextArticleId&topicId=$tid');
  }

  void onBackArticle() {
    final ctx = context;
    print('[TopicReading1] ★ onBackArticle called: previousArticleId=$previousArticleId context=${ctx != null}');
    if (ctx == null || previousArticleId == null) return;
    final tid = widget?.topicId ?? 'topic_tech_read';
    ctx.go('/topicReadingPage1?articleId=$previousArticleId&topicId=$tid');
  }

  Future<void> jumpToArticle(int index) async {
    final ctx = context;
    if (ctx == null || totalCount == 0) return;
    if (index < 1 || index > totalCount) {
      print('[TopicReading1] ★ jumpToArticle invalid index=$index (total=$totalCount)');
      return;
    }
    final tid = widget?.topicId ?? 'topic_tech_read';
    try {
      final targetId = await BackendManager.instance.getArticleIdByIndex(tid, index - 1);
      if (targetId != null) {
        print('[TopicReading1] ★ jumpToArticle index=$index --> articleId=$targetId');
        ctx.go('/topicReadingPage1?articleId=$targetId&topicId=$tid');
      }
    } catch (e) {
      print('[TopicReading1] ★ jumpToArticle error: $e');
    }
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
    print('[TopicReading1] ★ dispose called');
    _disposed = true;
  }
}
