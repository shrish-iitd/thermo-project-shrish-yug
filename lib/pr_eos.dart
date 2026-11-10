import 'dart:math' as math;
import 'substances.dart';

const double rGas = 8.314462618; // J/(mol K)
const double tRef = 298.15; // K   reference state for ideal-gas H = 0, S = 0
const double pRef = 1.0; // bar

class PrResult {
  final double t; // K
  final double p; // bar
  final double tr, pr;
  final double z;
  final double v; // m3/mol
  final double density; // kg/m3
  final String phase;
  final List<double> roots;
  final double lnPhi;
  final double fugacity; // bar
  final double hDeparture, sDeparture; // J/mol, J/(mol K)
  final double h, s; // J/mol, J/(mol K) relative to ideal gas at 298.15 K, 1 bar

  PrResult({
    required this.t,
    required this.p,
    required this.tr,
    required this.pr,
    required this.z,
    required this.v,
    required this.density,
    required this.phase,
    required this.roots,
    required this.lnPhi,
    required this.fugacity,
    required this.hDeparture,
    required this.sDeparture,
    required this.h,
    required this.s,
  });
}

class PengRobinson {
  final Substance sub;
  PengRobinson(this.sub);

  static final double _sqrt2 = math.sqrt(2.0);

  double get _pcPa => sub.pc * 1e5;
  double get _ac => 0.45724 * rGas * rGas * sub.tc * sub.tc / _pcPa;
  double get b => 0.07780 * rGas * sub.tc / _pcPa;
  double get kappa =>
      0.37464 + 1.54226 * sub.omega - 0.26992 * sub.omega * sub.omega;

  double alpha(double t) {
    final x = 1 + kappa * (1 - math.sqrt(t / sub.tc));
    return x * x;
  }

  double a(double t) => _ac * alpha(t);

  /// da/dT
  double dadT(double t) => -_ac * kappa * math.sqrt(alpha(t) / (t * sub.tc));

  /// Pressure (bar) from T (K) and molar volume (m3/mol).
  double pressureFromV(double t, double v) {
    final p = rGas * t / (v - b) - a(t) / (v * (v + b) + b * (v - b));
    return p / 1e5;
  }

  static double _cbrt(double x) =>
      x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

  /// Real roots of the PR cubic in Z that are physical (Z > B), sorted ascending.
  List<double> zRoots(double t, double pBar) {
    final p = pBar * 1e5;
    final aa = a(t) * p / math.pow(rGas * t, 2);
    final bb = b * p / (rGas * t);

    final c2 = -(1 - bb);
    final c1 = aa - 3 * bb * bb - 2 * bb;
    final c0 = -(aa * bb - bb * bb - bb * bb * bb);

    // depressed cubic t^3 + pp*t + qq = 0, Z = t - c2/3
    final pp = c1 - c2 * c2 / 3;
    final qq = 2 * c2 * c2 * c2 / 27 - c2 * c1 / 3 + c0;
    final disc = qq * qq / 4 + pp * pp * pp / 27;

    final roots = <double>[];
    if (disc >= 0) {
      final sd = math.sqrt(disc);
      roots.add(_cbrt(-qq / 2 + sd) + _cbrt(-qq / 2 - sd) - c2 / 3);
    } else {
      final r = 2 * math.sqrt(-pp / 3);
      final arg = (3 * qq / (2 * pp)) * math.sqrt(-3 / pp);
      final phi = math.acos(arg.clamp(-1.0, 1.0)) / 3;
      for (var k = 0; k < 3; k++) {
        roots.add(r * math.cos(phi - 2 * math.pi * k / 3) - c2 / 3);
      }
    }
    final valid = roots.where((z) => z > bb).toList()..sort();
    return valid;
  }

  double _lnPhi(double t, double pBar, double z) {
    final p = pBar * 1e5;
    final aa = a(t) * p / math.pow(rGas * t, 2);
    final bb = b * p / (rGas * t);
    final l = math.log((z + (1 + _sqrt2) * bb) / (z + (1 - _sqrt2) * bb));
    return z - 1 - math.log(z - bb) - aa / (2 * _sqrt2 * bb) * l;
  }

  double _hIdeal(double t) {
    final s = sub;
    return rGas *
        (s.cpA * (t - tRef) +
            s.cpB / 2 * (t * t - tRef * tRef) +
            s.cpC / 3 * (t * t * t - tRef * tRef * tRef) -
            s.cpD * (1 / t - 1 / tRef));
  }

  double _sIdealT(double t) {
    final s = sub;
    return rGas *
        (s.cpA * math.log(t / tRef) +
            s.cpB * (t - tRef) +
            s.cpC / 2 * (t * t - tRef * tRef) -
            s.cpD / 2 * (1 / (t * t) - 1 / (tRef * tRef)));
  }

