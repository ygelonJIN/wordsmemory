// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom widgets
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!

import 'dart:math' as math;
import 'dart:ui' as ui;

class AdvancedRayBackground extends StatefulWidget {
  const AdvancedRayBackground({
    Key? key,
    this.width,
    this.height,
    this.totalRays = 60, // 射线总数
    this.lineColor = Colors.white, // 射线颜色
    this.thicknessPx = 2.0, // 射线线宽
    this.shapeType = 'Ellipse', // 中心形状
    this.shapeWidthPx = 150.0, // 形状总宽度
    this.shapeHeightPx = 150.0, // 形状总高度
    this.innerFadeLengthPx = 50.0, // 中心渐隐总长度
    this.inflectionDistPercent = 80.0, // 拐点距离占比 (%)
    this.inflectionOpacityPercent = 50.0, // 拐点透明度 (%)
    this.outerFadeLengthPx = 10.0, // 四周渐隐长度
  }) : super(key: key);

  final double? width;
  final double? height;
  final int totalRays;
  final Color lineColor;
  final double thicknessPx;
  final String shapeType;
  final double shapeWidthPx;
  final double shapeHeightPx;
  final double innerFadeLengthPx;
  final double inflectionDistPercent;
  final double inflectionOpacityPercent;
  final double outerFadeLengthPx;

  @override
  State<AdvancedRayBackground> createState() => _AdvancedRayBackgroundState();
}

class _AdvancedRayBackgroundState extends State<AdvancedRayBackground> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: Colors.transparent, // 模块一：背景保持完全透明
      child: CustomPaint(
        size: Size.infinite,
        painter: RayPainter(
          totalRays: widget.totalRays,
          lineColor: widget.lineColor,
          thicknessPx: widget.thicknessPx,
          shapeType: widget.shapeType,
          shapeWidthPx: widget.shapeWidthPx,
          shapeHeightPx: widget.shapeHeightPx,
          innerFadeLengthPx: widget.innerFadeLengthPx,
          inflectionDistPercent: widget.inflectionDistPercent,
          inflectionOpacityPercent: widget.inflectionOpacityPercent,
          outerFadeLengthPx: widget.outerFadeLengthPx,
        ),
      ),
    );
  }
}

class RayPainter extends CustomPainter {
  final int totalRays;
  final Color lineColor;
  final double thicknessPx;
  final String shapeType;
  final double shapeWidthPx;
  final double shapeHeightPx;
  final double innerFadeLengthPx;
  final double inflectionDistPercent;
  final double inflectionOpacityPercent;
  final double outerFadeLengthPx;

