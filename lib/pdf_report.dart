import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Colors;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'chart_data.dart';
import 'chart_painter.dart';
import 'pr_eos.dart';
import 'substances.dart';

/// Draws a chart off-screen (white background) and returns it as PNG bytes.
Future<Uint8List> _chartPng(ChartSpec spec,
    {double w = 640, double h = 340, double scale = 2.5}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.scale(scale);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = Colors.white);
  ChartPainter(spec, textColor: Colors.black87, gridColor: const ui.Color(0x22000000))
      .paint(canvas, ui.Size(w, h));
  final picture = recorder.endRecording();
  final image = await picture.toImage((w * scale).round(), (h * scale).round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

String _two(int n) => n.toString().padLeft(2, '0');
String _f(double x, [int d = 4]) => x.toStringAsFixed(d);

pw.Widget _cell(String s, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: pw.Text(s,
          style: pw.TextStyle(
              fontSize: 10,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );

pw.Widget _table(List<List<String>> rows) => pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(2.5),
      },
      children: [
        for (final r in rows)
          pw.TableRow(children: [_cell(r[0]), _cell(r[1], bold: true)]),
      ],
    );

pw.Widget _heading(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
      child: pw.Text(s,
          style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.teal800)),
    );

/// Builds the report and opens the platform's save/share dialog.
Future<void> savePdfReport({
  required Substance sub,
  required PengRobinson eos,
  required PrResult r,
  required String modeLabel,
  required List<ChartSpec> charts,
}) async {
  final now = DateTime.now();
  final stamp =
      '${now.year}-${_two(now.month)}-${_two(now.day)} ${_two(now.hour)}:${_two(now.minute)}';

  final images = <pw.MemoryImage>[];
  for (final c in charts) {
    images.add(pw.MemoryImage(await _chartPng(c)));
  }

  final doc = pw.Document(title: 'PR EOS report - ${sub.name}');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ),
      build: (ctx) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.teal700,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Peng-Robinson EOS Report',
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 4),
              pw.Text('${sub.name} (${sub.formula})   |   $stamp',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.white)),
            ],
          ),
        ),

        _heading('1. Substance data'),
        _table([
          ['Substance', '${sub.name} (${sub.formula})'],
          ['Molar mass', '${sub.mw} g/mol'],
          ['Critical temperature Tc', '${sub.tc} K'],
          ['Critical pressure Pc', '${sub.pc} bar'],
          ['Acentric factor omega', '${sub.omega}'],
          ['PR parameter kappa', _f(eos.kappa, 5)],
          ['PR covolume b', '${_f(eos.b * 1e6, 3)} cm3/mol'],
          ['PR attraction a(T)', '${eos.a(r.t).toStringAsExponential(4)} J m3/mol2'],
        ]),

        _heading('2. Input specification'),
        _table([
          ['Input mode', modeLabel],
          ['Temperature T', '${_f(r.t, 2)} K  (Tr = ${_f(r.tr, 3)})'],
          ['Pressure P', '${_f(r.p, 3)} bar  (Pr = ${_f(r.pr, 3)})'],
          ['Molar volume V', '${_f(r.v * 1e6, 2)} cm3/mol'],
        ]),

        _heading('3. PVT results'),
        _table([
          ['Phase', r.phase],
          ['Compressibility factor Z', _f(r.z, 5)],
          ['Real roots of Z (physical)', r.roots.map((z) => _f(z, 4)).join(', ')],
          ['Density', '${_f(r.density, 3)} kg/m3'],
          ['ln(phi)', _f(r.lnPhi, 5)],
          ['Fugacity coefficient phi', _f(r.fugacity / r.p, 5)],
          ['Fugacity f', '${_f(r.fugacity, 3)} bar'],
        ]),

        _heading('4. Thermodynamic properties'),
        _table([
          ['Residual enthalpy H^R', '${_f(r.hDeparture, 2)} J/mol'],
          ['Residual entropy S^R', '${_f(r.sDeparture, 4)} J/(mol K)'],
          ['Enthalpy H', '${_f(r.h, 2)} J/mol'],
          ['Entropy S', '${_f(r.s, 4)} J/(mol K)'],
        ]),
        pw.SizedBox(height: 4),
        pw.Text(
            'Reference state: ideal gas at 298.15 K and 1 bar has H = 0 and S = 0. '
            'Only differences between two states are physically meaningful.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),

        _heading('5. Method'),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey200,
          child: pw.Text(
            'P = RT/(V-b) - a(T)/[V(V+b)+b(V-b)]\n'
            'a = 0.45724 R^2 Tc^2/Pc * alpha,  b = 0.07780 R Tc/Pc\n'
            'alpha = [1 + kappa(1 - sqrt(T/Tc))]^2\n'
            'kappa = 0.37464 + 1.54226 w - 0.26992 w^2\n'
            'Z^3 - (1-B) Z^2 + (A - 3B^2 - 2B) Z - (AB - B^2 - B^3) = 0\n'
            'H^R = RT(Z-1) + (T da/dT - a)/(2 sqrt2 b) * L\n'
            'S^R = R ln(Z-B) + (da/dT)/(2 sqrt2 b) * L\n'
            'L = ln[(Z+(1+sqrt2)B)/(Z+(1-sqrt2)B)]\n'
            'H = H_ideal(T) + H^R,   S = S_ideal(T,P) + S^R',
            style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
          ),
        ),

        _heading('6. Graphs'),
        for (var i = 0; i < charts.length; i++)
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Figure ${i + 1}. ${charts[i].title}',
                    style: pw.TextStyle(
                        fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Image(images[i], width: 460),
                pw.SizedBox(height: 2),
                pw.Text(charts[i].caption,
                    style: pw.TextStyle(
                        fontSize: 8.5,
                        fontStyle: pw.FontStyle.italic,
                        color: PdfColors.grey700)),
              ],
            ),
          ),
      ],
    ),
  );

  final bytes = await doc.save();
  final tag = '${sub.formula}_${r.t.toStringAsFixed(0)}K_${r.p.toStringAsFixed(1)}bar';
  await Printing.sharePdf(bytes: bytes, filename: 'PR_EOS_$tag.pdf');
}
