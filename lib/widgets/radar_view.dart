import 'dart:math';
import 'package:flutter/material.dart';

class RadarView extends StatefulWidget {
  const RadarView({Key? key}) : super(key: key);

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: RadarPainter(_controller.value),
          child: Container(
            width: 200,
            height: 200,
            alignment: Alignment.center,
            child: Icon(
              Icons.wifi_tethering,
              size: 50,
              color: Colors.cyanAccent.withOpacity(0.8),
            ),
          ),
        );
      },
    );
  }
}

class RadarPainter extends CustomPainter {
  final double value;

  RadarPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final double maxRadius = size.width / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);

    // Draw multiple expanding circles
    for (int i = 0; i < 3; i++) {
      double opacity = (1.0 - (value + i * 0.33) % 1.0);
      double radius = maxRadius * ((value + i * 0.33) % 1.0);

      paint.color = Colors.cyanAccent.withOpacity(opacity);
      canvas.drawCircle(center, radius, paint);
    }

    // Draw sweeping line
    final Paint sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: pi * 2,
        colors: [Colors.transparent, Colors.cyanAccent.withOpacity(0.5)],
        stops: [0.7, 1.0],
        transform: GradientRotation(value * pi * 2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));

    // Ideally we draw a circle or arc, but for sweep effect we might need a full circle rect
    canvas.drawCircle(
      center,
      maxRadius,
      sweepPaint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) => true;
}
