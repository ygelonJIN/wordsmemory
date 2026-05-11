import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:demo1red/flutter_flow/flutter_flow_theme.dart';

/// "Hi, [username]" 组件
/// 点击 "Hi,名字" 后进入内联编辑状态，支持用户名保存回调
class HiGreeting extends StatefulWidget {
  final String name;
  final Future<void> Function(String) onSave;

  const HiGreeting({super.key, required this.name, required this.onSave});

  @override
  State<HiGreeting> createState() => HiGreetingState();
}

class HiGreetingState extends State<HiGreeting> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.name);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus && _isEditing) {
      _save();
    }
  }

  @override
  void didUpdateWidget(HiGreeting oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.name != oldWidget.name) {
      _controller.text = widget.name;
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _controller.text = widget.name;
    });
    Future.delayed(const Duration(milliseconds: 50), () {
      _focusNode.requestFocus();
    });
  }

  void _save() {
    setState(() => _isEditing = false);
    final value = _controller.text.trim();
    widget.onSave(value);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  TextStyle _baseStyle(BuildContext context) {
    final len = widget.name.length;
    final double size;
    if (len <= 4) {
      size = 94.0;
    } else if (len <= 6) {
      size = 72.0;
    } else if (len <= 8) {
      size = 60.0;
    } else if (len <= 10) {
      size = 50.0;
    } else if (len <= 12) {
      size = 44.0;
    } else if (len <= 14) {
      size = 38.0;
    } else if (len <= 16) {
      size = 32.0;
    } else if (len <= 18) {
      size = 26.0;
    } else {
      size = 20.0;
    }
    return GoogleFonts.notoSans(
      fontWeight: FontWeight.w600,
      fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
      color: Colors.black,
      fontSize: size,
      letterSpacing: 0.0,
      decoration: TextDecoration.underline,
      height: 1.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Hi,', style: _baseStyle(context)),
          IntrinsicWidth(
            stepHeight: 0,
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                style: _baseStyle(context),
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
          ),
        ],
      );
    }
    return GestureDetector(
      onTap: _startEditing,
      behavior: HitTestBehavior.translucent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('Hi,', style: _baseStyle(context)),
          Text(widget.name, style: _baseStyle(context)),
        ],
      ),
    );
  }
}
