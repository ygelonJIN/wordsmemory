import 'package:flutter/material.dart';

class ClickFeedbackText extends StatefulWidget {
  final String text;
  final TextStyle normalStyle;
  final TextStyle feedbackStyle;
  final VoidCallback? onTap;
  final Duration duration;

  const ClickFeedbackText({
    super.key,
    required this.text,
    required this.normalStyle,
    required this.feedbackStyle,
    required this.onTap,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<ClickFeedbackText> createState() => _ClickFeedbackTextState();
}

class _ClickFeedbackTextState extends State<ClickFeedbackText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    _controller.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final fontWeight = FontWeight.lerp(
            widget.feedbackStyle.fontWeight ?? FontWeight.w600,
            widget.normalStyle.fontWeight ?? FontWeight.w600,
            _animation.value,
          );
          final color = Color.lerp(
            widget.normalStyle.color ?? Colors.black,
            widget.feedbackStyle.color ?? const Color(0xFF0000FF),
            _animation.value,
          );
          return Text(
            widget.text,
            style: widget.normalStyle.copyWith(
              fontWeight: fontWeight,
              color: color,
            ),
          );
        },
      ),
    );
  }
}
