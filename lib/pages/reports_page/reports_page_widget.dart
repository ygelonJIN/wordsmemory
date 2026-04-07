import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'reports_page_model.dart';
export 'reports_page_model.dart';

class ReportsPageWidget extends StatefulWidget {
  const ReportsPageWidget({super.key});

  static String routeName = 'ReportsPage';
  static String routePath = '/reportsPage';

  @override
  State<ReportsPageWidget> createState() => _ReportsPageWidgetState();
}

class _ReportsPageWidgetState extends State<ReportsPageWidget> {
  late ReportsPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ReportsPageModel());
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
                        '你的学习报告',
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
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                      child: Text(
                        '总览：',
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
                        Align(
                          alignment: AlignmentDirectional(-1.0, -1.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              _model.totalStudyTimeText,
                              textAlign: TextAlign.start,
                              style: FlutterFlowTheme.of(context)
                                  .displayLarge
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .fontStyle,
                                    lineHeight: 1.5,
                                  ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, -1.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              _model.totalStudyCountText,
                              style: FlutterFlowTheme.of(context)
                                  .displayLarge
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .fontStyle,
                                    lineHeight: 1.5,
                                  ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, -1.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              _model.totalDaysText,
                              style: FlutterFlowTheme.of(context)
                                  .displayLarge
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .fontStyle,
                                    lineHeight: 1.5,
                                  ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, -1.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              _model.bookProgressText,
                              style: FlutterFlowTheme.of(context)
                                  .displayLarge
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .fontStyle,
                                    lineHeight: 1.5,
                                  ),
                            ),
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, -1.0),
                            child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            child: Text(
                              _model.monthlySummaryText,
                              style: FlutterFlowTheme.of(context)
                                  .displayLarge
                                  .override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.normal,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .displayLarge
                                          .fontStyle,
                                    ),
                                    color: Colors.black,
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .displayLarge
                                        .fontStyle,
                                    lineHeight: 1.5,
                                  ),
                            ),
                          ),
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
                                  '年度总结：',
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
                            ...(_model.yearlySummaryRows.isEmpty
                                ? [_buildEmptyRow(context, '暂无年度数据')]
                                : _model.yearlySummaryRows
                                    .map((s) => _buildStatRow(context, s))),
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
                                  '查看月度总结：',
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
                            ...(_model.monthlySummaryRows.isEmpty
                                ? [_buildEmptyRow(context, '暂无月度数据')]
                                : _model.monthlySummaryRows
                                    .map((s) => _buildStatRow(context, s))),
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
                      context.pushNamed(HomePageWidget.routeName);
                    },
                    child: Text(
                      'home',
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

  Widget _buildStatRow(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 4.0, 20.0, 4.0),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).displayLarge.override(
          font: GoogleFonts.notoSans(
            fontWeight: FontWeight.normal,
            fontStyle: FlutterFlowTheme.of(context).displayLarge.fontStyle,
          ),
          color: Colors.black,
          fontSize: 18.0,
          letterSpacing: 0.0,
          fontWeight: FontWeight.normal,
          fontStyle: FlutterFlowTheme.of(context).displayLarge.fontStyle,
          lineHeight: 1.5,
        ),
      ),
    );
  }

  Widget _buildEmptyRow(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 4.0, 20.0, 4.0),
      child: Text(
        text,
        style: FlutterFlowTheme.of(context).displayLarge.override(
          font: GoogleFonts.notoSans(
            fontWeight: FontWeight.normal,
            fontStyle: FlutterFlowTheme.of(context).displayLarge.fontStyle,
          ),
          color: Colors.grey,
          fontSize: 16.0,
          letterSpacing: 0.0,
          fontWeight: FontWeight.normal,
          fontStyle: FontStyle.italic,
          lineHeight: 1.5,
        ),
      ),
    );
  }
}
