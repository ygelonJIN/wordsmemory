
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'topic_catelog_widget.dart' show TopicCatelogWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicItemModel {
  final String topicId;
  final String topicName;
  final String topicNameEn;
  final int wordCount;
  final List<String> articleIds;

  TopicItemModel({
    required this.topicId,
    required this.topicName,
    required this.topicNameEn,
    required this.wordCount,
    this.articleIds = const [],
  });
}

class TopicCatelogModel extends FlutterFlowModel<TopicCatelogWidget> {
  List<TopicItemModel> topics = [];
  bool isLoading = true;
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    print('[TopicCatalog-Model] initState START, isLoading=$isLoading');
    // 不再在这里调用 _loadData，改用 onInitialized 钩子
    print('[TopicCatalog-Model] initState END');
  }

  @override
  void onInitialized() {
    // _context 已设置好，调用 _loadData
    _loadData();
  }

  Future<void> _loadData() async {
    print('[TopicCatalog-Model] _loadData ENTER, isLoading=$isLoading, _disposed=$_disposed');
    if (_disposed) {
      print('[TopicCatalog-Model] _loadData: _disposed=true, return early');
      return;
    }
    final ctx = context;
    if (ctx == null) return;
    try {
      updatePage(() => isLoading = true);

      final rawTopics = await BackendManager.instance.loadTopics();
      print('[TopicCatalog-Model] loadTopics 返回 ${rawTopics.length} 个专题');
      final loaded = <TopicItemModel>[];

      for (final t in rawTopics) {
        final articles = await BackendManager.instance.topicManager.getArticlesByTopic(t.topicId);
        print('[TopicCatalog] 专题 ${t.topicId} 含 ${articles.length} 篇文章: ${articles.map((a) => a.articleId)}');
        loaded.add(TopicItemModel(
          topicId: t.topicId,
          topicName: t.topicName,
          topicNameEn: t.topicNameEn,
          wordCount: t.wordCount,
          articleIds: articles.map((a) => a.articleId).toList(),
        ));
      }

      if (!_disposed) {
        updatePage(() {
          topics = loaded;
          isLoading = false;
        });
      }
    } catch (e, st) {
      print('[TopicCatalog] _loadData 异常: $e\n$st');
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  void navigateToReading(String topicId, String? articleId) {
    if (articleId != null) {
      context?.go('/topicReadingPage1?topicId=$topicId&articleId=$articleId');
    } else {
      context?.go('/topicCatelog');
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
