import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/habitant.dart';

class RoomView extends StatefulWidget {
  const RoomView({
    super.key,
    required this.state,
    required this.onCreatureTap,
    required this.onMarkTap,
  });

  final Habitant state;
  final VoidCallback onCreatureTap;
  final VoidCallback onMarkTap;

  @override
  State<RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<RoomView>
    with TickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );
  late final AnimationController reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  @override
  void didUpdateWidget(covariant RoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.interactions != widget.state.interactions &&
        !MediaQuery.disableAnimationsOf(context)) {
      reaction.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      animation.stop();
      animation.value = 0;
      reaction.stop();
      reaction.value = 0;
    } else {
      animation.repeat();
    }
  }

  @override
  void dispose() {
    animation.dispose();
    reaction.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.2,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _RoomPainter()),
          if (widget.state.mystery != MysteryStage.hidden)
            Align(
              alignment: const Alignment(0.72, -0.25),
              child: IconButton(
                tooltip: 'Marca misteriosa en la pared',
                onPressed: widget.state.mystery == MysteryStage.appeared
                    ? widget.onMarkTap
                    : null,
                icon: Icon(
                  Icons.all_inclusive,
                  size: 34,
                  color: widget.state.mystery == MysteryStage.examined
                      ? const Color(0xffa1b7a4)
                      : const Color(0xffe4c99c),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: Listenable.merge([animation, reaction]),
            builder: (context, _) {
              final phase = animation.value * math.pi * 2;
              final exploring = widget.state.activity == Activity.exploring;
              final response = math.sin(reaction.value * math.pi).abs();
              return Align(
                alignment: Alignment(
                  exploring ? math.sin(phase) * 0.35 : -0.08,
                  0.45 + math.sin(phase) * 0.035 - response * 0.16,
                ),
                child: Semantics(
                  label: 'Criatura. Tocar para saludar',
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onCreatureTap,
                    child: SizedBox(
                      width: 110,
                      height: 130,
                      child: CustomPaint(
                        painter: _CreaturePainter(
                          phase: phase,
                          emotion: widget.state.emotion,
                          resting: widget.state.activity == Activity.resting,
                          response: response,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _RoomPainter extends CustomPainter {
  const _RoomPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wall = Paint()..color = const Color(0xff34444a);
    canvas.drawRect(Offset.zero & size, wall);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
      Paint()..color = const Color(0xff5e5c52),
    );
    canvas.drawLine(
      Offset(0, size.height * 0.72),
      Offset(size.width, size.height * 0.72),
      Paint()..color = const Color(0xff26383a)..strokeWidth = 4,
    );
    final window = Rect.fromLTWH(
      size.width * 0.13, size.height * 0.12,
      size.width * 0.23, size.height * 0.30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(35)),
      Paint()..color = const Color(0xffabc1b7),
    );
    canvas.drawLine(
      window.topCenter, window.bottomCenter,
      Paint()..color = const Color(0xff526466)..strokeWidth = 5,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.47, size.height * 0.86),
          width: size.width * 0.36, height: size.height * 0.10),
      Paint()..color = const Color(0xff474b43),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter oldDelegate) => false;
}

class _CreaturePainter extends CustomPainter {
  const _CreaturePainter({
    required this.phase,
    required this.emotion,
    required this.resting,
    required this.response,
  });

  final double phase;
  final Emotion emotion;
  final bool resting;
  final double response;

  @override
  void paint(Canvas canvas, Size size) {
    final breath = 1 + math.sin(phase) * 0.025;
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.54);
    canvas.scale(breath + response * 0.08,
        resting ? 0.83 : 1 / breath + response * 0.07);
    final body = Paint()..color = emotion == Emotion.curious
        ? const Color(0xffd5c497)
        : const Color(0xffb3c5ac);
    final ear = Path()
      ..moveTo(-35, -15)..lineTo(-32, -56)..lineTo(-7, -29)
      ..moveTo(9, -29)..lineTo(35, -56)..lineTo(37, -10);
    canvas.drawPath(ear, body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-43, -32, 86, 88),
          const Radius.circular(36)),
      body,
    );
    final eyes = Paint()..color = const Color(0xff233a38)..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final blink = resting || math.cos(phase) > 0.985;
    for (final x in [-17.0, 17.0]) {
      if (blink) {
        canvas.drawLine(Offset(x - 5, 0), Offset(x + 5, 0), eyes);
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset(x, 0),
            width: 8, height: emotion == Emotion.cautious ? 9 : 13), eyes);
      }
    }
    if (emotion == Emotion.calm || response > 0.2) {
      final smile = Path()
        ..moveTo(-6, 17)
        ..quadraticBezierTo(0, 24 + response * 4, 7, 17);
      canvas.drawPath(smile, eyes..style = PaintingStyle.stroke);
    } else if (emotion == Emotion.cautious || emotion == Emotion.reserved) {
      canvas.drawLine(const Offset(-4, 19), const Offset(4, 19), eyes);
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(0, 19), width: 5, height: 7),
        eyes,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CreaturePainter oldDelegate) =>
      phase != oldDelegate.phase || emotion != oldDelegate.emotion ||
      resting != oldDelegate.resting || response != oldDelegate.response;
}
