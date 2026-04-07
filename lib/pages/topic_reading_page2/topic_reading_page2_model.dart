import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'topic_reading_page2_widget.dart' show TopicReadingPage2Widget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class TopicReadingPage2Model extends FlutterFlowModel<TopicReadingPage2Widget> {
  TopicReadingPageData? pageData;
  bool isLoading = true;
  bool _disposed = false;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    try {
      updatePage(() => isLoading = true);
      final data = await BackendManager.instance.loadArticle('article_2');
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

  Future<void> onWordTap(String uuid) async {
    await BackendManager.instance.visitTopicWord(uuid);
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
