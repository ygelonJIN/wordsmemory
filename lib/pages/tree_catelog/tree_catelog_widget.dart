import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'tree_catelog_model.dart';
export 'tree_catelog_model.dart';

class TreeCatelogWidget extends StatefulWidget {
  const TreeCatelogWidget({super.key});

  static String routeName = 'TreeCatelog';
  static String routePath = '/treeCatelog';

  @override
  State<TreeCatelogWidget> createState() => _TreeCatelogWidgetState();
}

class _TreeCatelogWidgetState extends State<TreeCatelogWidget> {
  late TreeCatelogModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TreeCatelogModel());
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
                            context.pushNamed(HomePageWidget.routeName);
                          },
                          child: Text(
                            'home',
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
                      ],
                    ),
                  ),
                  Align(
                    alignment: AlignmentDirectional(-1.0, 0.0),
                    child: Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(12.0, 30.0, 12.0, 0.0),
                      child: Text(
                        '目录',
                        textAlign: TextAlign.start,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.notoSans(
                                fontWeight: FontWeight.normal,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                              ),
                              color: Colors.black,
                              fontSize: 56.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .fontStyle,
                              lineHeight: 1.0,
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
                              : _buildDynamicList(),
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

  /// 构建动态目录列表
  /// 每个分组：GroupHeader + N 个 RootItem
  Widget _buildDynamicList() {
    final groups = _model.groups;
    if (groups.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: FlutterFlowTheme.of(context).displayMedium.override(
                font: GoogleFonts.notoSans(
                  fontWeight: FontWeight.normal,
                  fontStyle: FlutterFlowTheme.of(context).displayMedium.fontStyle,
                ),
                color: Colors.black54,
                fontSize: 20.0,
              ),
        ),
      );
    }

    // 使用 ListView.builder + 按 group 拼接的方式
    final items = <Widget>[];
    for (int gi = 0; gi < groups.length; gi++) {
      final group = groups[gi];

      // Group header row
      items.add(
        Align(
          alignment: AlignmentDirectional(-1.0, 0.0),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
            child: Text(
              '${group.groupName}//',
              style: FlutterFlowTheme.of(context)
                  .displayLarge
                  .override(
                    font: GoogleFonts.notoSans(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                    fontSize: 18.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    lineHeight: 2.0,
                  ),
            ),
          ),
        ),
      );

      // Root items
      for (int ri = 0; ri < group.roots.length; ri++) {
        final root = group.roots[ri];

        items.add(
          Align(
            alignment: AlignmentDirectional(-1.0, 0.0),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(10.0, 5.0, 10.0, 5.0),
              child: InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () async {
                  _model.navigateToRoot(root.rootId);
                },
                child: Text(
                  '${root.rootName}//',
                  style: FlutterFlowTheme.of(context)
                      .displayLarge
                      .override(
                        font: GoogleFonts.notoSans(
                          fontWeight: FontWeight.w500,
                          fontStyle: FlutterFlowTheme.of(context)
                              .displayLarge
                              .fontStyle,
                        ),
                        fontSize: 18.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w500,
                        fontStyle: FlutterFlowTheme.of(context)
                            .displayLarge
                            .fontStyle,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      scrollDirection: Axis.vertical,
      children: items,
    );
  }
}