  /// Full calculation at (T [K], P [bar]).
  /// If [targetZ] is given, the root closest to it is used (for the T,V mode);
  /// otherwise the root of lowest fugacity (most stable phase) is used.
  PrResult solve(double t, double pBar, {double? targetZ}) {
    final roots = zRoots(t, pBar);
    if (roots.isEmpty) {
      throw StateError('No physical root found.');
    }

    double z;
    if (targetZ != null) {
      z = roots.reduce(
          (x, y) => (x - targetZ).abs() < (y - targetZ).abs() ? x : y);
    } else {
      z = roots.reduce(
          (x, y) => _lnPhi(t, pBar, x) < _lnPhi(t, pBar, y) ? x : y);
    }

    final p = pBar * 1e5;
    final bb = b * p / (rGas * t);
    final l = math.log((z + (1 + _sqrt2) * bb) / (z + (1 - _sqrt2) * bb));
    final da = dadT(t);

    final hR = rGas * t * (z - 1) + (t * da - a(t)) / (2 * _sqrt2 * b) * l;
    final sR = rGas * math.log(z - bb) + da / (2 * _sqrt2 * b) * l;

    final hTotal = _hIdeal(t) + hR;
    final sTotal = _sIdealT(t) - rGas * math.log(pBar / pRef) + sR;

    final v = z * rGas * t / p;
    final tr = t / sub.tc, pr = pBar / sub.pc;
    final lnPhi = _lnPhi(t, pBar, z);

    String phase;
    if (tr >= 1 && pr >= 1) {
      phase = 'Supercritical fluid';
    } else if (roots.length == 3) {
      phase = z == roots.last ? 'Vapor (3 roots, stable)' : 'Liquid (3 roots, stable)';
    } else if (tr >= 1) {
      phase = 'Gas (T > Tc)';
    } else {
      phase = z > 0.3 ? 'Vapor' : 'Liquid';
    }

    return PrResult(
      t: t,
      p: pBar,
      tr: tr,
      pr: pr,
      z: z,
      v: v,
      density: sub.mw / 1000 / v,
      phase: phase,
      roots: roots,
      lnPhi: lnPhi,
      fugacity: pBar * math.exp(lnPhi),
      hDeparture: hR,
      sDeparture: sR,
      h: hTotal,
      s: sTotal,
    );
  }

  /// Given T and molar volume, find P and then the properties.
  PrResult solveFromTV(double t, double vM3PerMol) {
    if (vM3PerMol <= b) {
      throw StateError('Molar volume must be larger than b = ${(b * 1e6).toStringAsFixed(2)} cm3/mol.');
    }
    final pBar = pressureFromV(t, vM3PerMol);
    if (pBar <= 0) {
      throw StateError('Computed pressure is not positive (inside the unstable/spinodal region).');
    }
    final zTarget = pBar * 1e5 * vM3PerMol / (rGas * t);
    return solve(t, pBar, targetZ: zTarget);
  }

  /// Given P (bar) and molar volume (m3/mol), find T (K) and then the properties.
  /// With x = sqrt(T), the PR equation is a quadratic in x:
  ///   alpha = (c0 - c1*x)^2,  c0 = 1 + kappa,  c1 = kappa / sqrt(Tc)
  ///   P = R x^2/(V-b) - ac (c0 - c1 x)^2 / D,   D = V^2 + 2bV - b^2
  PrResult solveFromPV(double pBar, double vM3PerMol) {
    if (vM3PerMol <= b) {
      throw StateError(
          'Molar volume must be larger than b = ${(b * 1e6).toStringAsFixed(2)} cm3/mol.');
    }
    final p = pBar * 1e5;
    final v = vM3PerMol;
    final d = v * v + 2 * b * v - b * b;
    final c0 = 1 + kappa;
    final c1 = kappa / math.sqrt(sub.tc);

    final qa = rGas / (v - b) - _ac * c1 * c1 / d;
    final qb = 2 * _ac * c0 * c1 / d;
    final qc = -_ac * c0 * c0 / d - p;

    final xs = <double>[];
    if (qa.abs() < 1e-14) {
      if (qb.abs() > 0) xs.add(-qc / qb);
    } else {
      final disc = qb * qb - 4 * qa * qc;
      if (disc >= 0) {
        final sd = math.sqrt(disc);
        xs.add((-qb + sd) / (2 * qa));
        xs.add((-qb - sd) / (2 * qa));
      }
    }
    // keep positive x on the physical branch of alpha (c0 - c1 x > 0)
    final temps = xs
        .where((x) => x > 0 && c0 - c1 * x > 0)
        .map((x) => x * x)
        .toList()
      ..sort();
    if (temps.isEmpty) {
      throw StateError('No physical temperature satisfies the given P and V.');
    }
    final t = temps.last;
    final zTarget = p * v / (rGas * t);
    return solve(t, pBar, targetZ: zTarget);
  }

  /// Z-vs-P isotherm at fixed T for plotting.
  List<List<double>> zIsotherm(double t, double pMaxBar, {int n = 80}) {
    final xs = <double>[], ys = <double>[];
    for (var i = 1; i <= n; i++) {
      final p = pMaxBar * i / n;
      try {
        final r = solve(t, p);
        xs.add(p);
        ys.add(r.z);
      } catch (_) {}
    }
    return [xs, ys];
  }
}
