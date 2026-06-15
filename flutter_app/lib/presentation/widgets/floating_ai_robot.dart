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
            final hoverOffset = _isDragging ? 0.0 : sin(_controller.value * pi) * 12;
            return Transform.translate(
              offset: Offset(0, hoverOffset),
              child: SizedBox(
                width: 80,
                height: 100,
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
    
    // 1. Antenna (Choti) - More prominent!
    paint.color = Colors.grey[800]!;
    canvas.drawLine(
      Offset(centerX, 20),
      Offset(centerX, 0), // Higher up
      Paint()..color = Colors.grey[800]!..strokeWidth = 3..style = PaintingStyle.stroke..strokeCap = StrokeCap.round,
    );
    // Antenna glowing bulb (binks)
    paint.color = animationValue > 0.5 ? Colors.redAccent : Colors.amberAccent;
    canvas.drawCircle(Offset(centerX, 0), 6, paint);

    // 2. Head
    paint.color = const Color(0xFF2E86C1); // Blue robot head
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, 38), width: 44, height: 34),
      const Radius.circular(12),
    );
    canvas.drawRRect(headRect, paint);

    // Face / Screen
    paint.color = Colors.white;
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, 38), width: 36, height: 22),
      const Radius.circular(6),
    );
    canvas.drawRRect(screenRect, paint);

    // Eyes
    paint.color = const Color(0xFF2E86C1);
    final eyeY = 35.0;
    // Blink animation
    final eyeHeight = (animationValue > 0.95) ? 2.0 : 6.0; 
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX - 8, eyeY), width: 6, height: eyeHeight), paint);
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX + 8, eyeY), width: 6, height: eyeHeight), paint);

    // Smile
    final smilePath = Path()
      ..moveTo(centerX - 8, 42)
      ..quadraticBezierTo(centerX, 48, centerX + 8, 42);
    canvas.drawPath(smilePath, Paint()..color = const Color(0xFF2E86C1)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round);

    // 3. Body
    paint.color = Colors.grey[300]!;
    paint.style = PaintingStyle.fill;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, 68), width: 30, height: 24),
      const Radius.circular(6),
    );
    canvas.drawRRect(bodyRect, paint);

    // 4. Tail (Pooch) - Actual curved tail swinging
    final tailSway = sin(animationValue * pi * 2) * 15; // Swings left and right
    final tailPath = Path()
      ..moveTo(centerX, 78)
      ..quadraticBezierTo(centerX, 90, centerX + tailSway, 95);
    
    canvas.drawPath(
      tailPath, 
      Paint()
        ..color = Colors.grey[700]!
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
    );
    
    // Tail tip (Pooch ka sira)
    canvas.drawCircle(Offset(centerX + tailSway, 95), 5, Paint()..color = const Color(0xFF2E86C1));
  }

  @override
  bool shouldRepaint(covariant _RobotPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
