import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'chart_data.dart';

const List<Color> chartPalette = [
  Color(0xFF00796B), // teal
  Color(0xFFE65100), // orange
  Color(0xFF3949AB), // indigo
  Color(0xFF8E24AA), // purple
  Color(0xFF6D4C41), // brown
  Color(0xFF00838F), // cyan
];

class ChartPainter extends CustomPainter {
  final ChartSpec spec;
  final Color textColor, gridColor;
  ChartPainter(this.spec, {required this.textColor, required this.gridColor});

  static double _log10(double x) => math.log(x) / math.ln10;

  /// Used for log-axis labels (decades such as 1, 2, 5, 10, 20 ...).
  static String _fmt(double v) {
    if (v == 0) return '0';
    final a = v.abs();
    if (a >= 1 && (a - a.roundToDouble()).abs() < 1e-9) {
      return v.toStringAsFixed(0);
    }
    if (a >= 100) return v.toStringAsFixed(0);
    if (a >= 10) return v.toStringAsFixed(1);
    if (a >= 1) return v.toStringAsFixed(2);
    return v.toStringAsPrecision(2);
  }

  /// "Nice" tick values (1, 2 or 5 x 10^k spacing) inside [lo, hi], together
  /// with the number of decimals needed so that no two labels look the same.
  static ({List<double> ticks, int decimals}) _niceTicks(double lo, double hi,
      {int target = 5}) {
    final raw = (hi - lo) / target;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final norm = raw / mag;
    final step = (norm <= 1 ? 1.0 : norm <= 2 ? 2.0 : norm <= 5 ? 5.0 : 10.0) * mag;
    final first = (lo / step).ceil() * step;
    final n = ((hi - first) / step + 1e-9).floor();
    final ticks = List<double>.generate(n + 1, (i) => first + i * step);
    final decimals =
        step >= 1 ? 0 : (-(math.log(step) / math.ln10).floor()).clamp(0, 8);
    return (ticks: ticks, decimals: decimals);
  }

  static String _label(double v, int decimals) {
    final s = v.toStringAsFixed(decimals);
    return double.parse(s) == 0 ? (decimals == 0 ? '0' : '0') : s;
  }

  TextPainter _tp(String s, {double size = 10, bool bold = false, Color? color}) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: size,
          color: color ?? textColor,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _text(Canvas c, String s, Offset o,
      {double size = 10, bool bold = false, TextAlign align = TextAlign.left}) {
    final tp = _tp(s, size: size, bold: bold);
    var dx = o.dx;
    if (align == TextAlign.center) dx -= tp.width / 2;
    if (align == TextAlign.right) dx -= tp.width;
    tp.paint(c, Offset(dx, o.dy));
  }

