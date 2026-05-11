import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'reports_page_widget.dart' show ReportsPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';

class ReportsPageModel extends FlutterFlowModel<ReportsPageWidget> {
  ReportsPageData? reportData;
  bool isLoading = true;
  bool _disposed = false;

  String get userName => reportData?.userNameText ?? 'Hi,';
  String get totalStudyTimeText => reportData?.totalStudyTimeText ?? '总学习时长：--';
  String get totalStudyCountText => reportData?.totalStudyCountText ?? '累计学习：--词';
  String get totalReviewCountText => reportData?.totalReviewCountText ?? '累计复习：--词';
  String get totalDaysText => reportData?.totalDaysText ?? '共学习：--天';
  String get bookProgressText => reportData?.bookProgressText ?? '--';
  String get ratingDistributionText => reportData?.ratingDistributionText ?? 'again:0% | hard:0% | good:0% | easy:0%';
  String get matureRateText => reportData?.matureRateText ?? '成熟转化率：--%';
  String get forgotRateText => reportData?.forgotRateText ?? '成熟词汇失忆率：--%';
  String get throughputText => reportData?.throughputText ?? '认知吞吐量：--词/min';
  String get backlogText => reportData?.backlogText ?? '历史积压复习量：--词';

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (_disposed) return;
    isLoading = true;
    try {
      final data = await BackendManager.instance.loadReportsData();
      if (!_disposed) {
        updatePage(() {
          reportData = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!_disposed) updatePage(() => isLoading = false);
    }
  }

  Future<void> refresh() async {
    _disposed = false;
    isLoading = true;
    await _loadData();
  }

  Future<void> saveUserName(String name) async {
    final trimmed = name.trim();
    await BackendManager.instance.updateSetting('user_name', trimmed);
    await _loadData();
  }

  @override
  void dispose() {
    _disposed = true;
  }
}
