import 'dart:math';
import 'package:flutter/material.dart';

class CircularProgressRing extends StatelessWidget {
  final double progress;
  final Widget child;
  final double size;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;
  final Function(double)? onSeek;

  const CircularProgressRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 280,
    this.progressColor = Colors.white,
    this.backgroundColor = Colors.white10,
    this.strokeWidth = 6,
    this.onSeek,
  });

  void _handleSeek(Offset localPosition) {
    if (onSeek == null) return;
    
    final centerX = size / 2;
    final centerY = size / 2;
    final dx = localPosition.dx - centerX;
    final dy = localPosition.dy - centerY;
    
    // Calculate angle in radians
    double angle = atan2(dy, dx) + (pi / 2);
    
    // Normalize angle to [0, 2*pi]
    if (angle < 0) {
      angle += 2 * pi;
    }
    
    // Convert angle to progress [0, 1]
    final newProgress = angle / (2 * pi);
    onSeek!(newProgress);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) => _handleSeek(details.localPosition),
      onPanDown: (details) => _handleSeek(details.localPosition),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _RingPainter(
                progress: progress,
                progressColor: progressColor,
                backgroundColor: backgroundColor,
                strokeWidth: strokeWidth,
              ),
            ),
            // Inner artwork
            ClipOval(
              child: SizedBox(
                width: size - (strokeWidth * 4),
                height: size - (strokeWidth * 4),
                child: child,
              ),
            ),
            // Thumb indicator
            Transform.rotate(
              angle: 2 * pi * progress - pi / 2,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: strokeWidth * 2.5,
                    height: strokeWidth * 2.5,
                    transform: Matrix4.translationValues(strokeWidth * 1.25, 0, 0),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
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

class _RingPainter extends CustomPainter {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
