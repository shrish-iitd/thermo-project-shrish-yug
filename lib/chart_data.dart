import 'dart:math' as math;
import 'pr_eos.dart';

/// One curve on a chart.
class Series {
  final String name;
  final List<double> x;
  final List<double> y;
  final bool dashed;
  const Series(this.name, this.x, this.y, {this.dashed = false});
}

/// Everything needed to draw one chart (on screen or inside the PDF).
/// Text is kept ASCII-only so the same strings can go into the PDF.
class ChartSpec {
  final String chip, title, xLabel, yLabel, caption;
  final List<Series> series;
  final double? markX, markY; // the user's current state
  final bool logX;
  const ChartSpec({
    required this.chip,
    required this.title,
    required this.xLabel,
    required this.yLabel,
    required this.caption,
    required this.series,
    this.markX,
    this.markY,
    this.logX = false,
  });
}

List<double> _lin(double a, double b, int n) =>
    List.generate(n, (i) => a + (b - a) * i / (n - 1));

List<double> _log(double a, double b, int n) {
  final la = math.log(a), lb = math.log(b);
  return List.generate(n, (i) => math.exp(la + (lb - la) * i / (n - 1)));
}

Series _sample(String name, List<double> xs, double? Function(double x) f,
    {bool dashed = false}) {
  final ox = <double>[], oy = <double>[];
  for (final x in xs) {
    double? y;
    try {
      y = f(x);
    } catch (_) {
      y = null;
    }
    if (y != null && y.isFinite) {
      ox.add(x);
      oy.add(y);
    }
  }
  return Series(name, ox, oy, dashed: dashed);
}

