import 'package:flutter/material.dart';

import '../theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'DicomFlow',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.31),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFFF97316)],
            ),
          ),
          child: CustomPaint(painter: _MarkPainter()),
        ),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Colors.white
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(size.width * 0.28, c.dy), Offset(size.width * 0.72, c.dy), stroke);
    canvas.drawLine(Offset(c.dx, size.height * 0.28), Offset(c.dx, size.height * 0.72), stroke);
    canvas.drawCircle(
      c,
      size.width * 0.16,
      stroke..strokeWidth = size.width * 0.047,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final muted2 = DicomFlowTokens.of(context).muted2;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DicomFlow',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
                height: 1.15,
              ),
            ),
            Text(
              '影像随手看',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: muted2,
                letterSpacing: 0.6,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