  void _dashed(Canvas c, Path p, Paint paint) {
    for (final m in p.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        c.drawPath(m.extractPath(d, math.min(d + 6, m.length)), paint);
        d += 10;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const left = 58.0, right = 14.0, top = 28.0, bottom = 44.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    double tx(double x) => spec.logX ? _log10(x) : x;

    final allX = <double>[], allY = <double>[];
    for (final s in spec.series) {
      allX.addAll(s.x);
      allY.addAll(s.y);
    }
    if (spec.markX != null && spec.markY != null) {
      allX.add(spec.markX!);
      allY.add(spec.markY!);
    }
    if (allX.isEmpty) {
      _text(canvas, 'No data to plot', Offset(size.width / 2, size.height / 2),
          align: TextAlign.center, size: 12);
      return;
    }

    var xMin = allX.map(tx).reduce(math.min);
    var xMax = allX.map(tx).reduce(math.max);
    var yMin = allY.reduce(math.min);
    var yMax = allY.reduce(math.max);
    if (xMax - xMin < 1e-12) {
      xMin -= 1;
      xMax += 1;
    }
    if (yMax - yMin < 1e-12) {
      final d = yMin.abs() * 0.05 + 0.05;
      yMin -= d;
      yMax += d;
    } else {
      final pad = (yMax - yMin) * 0.06;
      yMin -= pad;
      yMax += pad;
    }

    double px(double x) => left + (tx(x) - xMin) / (xMax - xMin) * w;
    double py(double y) => top + (1 - (y - yMin) / (yMax - yMin)) * h;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = textColor.withAlpha(140)
      ..strokeWidth = 1.2;

    // horizontal grid + y tick labels
    final yt = _niceTicks(yMin, yMax);
    for (final y in yt.ticks) {
      final yy = py(y);
      canvas.drawLine(Offset(left, yy), Offset(left + w, yy), gridPaint);
      _text(canvas, _label(y, yt.decimals), Offset(left - 6, yy - 6),
          align: TextAlign.right);
    }

    // vertical grid + x tick labels
    final xTicks = <double>[];
    var xDecimals = 0;
    if (spec.logX) {
      for (var k = xMin.floor(); k <= xMax.ceil(); k++) {
        for (final m in [1.0, 2.0, 5.0]) {
          final v = m * math.pow(10, k).toDouble();
          final lv = _log10(v);
          if (lv >= xMin - 1e-9 && lv <= xMax + 1e-9) xTicks.add(v);
        }
      }
    } else {
      final xt = _niceTicks(xMin, xMax);
      xTicks.addAll(xt.ticks);
      xDecimals = xt.decimals;
    }
    for (final v in xTicks) {
      final xx = px(v);
      canvas.drawLine(Offset(xx, top), Offset(xx, top + h), gridPaint);
      _text(canvas, spec.logX ? _fmt(v) : _label(v, xDecimals),
          Offset(xx, top + h + 4),
          align: TextAlign.center);
    }

    // axes
    canvas.drawLine(Offset(left, top), Offset(left, top + h), axisPaint);
    canvas.drawLine(Offset(left, top + h), Offset(left + w, top + h), axisPaint);

    // axis titles
    _text(canvas, spec.xLabel, Offset(left + w / 2, size.height - 16),
        align: TextAlign.center, size: 11, bold: true);
    canvas.save();
    canvas.translate(12, top + h / 2);
    canvas.rotate(-math.pi / 2);
    _text(canvas, spec.yLabel, Offset.zero,
        align: TextAlign.center, size: 11, bold: true);
    canvas.restore();

    // curves (clipped to the plot area)
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(left, top, w, h));
    for (var i = 0; i < spec.series.length; i++) {
      final s = spec.series[i];
      if (s.x.length < 2) continue;
      final path = Path()..moveTo(px(s.x[0]), py(s.y[0]));
      for (var j = 1; j < s.x.length; j++) {
        path.lineTo(px(s.x[j]), py(s.y[j]));
      }
      final paint = Paint()
        ..color = chartPalette[i % chartPalette.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.dashed ? 1.6 : 2.2
        ..strokeJoin = StrokeJoin.round;
      if (s.dashed) {
        _dashed(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();

    // marker for the current state
    if (spec.markX != null && spec.markY != null) {
      final mx = px(spec.markX!), my = py(spec.markY!);
      final guide = Paint()
        ..color = Colors.red.withAlpha(110)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(left, my), Offset(mx, my), guide);
      canvas.drawLine(Offset(mx, top + h), Offset(mx, my), guide);
      canvas.drawCircle(Offset(mx, my), 5.5, Paint()..color = Colors.red);
      canvas.drawCircle(
          Offset(mx, my),
          5.5,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }

    // legend row above the plot
    var lx = left;
    for (var i = 0; i < spec.series.length; i++) {
      final s = spec.series[i];
      final col = chartPalette[i % chartPalette.length];
      final lp = Paint()
        ..color = col
        ..strokeWidth = 2.2;
      if (s.dashed) {
        canvas.drawLine(Offset(lx, 10), Offset(lx + 5, 10), lp);
        canvas.drawLine(Offset(lx + 9, 10), Offset(lx + 14, 10), lp);
      } else {
        canvas.drawLine(Offset(lx, 10), Offset(lx + 14, 10), lp);
      }
      final tp = _tp(s.name, size: 10);
      tp.paint(canvas, Offset(lx + 18, 4));
      lx += 18 + tp.width + 14;
    }
    if (spec.markX != null) {
      canvas.drawCircle(Offset(lx + 4, 10), 4, Paint()..color = Colors.red);
      _tp('Your state', size: 10).paint(canvas, Offset(lx + 12, 4));
    }
  }

  @override
  bool shouldRepaint(covariant ChartPainter old) => true;
}
