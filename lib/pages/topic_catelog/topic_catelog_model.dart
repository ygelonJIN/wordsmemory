
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
    _loadData();
  }

  Future<void> _loadData() async {
    if (isLoading || _disposed) return;
    final ctx = context;
    if (ctx == null) return;
    try {
      updatePage(() => isLoading = true);
      final rawTopics = await BackendManager.instance.loadTopics();
      final loaded = <TopicItemModel>[];

      for (final t in rawTopics) {
        final articles = await BackendManager.instance.topicManager.getArticlesByTopic(t.topicId);
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
    } catch (e) {
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
