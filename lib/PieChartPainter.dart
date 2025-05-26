import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class PieChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> categories;

  PieChartPainter({required this.categories});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final center = Offset(size.width / 2, size.height / 2);
    double radius = min(size.width, size.height) / 2;

    // Hitung total pengeluaran
    double totalAmount = categories.fold<double>(
        0.0,
            (sum, e) => sum + (e['amount'] ?? 0.0));

    final colors = [
      const Color(0xFF8A2BE2),
      Colors.orange,
      Colors.green,
      Colors.blue,
      Colors.purple,
      Colors.indigo,
      Colors.teal
    ];

    double currentStartAngle = -pi / 2; // Mulai dari atas

    for (int i = 0; i < categories.length; i++) {
      final amount = (categories[i]['amount'] ?? 0.0) as double;
      final ratio = totalAmount > 0 ? amount / totalAmount : 0;
      final sweepAngle = ratio * 2 * pi;

      if (sweepAngle > 0) {
        // Gambar bagian pie
        paint.color = colors[i % colors.length];
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          currentStartAngle,
          sweepAngle,
          true,
          paint,
        );

        // Tambahkan teks di tengah potongan pie
        final midAngle = currentStartAngle + sweepAngle / 2;
        final textRadius = radius * 0.65;
        final textX = center.dx + textRadius * cos(midAngle);
        final textY = center.dy + textRadius * sin(midAngle);

        final percentage = (ratio * 100).toStringAsFixed(1); // Contoh: 25.1%
        final formattedAmount = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(amount);

        TextSpan span = TextSpan(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,

          ),
          text: '$percentage%\n$formattedAmount',
        );

        TextPainter tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: ui.TextDirection.ltr,
        );
        tp.layout();
        tp.paint(canvas, Offset(textX - tp.width / 2, textY - tp.height / 2));
      }

      currentStartAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}