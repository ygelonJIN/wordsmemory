import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'topic_reading_page1_widget.dart' show TopicReadingPage1Widget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicReadingPage1Model extends FlutterFlowModel<TopicReadingPage1Widget> {
  TopicReadingPageData? pageData;
  bool isLoading = true;
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    final articleId = widget?.articleId ?? 'article_1';
    _loadData(articleId);
  }

  Future<void> _loadData(String articleId) async {
    if (isLoading || _disposed) return;
    try {
      final data = await BackendManager.instance.loadArticle(articleId);
      if (!_disposed) {
        updatePage(() {
          pageData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  Future<void> onWordTap(String? uuid) async {
    if (uuid == null || uuid.isEmpty) return;
    final ctx = context;
    if (ctx == null) return;
    try {
      await BackendManager.instance.visitTopicWord(uuid);
        ctx.pushNamed(RandomLearnPageWidget.routeName);
    } catch (e) {
      ctx.pushNamed(ErrorPageWidget.routeName);
    }
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