  RayPainter({
    required this.totalRays,
    required this.lineColor,
    required this.thicknessPx,
    required this.shapeType,
    required this.shapeWidthPx,
    required this.shapeHeightPx,
    required this.innerFadeLengthPx,
    required this.inflectionDistPercent,
    required this.inflectionOpacityPercent,
    required this.outerFadeLengthPx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 模块一：绝对中心点
    final cx = size.width / 2;
    final cy = size.height / 2;

    final paint = Paint()
      ..strokeWidth = thicknessPx
      ..style = PaintingStyle.stroke;

    // 模块一：强制镜像对称，必须是 4 的倍数
    int rays = (totalRays ~/ 4) * 4;
    if (rays <= 0) rays = 4;

    for (int i = 0; i < rays; i++) {
      // 模块一：+0.5 步长角度偏移，避开正交轴，确保四象限绝对镜像对称
      double theta = (i + 0.5) * (2 * math.pi / rays);
      double cosT = math.cos(theta);
      double sinT = math.sin(theta);

      // --- 模块二：中心物理形态定义 (反推起点距离 dStart) ---
      double dStart = 0.0;
      if (shapeType == 'Rectangle') {
        double hw = shapeWidthPx / 2;
        double hh = shapeHeightPx / 2;
        double distX = cosT.abs() > 1e-6 ? hw / cosT.abs() : double.infinity;
        double distY = sinT.abs() > 1e-6 ? hh / sinT.abs() : double.infinity;
        dStart = math.min(distX, distY);
      } else if (shapeType == 'Ellipse') {
        double a = shapeWidthPx / 2;
        double b = shapeHeightPx / 2;
        if (a > 0 && b > 0) {
          // 椭圆极坐标方程系推导
          double denom =
              math.sqrt(math.pow(b * cosT, 2) + math.pow(a * sinT, 2));
          dStart = (a * b) / denom;
        }
      } // 如果是 'Point'，dStart 保持 0.0

      // --- 模块四：四周渐隐 (推算终点屏幕边界距离 dEnd) ---
      double tX = cosT > 0
          ? (size.width - cx) / cosT
          : (cosT < 0 ? -cx / cosT : double.infinity);
      double tY = sinT > 0
          ? (size.height - cy) / sinT
          : (sinT < 0 ? -cy / sinT : double.infinity);
      double dEnd = math.min(tX, tY);

      double rayLength = dEnd - dStart;
      if (rayLength <= 0) continue; // 射线在屏幕外

      // --- 模块五：极限边界防崩溃锁 ---
      double safeInner = innerFadeLengthPx;
      double safeOuter = outerFadeLengthPx;

      if (safeInner + safeOuter > rayLength) {
        // 优先级：内圈绝对虚空形态最高。外圈必须让步
        safeOuter = rayLength - safeInner;
        if (safeOuter < 0) safeOuter = 0.0;
        // 如果连内圈都被压缩，则截断内圈
        if (safeInner > rayLength) safeInner = rayLength;
      }

      // --- 模块三 & 模块四：灵魂折线衰减 (绝对物理距离映射) ---
      double d0 = 0.0; // 起点 (0% 透明)
      // 【关键换算】: 将输入的 80 转换为 0.8 进行底层计算
      double d1 =
          safeInner * (inflectionDistPercent / 100.0).clamp(0.0, 1.0); // 拐点
      double d2 = safeInner; // 内部渐隐结束点 (100% 透明)
      double d3 = rayLength - safeOuter; // 外部渐隐开始点 (100% 透明)
      double d4 = rayLength; // 终点 (0% 透明)

      List<double> stops = [
        d0 / rayLength,
        d1 / rayLength,
        d2 / rayLength,
        d3 / rayLength,
        1.0 // 必须为1.0闭环
      ];

      // 【关键换算】: 将输入的 50 转换为 0.5 进行透明度计算
      double actualOpacity = (inflectionOpacityPercent / 100.0).clamp(0.0, 1.0);

      List<Color> colors = [
        lineColor.withOpacity(0.0), // 彻底斩断叠加亮斑
        lineColor.withOpacity(actualOpacity), // 极度深邃的黑洞边缘
        lineColor.withOpacity(1.0), // 实心
        lineColor.withOpacity(1.0), // 实心
        lineColor.withOpacity(0.0), // 四周边缘
      ];

      Offset pStart = Offset(cx + dStart * cosT, cy + dStart * sinT);
      Offset pEnd = Offset(cx + dEnd * cosT, cy + dEnd * sinT);

      paint.shader = ui.Gradient.linear(pStart, pEnd, colors, stops);
      canvas.drawLine(pStart, pEnd, paint);
    }
  }

  @override
  bool shouldRepaint(covariant RayPainter oldDelegate) {
    return totalRays != oldDelegate.totalRays ||
        lineColor != oldDelegate.lineColor ||
        thicknessPx != oldDelegate.thicknessPx ||
        shapeType != oldDelegate.shapeType ||
        shapeWidthPx != oldDelegate.shapeWidthPx ||
        shapeHeightPx != oldDelegate.shapeHeightPx ||
        innerFadeLengthPx != oldDelegate.innerFadeLengthPx ||
        inflectionDistPercent != oldDelegate.inflectionDistPercent ||
        inflectionOpacityPercent != oldDelegate.inflectionOpacityPercent ||
        outerFadeLengthPx != oldDelegate.outerFadeLengthPx;
  }
}
