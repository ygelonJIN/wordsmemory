import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tree_page_model.dart';
import 'package:demo1red/backend/provider.dart';
export 'tree_page_model.dart';

class TreePageWidget extends StatefulWidget {
  const TreePageWidget({
    super.key,
    this.rootId,
  });

  final String? rootId;

  static String routeName = 'TreePage';
  static String routePath = '/treePage';

  @override
  State<TreePageWidget> createState() => _TreePageWidgetState();
}

class _TreePageWidgetState extends State<TreePageWidget> {
  late TreePageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TreePageModel());
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
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 60.0, 0.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(TreeCatelogWidget.routeName);
                          },
                          child: Text(
                            'catelog',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
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
                        Spacer(),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          child: Text(
                            'next',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(
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
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 10.0, 20.0, 0.0),
                      child: Text(
                        _model.pageData?.rootName ?? 're',
                        textAlign: TextAlign.start,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.notoSans(
                                fontWeight: FontWeight.w800,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: Colors.black,
                              fontSize: 80.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w800,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                              lineHeight: 1.0,
                            ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                      child: Text(
                        _model.pageData?.rootDefinition ?? '又，再，重新',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.normal,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: Colors.black,
                              fontSize: 35.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
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
                      color: Color(0xFF0000FF),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 0.0, 20.0, 0.0),
                          child: _model.isLoading
                              ? Center(
                              child: CircularProgressIndicator(
                                color: Colors.black54,
                              ),
                            )
                              : ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: _model.pageData?.words.length ?? 0,
                                  itemBuilder: (context, index) {
                                    final word = _model.pageData!.words[index];
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await BackendManager.instance.visitTreeWord(word.conceptUuid);
                                        context.pushNamed(RandomLearnPageWidget.routeName);
                                      },
                                      child: Text(
                                        word.renderString,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle: FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                              ),
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle: FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                              lineHeight: 2.5,
                                              decoration: TextDecoration.underline,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
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
