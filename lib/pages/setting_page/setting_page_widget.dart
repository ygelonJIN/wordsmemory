import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'setting_page_model.dart';
export 'setting_page_model.dart';

class SettingPageWidget extends StatefulWidget {
  const SettingPageWidget({super.key});

  static String routeName = 'SettingPage';
  static String routePath = '/settingPage';

  @override
  State<SettingPageWidget> createState() => _SettingPageWidgetState();
}

class _SettingPageWidgetState extends State<SettingPageWidget> {
  late SettingPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingPageModel());
  }

  @override
  void dispose() {
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: custom_widgets.AdvancedRayBackground(
                  width: double.infinity,
                  height: double.infinity,
                  totalRays: 28,
                  lineColor: FlutterFlowTheme.of(context).primary,
                  thicknessPx: 0.5,
                  shapeType: 'Point',
                  shapeWidthPx: 0.0,
                  shapeHeightPx: 0.0,
                  innerFadeLengthPx: 320.0,
                  inflectionDistPercent: 0.0,
                  inflectionOpacityPercent: 0.0,
                  outerFadeLengthPx: 200.0,
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: Container(
                width: double.infinity,
                height: 150.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x004B39EF),
                      FlutterFlowTheme.of(context).primary
                    ],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 60.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Align(
                    alignment: AlignmentDirectional(1.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                      child: Text(
                        _model.userName,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.normal,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: Colors.black,
                              fontSize: 42.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
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
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                      child: Text(
                        '你的设置',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: Colors.black,
                              fontSize: 56.0,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.9,
                    child: Divider(
                      thickness: 5.0,
                      color: FlutterFlowTheme.of(context).secondary,
                    ),
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 10.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            final result = await _model.importArchive();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result != null
                                      ? '导入成功：${result.imported}条，跳过：${result.skipped}条'
                                      : '导入已取消',
                                ),
                                backgroundColor: result == null ? Colors.orange : null,
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 0.0),
                            child: Text(
                              '导入存档',
                              style: FlutterFlowTheme.of(context)
                                  .displayMedium
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayMedium
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayMedium
                                        .fontStyle,
                                    decoration: TextDecoration.underline,
                                    lineHeight: 2.0,
                                  ),
                            ),
                          ),
                        ),
                        Spacer(),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            final path = await _model.exportArchive();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  path != null ? '备份成功' : '备份已取消',
                                ),
                                backgroundColor: path == null ? Colors.orange : null,
                              ),
                            );
                          },
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                            child: Text(
                              '备份存档',
                              style: FlutterFlowTheme.of(context)
                                  .displayMedium
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayMedium
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayMedium
                                        .fontStyle,
                                    decoration: TextDecoration.underline,
                                    lineHeight: 2.0,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                      child: Text(
                        '选择词书：',
                        style:
                            FlutterFlowTheme.of(context).displayMedium.override(
                                  font: GoogleFonts.notoSans(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .displayMedium
                                        .fontWeight,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  color: Colors.black,
                                  fontSize: 24.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .displayMedium
                                      .fontWeight,
                                  fontStyle: FontStyle.italic,
                                  lineHeight: 2.0,
                                ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => _model.setCurrentBook('kaoyan2027'),
                                    child: Text(
                                      '2027考研',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .override(
                                            font: GoogleFonts.notoSans(
                                              fontWeight: _model.currentBook == 'kaoyan2027'
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .displayLarge
                                                  .fontStyle,
                                            ),
                                            color: _model.currentBook == 'kaoyan2027'
                                                ? const Color(0xFF0000FF)
                                                : Colors.black,
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: _model.currentBook == 'kaoyan2027'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                            decoration: TextDecoration.underline,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setCurrentBook('cet6'),
                                  child: Text(
                                    'CET6',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.currentBook == 'cet6'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.currentBook == 'cet6'
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.currentBook == 'cet6'
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setCurrentBook('cet4'),
                                  child: Text(
                                    'CET4',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.currentBook == 'cet4'
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.currentBook == 'cet4'
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.currentBook == 'cet4'
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                                  child: SizedBox(width: 1.0),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          children: [
                            Align(
                              alignment: AlignmentDirectional(-1.0, 0.0),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 0.0, 20.0, 0.0),
                                child: Text(
                                  '单次学习数量：',
                                  style: FlutterFlowTheme.of(context)
                                      .displayMedium
                                      .override(
                                        font: GoogleFonts.notoSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .displayMedium
                                                  .fontWeight,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        color: Colors.black,
                                        fontSize: 24.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .displayMedium
                                            .fontWeight,
                                        fontStyle: FontStyle.italic,
                                        lineHeight: 2.0,
                                      ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => _model.setSingleSessionLimit(100),
                                    child: Text(
                                      '100',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .override(
                                            font: GoogleFonts.notoSans(
                                              fontWeight: _model.singleSessionLimit == 100
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .displayLarge
                                                  .fontStyle,
                                            ),
                                            color: _model.singleSessionLimit == 100
                                                ? const Color(0xFF0000FF)
                                                : Colors.black,
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: _model.singleSessionLimit == 100
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                            decoration: TextDecoration.underline,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setSingleSessionLimit(70),
                                  child: Text(
                                    '70',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.singleSessionLimit == 70
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.singleSessionLimit == 70
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.singleSessionLimit == 70
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setSingleSessionLimit(50),
                                  child: Text(
                                    '50',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.singleSessionLimit == 50
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.singleSessionLimit == 50
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.singleSessionLimit == 50
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setSingleSessionLimit(30),
                                  child: Text(
                                    '30',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.singleSessionLimit == 30
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.singleSessionLimit == 30
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.singleSessionLimit == 30
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setSingleSessionLimit(20),
                                  child: Text(
                                    '20',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.singleSessionLimit == 20
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.singleSessionLimit == 20
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.singleSessionLimit == 20
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => _model.setSingleSessionLimit(10),
                                    child: Text(
                                      '10',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .override(
                                            font: GoogleFonts.notoSans(
                                              fontWeight: _model.singleSessionLimit == 10
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .displayLarge
                                                  .fontStyle,
                                            ),
                                            color: _model.singleSessionLimit == 10
                                                ? const Color(0xFF0000FF)
                                                : Colors.black,
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: _model.singleSessionLimit == 10
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                            decoration: TextDecoration.underline,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          children: [
                            Align(
                              alignment: AlignmentDirectional(-1.0, 0.0),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 0.0, 20.0, 0.0),
                                child: Text(
                                  '学习辅助显示：',
                                  style: FlutterFlowTheme.of(context)
                                      .displayMedium
                                      .override(
                                        font: GoogleFonts.notoSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .displayMedium
                                                  .fontWeight,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        color: Colors.black,
                                        fontSize: 24.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .displayMedium
                                            .fontWeight,
                                        fontStyle: FontStyle.italic,
                                        lineHeight: 2.0,
                                      ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => _model.setShowEtymology(true),
                                    child: Text(
                                      '词根词缀',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .override(
                                            font: GoogleFonts.notoSans(
                                              fontWeight: _model.showEtymology
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .displayLarge
                                                  .fontStyle,
                                            ),
                                            color: _model.showEtymology
                                                ? const Color(0xFF0000FF)
                                                : Colors.black,
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: _model.showEtymology
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                            decoration: TextDecoration.underline,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setShowDefinition(true),
                                  child: Text(
                                    '词义',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.showDefinition
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.showDefinition
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.showDefinition
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 12.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setShowExample(true),
                                  child: Text(
                                    '例句',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.showExample
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.showExample
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.showExample
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                                  child: SizedBox(width: 1.0),
                                ),
                              ],
                            ),
                          ],
                        ),
                        ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          scrollDirection: Axis.vertical,
                          children: [
                            Align(
                              alignment: AlignmentDirectional(-1.0, 0.0),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 0.0, 20.0, 0.0),
                                child: Text(
                                  '每日刷新时间：',
                                  style: FlutterFlowTheme.of(context)
                                      .displayMedium
                                      .override(
                                        font: GoogleFonts.notoSans(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .displayMedium
                                                  .fontWeight,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        color: Colors.black,
                                        fontSize: 24.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .displayMedium
                                            .fontWeight,
                                        fontStyle: FontStyle.italic,
                                        lineHeight: 2.0,
                                      ),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 0.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => _model.setDailyRefreshHour(0),
                                    child: Text(
                                      '0.',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .override(
                                            font: GoogleFonts.notoSans(
                                              fontWeight: _model.dailyRefreshHour == 0
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .displayLarge
                                                  .fontStyle,
                                            ),
                                            color: _model.dailyRefreshHour == 0
                                                ? const Color(0xFF0000FF)
                                                : Colors.black,
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: _model.dailyRefreshHour == 0
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                            decoration: TextDecoration.underline,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setDailyRefreshHour(4),
                                  child: Text(
                                    '4.',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.dailyRefreshHour == 4
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.dailyRefreshHour == 4
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.dailyRefreshHour == 4
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 8.0),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () => _model.setDailyRefreshHour(8),
                                  child: Text(
                                    '8.',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .override(
                                          font: GoogleFonts.notoSans(
                                            fontWeight: _model.dailyRefreshHour == 8
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                          ),
                                          color: _model.dailyRefreshHour == 8
                                              ? const Color(0xFF0000FF)
                                              : Colors.black,
                                          fontSize: 20.0,
                                          letterSpacing: 0.0,
                                          fontWeight: _model.dailyRefreshHour == 8
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .displayLarge
                                              .fontStyle,
                                          decoration: TextDecoration.underline,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 8.0),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 20.0, 0.0),
                                  child: InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => _model.setDailyRefreshHour(18),
                                    child: Text(
                                      '18.',
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .override(
                                            font: GoogleFonts.notoSans(
                                              fontWeight: _model.dailyRefreshHour == 18
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .displayLarge
                                                  .fontStyle,
                                            ),
                                            color: _model.dailyRefreshHour == 18
                                                ? const Color(0xFF0000FF)
                                                : Colors.black,
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: _model.dailyRefreshHour == 18
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontStyle: FlutterFlowTheme.of(context)
                                                .displayLarge
                                                .fontStyle,
                                            decoration: TextDecoration.underline,
                                            lineHeight: 1.5,
                                          ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20.0, 60.0, 20.0, 0.0),
              child: Row(
                mainAxisSize: MainAxisSize.max,
                children: [
                  InkWell(
                    splashColor: Colors.transparent,
                    focusColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    onTap: () async {
                      context.safePop();
                    },
                    child: Text(
                      'back',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.notoSans(
                              fontWeight: FontWeight.w600,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                            ),
                            fontSize: 18.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .fontStyle,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
