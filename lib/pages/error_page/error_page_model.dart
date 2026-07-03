import '/flutter_flow/flutter_flow_util.dart';
import 'error_page_widget.dart' show ErrorPageWidget;
import 'package:flutter/material.dart';

/// 错误码到显示文本的映射表（SRS&SDD v2.1 第 8.1 节）
const Map<String, ErrorPageConfig> kErrorCodeConfig = {
  'DB_INTEGRITY_ERROR': ErrorPageConfig(
    title: '本地数据异常',
    guide: '请前往更新或重新安装应用',
  ),
  'SQLITE_ERROR': ErrorPageConfig(
    title: '数据库操作异常',
    guide: '请重启应用',
  ),
  'SQLITE_FULL': ErrorPageConfig(
    title: '设备存储空间不足',
    guide: '请前往清理手机存储空间后重启应用',
  ),
  'PDF_OOM_ERROR': ErrorPageConfig(
    title: 'PDF 生成失败',
    guide: '内存不足，请关闭其他应用后重试',
  ),
  'IMPORT_FORMAT_ERROR': ErrorPageConfig(
    title: '导入文件格式错误',
    guide: '请选择正确的 JSON 文件',
  ),
  'IMPORT_UUID_MISMATCH': ErrorPageConfig(
    title: '导入部分完成',
    guide: '已导入有效词汇进度，失效词汇已丢弃',
  ),
  'EXPORT_ERROR': ErrorPageConfig(
    title: '导出存档失败',
    guide: '请检查存储空间后重试',
  ),
  'TTS_UNAVAILABLE': ErrorPageConfig(
    title: '发音功能暂时不可用',
    guide: '请检查系统语言设置',
  ),
  'BACKEND_NOT_INITIALIZED': ErrorPageConfig(
    title: '应用初始化未完成',
    guide: '请重启应用',
  ),
  'UNKNOWN_ERROR': ErrorPageConfig(
    title: '发生未知错误',
    guide: '请重启应用',
  ),
  'IN_DEVELOPMENT': ErrorPageConfig(
    title: '功能开发中',
    guide: '此功能正在开发中，敬请期待',
  ),
};

class ErrorPageConfig {
  final String title;
  final String guide;
  const ErrorPageConfig({required this.title, required this.guide});
}

class ErrorPageModel extends FlutterFlowModel<ErrorPageWidget> {
  final String errorTitle;
  final String guideText;

  ErrorPageModel({
    String? errorCode,
    String? customTitle,
    String? guideText,
  })  : errorTitle = _resolveTitle(errorCode, customTitle),
        guideText = _resolveGuide(errorCode, guideText);

  /// errorTitle: 优先级 customTitle > errorCode 映射 > UNKNOWN_ERROR
  static String _resolveTitle(String? errorCode, String? customTitle) {
    if (customTitle != null) return customTitle;
    if (errorCode == null) return kErrorCodeConfig['UNKNOWN_ERROR']!.title;
    return kErrorCodeConfig[errorCode]?.title ??
        kErrorCodeConfig['UNKNOWN_ERROR']!.title;
  }

  /// guideText: 优先级 guideText 参数 > errorCode 映射 > UNKNOWN_ERROR
  static String _resolveGuide(String? errorCode, String? customGuide) {
    if (customGuide != null) return customGuide;
    if (errorCode == null) return kErrorCodeConfig['UNKNOWN_ERROR']!.guide;
    return kErrorCodeConfig[errorCode]?.guide ??
        kErrorCodeConfig['UNKNOWN_ERROR']!.guide;
  }

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
