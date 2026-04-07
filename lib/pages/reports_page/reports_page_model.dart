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
  String get totalDaysText => reportData?.totalDaysText ?? '共学习：--天';
  String get bookProgressText => reportData?.bookProgressText ?? '已学词书：--';
  String get monthlySummaryText => reportData?.monthlySummaryText ?? '';
  String get yearlySummaryText => reportData?.yearlySummaryText ?? '';

  List<String> get monthlySummaryRows {
    final stats = reportData?.monthlyStats ?? [];
    return stats.map((s) {
      final rate = (s.goodRate * 100).toStringAsFixed(0);
      return '${s.yearMonth}: ${s.reviewCount}词/$rate%良';
    }).toList();
  }

  List<String> get yearlySummaryRows {
    final stats = reportData?.yearlyStats ?? {};
    final entries = stats.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return entries.map((e) => '${e.key}年: ${e.value.reviewCount}词').toList();
  }

  bool get hasMonthlyData => (reportData?.monthlyStats ?? []).isNotEmpty;
  bool get hasYearlyData => (reportData?.yearlyStats ?? {}).isNotEmpty;

  @override
  void initState(BuildContext context) {
    updateOnChange = true;
    _loadData();
  }

  Future<void> _loadData() async {
    if (isLoading || _disposed) return;
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

  @override
  void dispose() {
    _disposed = true;
  }
}
