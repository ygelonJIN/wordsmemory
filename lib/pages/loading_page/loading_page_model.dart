import '/flutter_flow/flutter_flow_util.dart';
import 'loading_page_widget.dart' show LoadingPageWidget;
import 'package:flutter/material.dart';
import 'package:demo1red/backend/provider.dart';
import '/index.dart';
import 'dart:async';
import '/flutter_flow/nav/nav.dart';

class LoadingPageModel extends FlutterFlowModel<LoadingPageWidget> {
  late StreamSubscription<LoadingStatus> _subscription;
  String _loadingText = '正在启动...';
  bool _navigated = false;

  String get loadingText => _loadingText;

  @override
  void initState(BuildContext context) {
    _subscription = BackendManager.instance.loadingStatusStream.listen((status) {
      updatePage(() {
        _loadingText = status.text;
      });
      if (status.isDone && !_navigated) {
        _navigated = true;
        print('[Loading] 初始化完成，开始导航到 /homePage');
        Future.delayed(Duration.zero, () {
          try {
            print('[Loading] Future.delayed 执行, appRouter=$appRouter');
            appRouter?.go('/homePage');
            print('[Loading] appRouter.go 成功');
          } catch (e, st) {
            print('[Loading] 导航异常: $e');
            print('[Loading] stack: $st');
          }
        });
      }
    });

    BackendManager.instance.initialize().catchError((err) {
      updatePage(() {
        _loadingText = '初始化失败: $err';
      });
      Future.delayed(Duration.zero, () => appRouter?.go('/errorPage'));
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
  }
}
