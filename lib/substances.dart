/// Built-in data for ten substances.
/// Critical properties and acentric factors: Smith, Van Ness & Abbott, Table B.1.
/// Ideal-gas heat capacity: Cp/R = A + B*T + C*T^2 + D/T^2  (T in K), SVNA Table C.1.
class Substance {
  final String name;
  final String formula;
  final double mw; // g/mol
  final double tc; // K
  final double pc; // bar
  final double omega; // acentric factor
  final double cpA, cpB, cpC, cpD;

  const Substance({
    required this.name,
    required this.formula,
    required this.mw,
    required this.tc,
    required this.pc,
    required this.omega,
    required this.cpA,
    this.cpB = 0,
    this.cpC = 0,
    this.cpD = 0,
  });
}

const List<Substance> substances = [
  Substance(
      name: 'Methane', formula: 'CH4', mw: 16.043, tc: 190.6, pc: 45.99,
      omega: 0.012, cpA: 1.702, cpB: 9.081e-3, cpC: -2.164e-6),
  Substance(
      name: 'Ethane', formula: 'C2H6', mw: 30.070, tc: 305.3, pc: 48.72,
      omega: 0.100, cpA: 1.131, cpB: 19.225e-3, cpC: -5.561e-6),
  Substance(
      name: 'Propane', formula: 'C3H8', mw: 44.097, tc: 369.8, pc: 42.48,
      omega: 0.152, cpA: 1.213, cpB: 28.785e-3, cpC: -8.824e-6),
  Substance(
      name: 'n-Butane', formula: 'C4H10', mw: 58.123, tc: 425.1, pc: 37.96,
      omega: 0.200, cpA: 1.935, cpB: 36.915e-3, cpC: -11.402e-6),
  Substance(
      name: 'Ethylene', formula: 'C2H4', mw: 28.054, tc: 282.3, pc: 50.40,
      omega: 0.087, cpA: 1.424, cpB: 14.394e-3, cpC: -4.392e-6),
  Substance(
      name: 'Carbon dioxide', formula: 'CO2', mw: 44.010, tc: 304.2, pc: 73.83,
      omega: 0.224, cpA: 5.457, cpB: 1.045e-3, cpD: -1.157e5),
  Substance(
      name: 'Nitrogen', formula: 'N2', mw: 28.013, tc: 126.2, pc: 34.00,
      omega: 0.038, cpA: 3.280, cpB: 0.593e-3, cpD: 0.040e5),
  Substance(
      name: 'Oxygen', formula: 'O2', mw: 31.999, tc: 154.6, pc: 50.43,
      omega: 0.022, cpA: 3.639, cpB: 0.506e-3, cpD: -0.227e5),
  Substance(
      name: 'Ammonia', formula: 'NH3', mw: 17.031, tc: 405.7, pc: 112.8,
      omega: 0.253, cpA: 3.578, cpB: 3.020e-3, cpD: -0.186e5),
  Substance(
      name: 'Hydrogen sulfide', formula: 'H2S', mw: 34.081, tc: 373.5, pc: 89.63,
      omega: 0.094, cpA: 3.931, cpB: 1.490e-3, cpD: -0.232e5),
];
