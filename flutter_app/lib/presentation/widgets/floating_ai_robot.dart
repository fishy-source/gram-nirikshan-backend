import 'dart:math';
import 'package:flutter/material.dart';

class FloatingAIRobot extends StatefulWidget {
  final VoidCallback onTap;

  const FloatingAIRobot({super.key, required this.onTap});

  @override
  State<FloatingAIRobot> createState() => _FloatingAIRobotState();
}

class _FloatingAIRobotState extends State<FloatingAIRobot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _position = const Offset(20, 100);
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            // Bound to screen
            _position = Offset(
              _position.dx.clamp(0, screenSize.width - 60),
              _position.dy.clamp(0, screenSize.height - 120),
            );
          });
        },
        onPanEnd: (_) {
          setState(() {
            _isDragging = false;
            // Snap to edge
            if (_position.dx > screenSize.width / 2) {
              _position = Offset(screenSize.width - 70, _position.dy);
            } else {
              _position = Offset(10, _position.dy);
            }
          });
        },
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            // Hover effect only when not dragging
            final hoverOffset = _isDragging ? 0.0 : sin(_controller.value * pi) * 10;
            return Transform.translate(
              offset: Offset(0, hoverOffset),
              child: SizedBox(
                width: 60,
                height: 80,
                child: CustomPaint(
                  painter: _RobotPainter(_controller.value),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RobotPainter extends CustomPainter {
  final double animationValue;

  _RobotPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    
    // 1. Antenna (Choti)
    paint.color = Colors.grey[700]!;
    canvas.drawLine(
      Offset(centerX, 15),
      Offset(centerX, 5),
      Paint()..color = Colors.grey[700]!..strokeWidth = 3..style = PaintingStyle.stroke,
    );
    // Antenna glowing bulb
    paint.color = animationValue > 0.5 ? Colors.redAccent : Colors.orangeAccent;
    canvas.drawCircle(Offset(centerX, 5), 4, paint);

    // 2. Head
    paint.color = const Color(0xFF2E86C1); // Blue robot head
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, 30), width: 40, height: 30),
      const Radius.circular(8),
    );
    canvas.drawRRect(headRect, paint);

    // Face / Screen
    paint.color = Colors.white;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, 30), width: 32, height: 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(screenRect, paint);

    // Eyes
    paint.color = const Color(0xFF2E86C1);
    final eyeY = 28.0;
    // Blink animation
    final eyeHeight = (animationValue > 0.95) ? 2.0 : 6.0; 
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX - 8, eyeY), width: 6, height: eyeHeight), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX + 8, eyeY), width: 6, height: eyeHeight), paint);

    // Smile
    final smilePath = Path()
      ..moveTo(centerX - 6, 34)
      ..quadraticBezierTo(centerX, 38, centerX + 6, 34);
    canvas.drawPath(smilePath, Paint()..color = const Color(0xFF2E86C1)..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // 3. Body
    paint.color = Colors.grey[300]!;
    paint.style = PaintingStyle.fill;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, 55), width: 24, height: 20),
      const Radius.circular(4),
    );
    canvas.drawRRect(bodyRect, paint);

    // 4. Tail (Pooch) - Jet exhaust
    final tailPath = Path()
      ..moveTo(centerX - 6, 65)
      ..lineTo(centerX + 6, 65)
      ..lineTo(centerX, 65 + (animationValue * 15)) // Flame flickers based on animation
      ..close();
    
    paint.color = Colors.orangeAccent.withOpacity(0.8);
    canvas.drawPath(tailPath, paint);
    
    final innerTailPath = Path()
      ..moveTo(centerX - 3, 65)
      ..lineTo(centerX + 3, 65)
      ..lineTo(centerX, 65 + (animationValue * 8))
      ..close();
    paint.color = Colors.yellowAccent.withOpacity(0.9);
    canvas.drawPath(innerTailPath, paint);
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
