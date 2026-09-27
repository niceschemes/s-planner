import 'dart:math' as math;

import 'package:flutter/material.dart';

bool routeMarkIsNight(DateTime time) => time.hour < 6 || time.hour >= 18;

class RouteMark extends StatelessWidget {
  const RouteMark({super.key, required this.night, required this.travel});

  final bool night;
  final double travel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      width: double.infinity,
      child: Stack(
        children: [
          CustomPaint(
            painter: _MarkPainter(night: night, travel: travel),
            child: const SizedBox.expand(),
          ),
          const Positioned(
            left: 14,
            top: 12,
            child: Text(
              'S Planner',
              key: Key('app-title'),
              style: TextStyle(
                color: Color(0xFFF4FBF8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.night, required this.travel});

  final bool night;
  final double travel;

  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: night
            ? const [Color(0xFF07141A), Color(0xFF123844), Color(0xFF1A4A4A)]
            : const [Color(0xFF8EC9D4), Color(0xFF1F6670), Color(0xFF143E46)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);

    final lamp = Offset(size.width * 0.84, size.height * 0.24);
    if (night) {
      canvas.drawCircle(lamp, 16, Paint()..color = const Color(0xFFF4E6C4).withValues(alpha: 0.16));
      canvas.drawCircle(lamp, 7, Paint()..color = const Color(0xFFF4E6C4));
      for (final star in const [Offset(0.18, 0.22), Offset(0.32, 0.14), Offset(0.62, 0.18), Offset(0.72, 0.32)]) {
        canvas.drawCircle(
          Offset(size.width * star.dx, size.height * star.dy),
          1.1,
          Paint()..color = const Color(0xFFF4E6C4).withValues(alpha: 0.8),
        );
      }
    } else {
      canvas.drawCircle(lamp, 18, Paint()..color = const Color(0xFFF6E2A8).withValues(alpha: 0.22));
      canvas.drawCircle(lamp, 8, Paint()..color = const Color(0xFFF6E2A8));
    }

    final horizon = size.height * 0.56;
    final road = Path()
      ..moveTo(size.width * 0.44, horizon)
      ..lineTo(size.width * 0.22, size.height)
      ..lineTo(size.width * 0.78, size.height)
      ..lineTo(size.width * 0.56, horizon)
      ..close();
    canvas.drawPath(road, Paint()..color = const Color(0xFF15242C));

    final edge = Paint()
      ..color = const Color(0xFFD7E8E2).withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(size.width * 0.44, horizon), Offset(size.width * 0.22, size.height), edge);
    canvas.drawLine(Offset(size.width * 0.56, horizon), Offset(size.width * 0.78, size.height), edge);

    final dash = Paint()
      ..color = const Color(0xFFE7F6F1)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final start = (i / 5 + travel) % 1.0;
      if (start > 0.72) continue;
      final end = math.min(start + 0.08, 0.72);
      final a = _lane(size, start * start);
      final b = _lane(size, end * end);
      dash.strokeWidth = 1.2 + start * 2.4;
      canvas.drawLine(a, b, dash);
    }

    final bob = math.sin(travel * math.pi * 2) * 1.1;
    _car(canvas, Offset(size.width * 0.5, size.height * 0.78 + bob), night);
  }

  Offset _lane(Size size, double depth) {
    final y = size.height * (0.56 + 0.44 * depth);
    return Offset(size.width * 0.5, y);
  }

  void _car(Canvas canvas, Offset center, bool night) {
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(0, 12), width: 28, height: 6),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    final tire = Paint()..color = const Color(0xFF10181C);
    for (final dx in [-14.0, 14.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(dx, 6), width: 5, height: 9),
          const Radius.circular(1.5),
        ),
        tire,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, 2), width: 28, height: 14),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFF4F7F6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center.translate(0, -7), width: 16, height: 8),
        const Radius.circular(3),
      ),
      Paint()..color = night ? const Color(0xFF7EADC0) : const Color(0xFF1E5560),
    );
    final lamp = night ? const Color(0xFFFFE7A3) : const Color(0xFFFFF6D0);
    for (final dx in [-8.0, 8.0]) {
      if (night) {
        canvas.drawCircle(center.translate(dx, 4), 5, Paint()..color = lamp.withValues(alpha: 0.28));
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center.translate(dx, 4), width: 6, height: 4),
          const Radius.circular(1.5),
        ),
        Paint()..color = lamp,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) {
    return oldDelegate.night != night || oldDelegate.travel != travel;
  }
}
