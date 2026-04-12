import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'dart:ui' show Color;
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
  void didUpdateWidget(TreePageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rootId != oldWidget.rootId) {
      _model.reloadData(widget.rootId ?? '');
    }
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
                          onTap: () async {
                            await _model.finishLearning(context);
                          },
                          child: Text(
                            'finish',
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
                        Spacer(),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            _model.reloadPage(context);
                          },
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
                  // 词根名 + 英文释义 + Origin 同行布局
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(20.0, 10.0, 20.0, 0.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 词根名大字
                              RichText(
                                text: TextSpan(
                                  children: _buildTreeRootNameSpans(
                                    _model.rootName.isNotEmpty ? _model.rootName : (_model.pageData?.rootName ?? 're'),
                                  ),
                                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.notoSans(
                                      fontWeight: FontWeight.w800,
                                    ),
                                    color: Colors.black,
                                    fontSize: 80.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w800,
                                    lineHeight: 1.0,
                                  ),
                                ),
                              ),
                              // 英文释义
                              Text(
                                _model.rootDefinition.isNotEmpty ? _model.rootDefinition : (_model.pageData?.rootDefinition ?? '又，再，重新'),
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.notoSans(
                                    fontStyle: FontStyle.italic,
                                  ),
                                  color: Colors.black,
                                  fontSize: 35.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Origin 靠右，与 rootDefinition 同行
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(
                            _model.rootOrigin,
                            style: GoogleFonts.notoSans(
                              fontStyle: FontStyle.italic,
                              fontSize: 16,
                              color: Color(0xFF555555),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 构词说明（function 字段）
                  if (_model.rootFunction.isNotEmpty) ...[
                    Padding(
                      padding: EdgeInsets.only(left: 20.0, top: 8.0, right: 20.0, bottom: 0.0),
                      child: Text(
                        _model.rootFunction,
                        style: GoogleFonts.notoSans(
                          fontStyle: FontStyle.italic,
                          fontSize: 13.0,
                          color: Color(0xFF888888),
                          height: 1.4,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
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
                                  itemCount: _model.words.length,
                                  itemBuilder: (context, index) {
                                    final word = _model.words[index];
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        await BackendManager.instance.startTreeLearnSession(
                                          word.conceptUuid,
                                          _model.currentRootId,
                                        );
                                        context.pushNamed(RandomAskPageWidget.routeName);
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(vertical: 6.0),
                                        child: Text(
                                          word.spelling,
                                          style: GoogleFonts.notoSans(
                                            fontSize: 20.0,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black,
                                            decoration: TextDecoration.underline,
                                            decorationColor: Colors.black,
                                            decorationThickness: 1.5,
                                          ),
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

  /// 为结构树词根名称构建 InlineSpan：词根部分保持默认颜色，数字为灰色上标
  /// 例如："cap2,capit,cipit" → cap[上标2],capit,cipit
  List<InlineSpan> _buildTreeRootNameSpans(String text) {
    const superscripts = {
      '0': '\u2070', '1': '\u00B9', '2': '\u00B2', '3': '\u00B3',
      '4': '\u2074', '5': '\u2075', '6': '\u2076', '7': '\u2077',
      '8': '\u2078', '9': '\u2079',
    };

    final regex = RegExp(r'([a-zA-Z-]+)(\d+)');
    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final prefix = match.group(1) ?? '';
      final digits = match.group(2) ?? '';
      final superscripted = digits.split('').map((c) => superscripts[c] ?? c).join();

      spans.add(TextSpan(text: prefix));
      spans.add(TextSpan(
        text: superscripted,
        style: const TextStyle(color: Color(0xFF888888)),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    if (spans.isEmpty) {
      return [TextSpan(text: text)];
    }
    return spans;
  }
}