List<ChartSpec> buildCharts(PengRobinson eos, PrResult r) {
  final sub = eos.sub;
  final t = r.t, p = r.p;
  final tTxt = t.toStringAsFixed(1);
  final pTxt = p.toStringAsFixed(2);
  final out = <ChartSpec>[];

  final pMax = math.max(p * 1.5, 10.0);
  final ps = _lin(pMax / 80, pMax, 80);

  // 1. Z vs P ---------------------------------------------------------
  out.add(ChartSpec(
    chip: 'Z vs P',
    title: 'Compressibility factor vs pressure at T = $tTxt K',
    xLabel: 'P (bar)',
    yLabel: 'Z',
    caption:
        'Z = PV/RT. Z = 1 is ideal-gas behaviour; Z < 1 means attractive forces dominate, Z > 1 means repulsion dominates.',
    series: [
      _sample('PR EOS', ps, (x) => eos.solve(t, x).z),
      Series('Ideal gas', [0.0, pMax], [1.0, 1.0], dashed: true),
    ],
    markX: p,
    markY: r.z,
  ));

  // 2. P-V isotherm ---------------------------------------------------
  final vCur = r.v * 1e6; // cm3/mol
  final bCm = eos.b * 1e6;
  final vs = _log(bCm * 1.02, math.max(vCur * 5, bCm * 30), 160);
  final pTop = math.max(sub.pc * 2, p * 2);
  final pBot = -sub.pc;
  out.add(ChartSpec(
    chip: 'P-V',
    title: 'P-V isotherm at T = $tTxt K',
    xLabel: 'Molar volume (cm3/mol, log scale)',
    yLabel: 'P (bar)',
    caption:
        'Below Tc the PR isotherm shows a van der Waals-type loop (two-phase region); above Tc it is monotonic. Dashed: ideal gas.',
    series: [
      _sample('PR EOS', vs, (v) {
        final pp = eos.pressureFromV(t, v * 1e-6);
        return (pp <= pTop && pp >= pBot) ? pp : null;
      }),
      _sample('Ideal gas', vs, (v) {
        final pp = rGas * t / (v * 1e-6) / 1e5;
        return pp <= pTop ? pp : null;
      }, dashed: true),
    ],
    markX: vCur,
    markY: p,
    logX: true,
  ));

  // 3. Generalised Z vs Pr at several Tr ------------------------------
  final prMax = math.max(r.pr * 1.5, 4.0);
  final prs = _lin(prMax / 70, prMax, 70);
  final trList = <double>[1.0, 1.2, 1.5, 2.0];
  out.add(ChartSpec(
    chip: 'Z vs Pr',
    title: 'Generalised compressibility chart (PR EOS) for ${sub.name}',
    xLabel: 'Reduced pressure Pr',
    yLabel: 'Z',
    caption:
        'Z versus reduced pressure for several reduced temperatures. The highlighted curve is your temperature.',
    series: [
      for (final tr in trList)
        _sample('Tr = ${tr.toStringAsFixed(1)}', prs,
            (x) => eos.solve(tr * sub.tc, x * sub.pc).z),
      _sample('Tr = ${r.tr.toStringAsFixed(2)} (yours)', prs,
          (x) => eos.solve(t, x * sub.pc).z,
          dashed: true),
    ],
    markX: r.pr,
    markY: r.z,
  ));

  // 4 & 5. H and S vs T at fixed P ------------------------------------
  final tLo = math.max(t * 0.6, 50.0), tHi = t * 1.6;
  final ts = _lin(tLo, tHi, 70);
  out.add(ChartSpec(
    chip: 'H vs T',
    title: 'Enthalpy vs temperature at P = $pTxt bar',
    xLabel: 'T (K)',
    yLabel: 'H (kJ/mol)',
    caption:
        'Reference: ideal gas at 298.15 K and 1 bar has H = 0. The gap between the curves is the residual enthalpy H^R. Jumps indicate a phase change.',
    series: [
      _sample('PR EOS (real)', ts, (x) => eos.solve(x, p).h / 1000),
      _sample('Ideal gas', ts, (x) {
        final q = eos.solve(x, p);
        return (q.h - q.hDeparture) / 1000;
      }, dashed: true),
    ],
    markX: t,
    markY: r.h / 1000,
  ));
  out.add(ChartSpec(
    chip: 'S vs T',
    title: 'Entropy vs temperature at P = $pTxt bar',
    xLabel: 'T (K)',
    yLabel: 'S (J/mol K)',
    caption:
        'Reference: ideal gas at 298.15 K and 1 bar has S = 0. The gap between the curves is the residual entropy S^R.',
    series: [
      _sample('PR EOS (real)', ts, (x) => eos.solve(x, p).s),
      _sample('Ideal gas', ts, (x) {
        final q = eos.solve(x, p);
        return q.s - q.sDeparture;
      }, dashed: true),
    ],
    markX: t,
    markY: r.s,
  ));

  // 6 & 7. Departure functions vs P at fixed T ------------------------
  out.add(ChartSpec(
    chip: 'H^R vs P',
    title: 'Residual enthalpy vs pressure at T = $tTxt K',
    xLabel: 'P (bar)',
    yLabel: 'H^R (kJ/mol)',
    caption:
        'H^R = H(real) - H(ideal gas) at the same T and P. It tends to zero as P tends to zero.',
    series: [_sample('H^R', ps, (x) => eos.solve(t, x).hDeparture / 1000)],
    markX: p,
    markY: r.hDeparture / 1000,
  ));
  out.add(ChartSpec(
    chip: 'S^R vs P',
    title: 'Residual entropy vs pressure at T = $tTxt K',
    xLabel: 'P (bar)',
    yLabel: 'S^R (J/mol K)',
    caption:
        'S^R = S(real) - S(ideal gas) at the same T and P. It is negative because the real gas is more ordered than the ideal gas.',
    series: [_sample('S^R', ps, (x) => eos.solve(t, x).sDeparture)],
    markX: p,
    markY: r.sDeparture,
  ));

  // 8. Fugacity coefficient vs P --------------------------------------
  out.add(ChartSpec(
    chip: 'phi vs P',
    title: 'Fugacity coefficient vs pressure at T = $tTxt K',
    xLabel: 'P (bar)',
    yLabel: 'phi = f/P',
    caption:
        'phi = 1 for an ideal gas (dashed). phi < 1 indicates attraction dominates; phi > 1 indicates repulsion dominates.',
    series: [
      _sample('PR EOS', ps, (x) => math.exp(eos.solve(t, x).lnPhi)),
      Series('Ideal gas', [0.0, pMax], [1.0, 1.0], dashed: true),
    ],
    markX: p,
    markY: math.exp(r.lnPhi),
  ));

  return out;
}
