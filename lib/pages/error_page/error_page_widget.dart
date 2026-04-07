import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'error_page_model.dart';
export 'error_page_model.dart';

class ErrorPageWidget extends StatefulWidget {
  const ErrorPageWidget({super.key});

  static String routeName = 'ErrorPage';
  static String routePath = '/errorPage';

  @override
  State<ErrorPageWidget> createState() => _ErrorPageWidgetState();
}

class _ErrorPageWidgetState extends State<ErrorPageWidget> {
  late ErrorPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ErrorPageModel());
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
                  thicknessPx: 3.0,
                  shapeType: 'Ellipse',
                  shapeWidthPx: 320.0,
                  shapeHeightPx: 100.0,
                  innerFadeLengthPx: 320.0,
                  inflectionDistPercent: 0.0,
                  inflectionOpacityPercent: 0.0,
                  outerFadeLengthPx: 0.0,
                ),
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
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                child: Text(
                  '本地数据异常或存储空间不足等。',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.notoSans(
                          fontWeight: FontWeight.w800,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: Colors.black,
                        fontSize: 28.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w800,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        lineHeight: 1.0,
                      ),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 80.0, 20.0, 0.0),
                child: Text(
                  '可尝试清理浏览器存储、检查网络后重试，或更新应用。',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.notoSans(
                          fontWeight: FontWeight.normal,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        ),
                        color: Colors.black,
                        fontSize: 16.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                        lineHeight: 1.0,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
