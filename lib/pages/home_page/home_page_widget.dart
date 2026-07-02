// GENERATED CODE - DO NOT MODIFY BY HAND

import '/backend/provider.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import '/widgets/hi_greeting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  static String routeName = 'HomePage';
  static String routePath = '/homePage';

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
    _model.refresh();
    BackendManager.instance.addListener(_onBackendChanged);
  }

  void _onBackendChanged() {
    _model.refresh();
  }

  @override
  void dispose() {
    BackendManager.instance.removeListener(_onBackendChanged);
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _model.setOnUpdate(
      onUpdate: () => setState(() {}),
      updateOnChange: true,
    );
    _model.disposeOnWidgetDisposal = false;
    return ListenableBuilder(
      listenable: BackendManager.instance,
      builder: (context, _) => GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
          key: scaffoldKey,
          resizeToAvoidBottomInset: false,
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          body: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: custom_widgets.AdvancedRayBackground(
                    width: double.infinity,
                    height: double.infinity,
                    totalRays: 28,
                    lineColor: FlutterFlowTheme.of(context).primary,
                    thicknessPx: 3.0,
                    shapeType: 'Point',
                    shapeWidthPx: 0.0,
                    shapeHeightPx: 0.0,
                    innerFadeLengthPx: 320.0,
                    inflectionDistPercent: 0.0,
                    inflectionOpacityPercent: 0.0,
                    outerFadeLengthPx: 0.0,
                  ),
                ),
              ),
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 150.0,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x004B39EF),
                          FlutterFlowTheme.of(context).primary,
                        ],
                        stops: [0.0, 1.0],
                        begin: AlignmentDirectional(0.0, -1.0),
                        end: AlignmentDirectional(0, 1.0),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                child: Transform.translate(
                  offset: const Offset(0, -20),
                  child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 0.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 30.0, 20.0, 0.0),
                                  child: SizedBox(
                                    height: 120.0,
                                    child: Align(
                                      alignment: AlignmentDirectional(1.0, 1.0),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.only(bottom: 10.0),
                                        child: HiGreeting(
                                        name: _model.userName,
                                        onSave: (name) => _model.saveUserName(name),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                                    ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                            child: Text(
                              _model.todayLearned,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: Colors.black,
                                fontSize: 26.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '每日目标',
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: Colors.black,
                                    fontSize: 26.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                ),
                                _DailyTargetEditor(
                                  target: _model.dailyTarget,
                                  onSave: (t) => _model.saveDailyTarget(t),
                                ),
                                Text(
                                  '词',
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: Colors.black,
                                    fontSize: 26.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 10.0, 20.0, 0.0),
                            child: Text(
                              _model.exportWarning,
                              style: FlutterFlowTheme.of(context).displayLarge.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                                color: const Color(0xFF454545),
                                fontSize: 13.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                lineHeight: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 20.0, 0.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(SettingPageWidget.routeName);
                              },
                              child: Text(
                                '设置',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  decoration: TextDecoration.underline,
                                  lineHeight: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 30.0, 20.0, 0.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(FavoritePageWidget.routeName);
                              },
                              child: Text(
                                '收藏夹',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  decoration: TextDecoration.underline,
                                  lineHeight: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 30.0, 20.0, 0.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(ReportsPageWidget.routeName);
                              },
                              child: Text(
                                '数据统计',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  decoration: TextDecoration.underline,
                                  lineHeight: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 10.0, 20.0, 0.0),
                            child: Text(
                              'stability,稳定性,大概能稳定记住多久',
                              style: FlutterFlowTheme.of(context).displayLarge.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                                color: const Color(0xFF454545),
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                lineHeight: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              'retrievability,可提取性,目前回答正确的把握',
                              style: FlutterFlowTheme.of(context).displayLarge.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                                color: const Color(0xFF454545),
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                lineHeight: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              'collinsStar,柯林斯星级',
                              style: FlutterFlowTheme.of(context).displayLarge.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                                color: const Color(0xFF454545),
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                lineHeight: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              'bnc,英国国家语料库词频顺序',
                              style: FlutterFlowTheme.of(context).displayLarge.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                                color: const Color(0xFF454545),
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                lineHeight: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              'frq,当代语料库词频顺序',
                              style: FlutterFlowTheme.of(context).displayLarge.override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FontStyle.italic,
                                ),
                                color: const Color(0xFF454545),
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                lineHeight: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 10.0, 0.0, 0.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(TreeCatelogWidget.routeName);
                              },
                              child: Text(
                                '结构树学习',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  decoration: TextDecoration.underline,
                                  lineHeight: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 30.0, 0.0, 0.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(TopicCatelogWidget.routeName);
                              },
                              child: Text(
                                '语义阅读',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  decoration: TextDecoration.underline,
                                  lineHeight: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 30.0, 0.0, 0.0),
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(QuickLearnPageWidget.routeName);
                              },
                              child: Text(
                                '快速筛选',
                                textAlign: TextAlign.start,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                  decoration: TextDecoration.underline,
                                  lineHeight: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(70.0, 0.0, 0.0, 0.0),
                                child: Text(
                                  _model.remaining,
                                  style: FlutterFlowTheme.of(context)
                                      .displayLarge
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: const Color(0xFF454545),
                                        fontSize: 13.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        lineHeight: 1.5,
                                      ),
                                ),
                              ),
                              Spacer(),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 50.0, 0.0),
                                child: Text(
                                  _model.bookProgress,
                                  style: FlutterFlowTheme.of(context)
                                      .displayLarge
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: const Color(0xFF454545),
                                        fontSize: 13.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w600,
                                        lineHeight: 1.5,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(0.0, 1.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 30.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Align(
                                  alignment: AlignmentDirectional(-1.0, 0.0),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(50.0, 0.0, 20.0, 0.0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await BackendManager.instance
                                            .createReviewSession();
                                        context.pushNamed(RandomAskPageWidget.routeName);
                                      },
                                      child: Text(
                                        '复习',
                                        textAlign: TextAlign.start,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle: FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                              ),
                                              color: Colors.black,
                                              fontSize: 42.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                              decoration: TextDecoration.underline,
                                              lineHeight: 1.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                Spacer(),
                                Align(
                                  alignment: AlignmentDirectional(0.0, 1.0),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 50.0, 0.0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        print('[HomePage] 点击学习按钮，开始 createLearnSession');
                                        try {
                                          final settings = await BackendManager.instance.loadSettings();
                                          await BackendManager.instance.createLearnSession(
                                            limit: settings.singleSessionLimit,
                                            bookId: settings.currentBook,
                                          );
                                          print('[HomePage] createLearnSession 完成，limit=\${settings.singleSessionLimit} bookId=\${settings.currentBook}');
                                        } catch (e) {
                                          print('[HomePage] createLearnSession 异常: \$e');
                                        }
                                        context.pushNamed(RandomAskPageWidget.routeName);
                                        print('[HomePage] pushNamed 已调用');
                                      },
                                      child: Text(
                                        '学习',
                                        textAlign: TextAlign.start,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w600,
                                                fontStyle: FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                              ),
                                              color: Colors.black,
                                              fontSize: 42.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                              decoration: TextDecoration.underline,
                                              lineHeight: 1.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTargetEditor extends StatefulWidget {
  final int target;
  final Future<void> Function(int) onSave;

  const _DailyTargetEditor({required this.target, required this.onSave});

  @override
  State<_DailyTargetEditor> createState() => _DailyTargetEditorState();
}

class _DailyTargetEditorState extends State<_DailyTargetEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.target.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _save();
    }
  }

  @override
  void didUpdateWidget(_DailyTargetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.target != oldWidget.target) {
      _controller.text = widget.target.toString();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.target.toString();
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _focusNode.requestFocus();
    });
  }

  void _save() {
    final v = int.tryParse(_controller.text.trim());
    setState(() => _isEditing = false);
    if (v != null && v > 0) {
      _controller.text = v.toString();
      widget.onSave(v);
    } else {
      _controller.text = widget.target.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  TextStyle _baseStyle(BuildContext context) {
    return GoogleFonts.inter(
      fontWeight: FontWeight.w400,
      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
      color: Colors.black,
      fontSize: 30.0,
      letterSpacing: 0.0,
      decoration: TextDecoration.underline,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return IntrinsicWidth(
        stepHeight: 0,
        child: Material(
          color: Colors.transparent,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            style: _baseStyle(context),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onSubmitted: (_) => _save(),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: _startEditing,
      behavior: HitTestBehavior.translucent,
      child: Text(widget.target.toString(), style: _baseStyle(context)),
    );
  }
}
