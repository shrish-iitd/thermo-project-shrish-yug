import 'package:flutter/material.dart';

import 'chart_data.dart';
import 'chart_painter.dart';
import 'pdf_report.dart';
import 'pr_eos.dart';
import 'substances.dart';

/// Global theme switch (system default until the user taps the toggle).
final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

void main() => runApp(const PrApp());

class PrApp extends StatelessWidget {
  const PrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (_, mode, __) => MaterialApp(
        title: 'PR EOS Calculator',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.teal,
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomePage(),
      ),
    );
  }
}

enum Mode { tp, tv, pv }

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Substance sub = substances.first;
  Mode mode = Mode.tp;
  final tCtrl = TextEditingController(text: '300');
  final pCtrl = TextEditingController(text: '50');
  final vCtrl = TextEditingController(text: '400'); // cm3/mol
  PrResult? result;
  List<ChartSpec> charts = [];
  int sel = 0;
  String? error;
  bool busy = false;

  String get _modeLabel => switch (mode) {
        Mode.tp => 'Given T and P',
        Mode.tv => 'Given T and V',
        Mode.pv => 'Given P and V',
      };

  void _calculate() {
    final t = double.tryParse(tCtrl.text);
    final p = double.tryParse(pCtrl.text);
    final v = double.tryParse(vCtrl.text);
    final needT = mode != Mode.pv;
    final needP = mode != Mode.tv;
    final needV = mode != Mode.tp;
    if (needT && (t == null || t <= 0)) {
      setState(() => error = 'Enter a valid temperature in K.');
      return;
    }
    if (needP && (p == null || p <= 0)) {
      setState(() => error = 'Enter a valid pressure in bar.');
      return;
    }
    if (needV && (v == null || v <= 0)) {
      setState(() => error = 'Enter a valid molar volume in cm³/mol.');
      return;
    }
    try {
      final eos = PengRobinson(sub);
      PrResult r;
      switch (mode) {
        case Mode.tp:
          r = eos.solve(t!, p!);
          break;
        case Mode.tv:
          r = eos.solveFromTV(t!, v! * 1e-6);
          break;
        case Mode.pv:
          r = eos.solveFromPV(p!, v! * 1e-6);
          break;
      }
      final c = buildCharts(eos, r);
      setState(() {
        result = r;
        charts = c;
        if (sel >= c.length) sel = 0;
        error = null;
      });
    } catch (e) {
      setState(() {
        error = e.toString().replaceFirst('Bad state: ', '');
        result = null;
        charts = [];
      });
    }
  }

  Future<void> _savePdf() async {
    final r = result;
    if (r == null || busy) return;
    setState(() => busy = true);
    try {
      await savePdfReport(
        sub: sub,
        eos: PengRobinson(sub),
        r: r,
        modeLabel: _modeLabel,
        charts: charts,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not create PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon) =>
      TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      );

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(k)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(v,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _chip(String s) => Chip(
        label: Text(s, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );

  String _f(double x, [int d = 4]) => x.toStringAsFixed(d);

  PreferredSizeWidget _appBar(bool isDark) {
    final colors = isDark
        ? const [Color(0xFF004D40), Color(0xFF1A237E)]
        : const [Color(0xFF00897B), Color(0xFF3949AB)];
    return AppBar(
      toolbarHeight: 78,
      elevation: 0,
      foregroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset('assets/icon/app_logo.png', fit: BoxFit.cover),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Peng–Robinson EOS',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          SizedBox(height: 2),
          Text('PVT · Enthalpy · Entropy of real gases',
              style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Save report as PDF',
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf_outlined),
          color: Colors.white,
          disabledColor: Colors.white38,
          onPressed: result == null || busy ? null : _savePdf,
        ),
        IconButton(
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
          color: Colors.white,
          onPressed: () =>
              themeMode.value = isDark ? ThemeMode.light : ThemeMode.dark,
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final r = result;
    final eos = PengRobinson(sub);

    return Scaffold(
      appBar: _appBar(isDark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<Substance>(
                value: sub,
                decoration: const InputDecoration(
                  labelText: 'Substance',
                  prefixIcon: Icon(Icons.bubble_chart_outlined),
                  border: OutlineInputBorder(),
                ),
                items: substances
                    .map((s) => DropdownMenuItem(
                        value: s, child: Text('${s.name} (${s.formula})')))
                    .toList(),
                onChanged: (s) => setState(() {
                  sub = s!;
                  result = null;
                  charts = [];
                }),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 0,
                children: [
                  _chip('Tc = ${sub.tc} K'),
                  _chip('Pc = ${sub.pc} bar'),
                  _chip('ω = ${sub.omega}'),
                  _chip('M = ${sub.mw} g/mol'),
                ],
              ),
              const SizedBox(height: 14),
              SegmentedButton<Mode>(
                segments: const [
                  ButtonSegment(value: Mode.tp, label: Text('T & P')),
                  ButtonSegment(value: Mode.tv, label: Text('T & V')),
                  ButtonSegment(value: Mode.pv, label: Text('P & V')),
                ],
                selected: {mode},
                onSelectionChanged: (s) => setState(() => mode = s.first),
              ),
              const SizedBox(height: 14),
              if (mode != Mode.pv) ...[
                _field(tCtrl, 'Temperature (K)', Icons.thermostat),
                const SizedBox(height: 12),
              ],
              if (mode != Mode.tv) ...[
                _field(pCtrl, 'Pressure (bar)', Icons.compress),
                const SizedBox(height: 12),
              ],
              if (mode != Mode.tp)
                _field(vCtrl, 'Molar volume (cm³/mol)', Icons.view_in_ar),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _calculate,
                      icon: const Icon(Icons.calculate),
                      label: const Text('Calculate'),
                    ),
                  ),
                  if (r != null) ...[
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : _savePdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Save PDF'),
                    ),
                  ],
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: TextStyle(color: scheme.error)),
                ),
              if (r != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Text('PVT behaviour', style: theme.textTheme.titleMedium),
                      const Divider(),
                      _row('T', '${_f(r.t, 2)} K  (Tr = ${_f(r.tr, 3)})'),
                      _row('P', '${_f(r.p, 3)} bar  (Pr = ${_f(r.pr, 3)})'),
                      _row('Phase', r.phase),
                      _row('Z', _f(r.z, 5)),
                      _row('Molar volume', '${_f(r.v * 1e6, 2)} cm³/mol'),
                      _row('Density', '${_f(r.density, 3)} kg/m³'),
                      _row('Real roots of Z',
                          r.roots.map((z) => _f(z, 4)).join(', ')),
                      _row('ln φ', _f(r.lnPhi, 5)),
                      _row('Fugacity', '${_f(r.fugacity, 3)} bar'),
                    ]),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(children: [
                      Text('Thermodynamic properties',
                          style: theme.textTheme.titleMedium),
                      const Divider(),
                      _row('Hᴿ (departure)', '${_f(r.hDeparture, 2)} J/mol'),
                      _row('Sᴿ (departure)', '${_f(r.sDeparture, 4)} J/mol·K'),
                      _row('H', '${_f(r.h, 2)} J/mol'),
                      _row('S', '${_f(r.s, 4)} J/mol·K'),
                      const SizedBox(height: 6),
                      Text(
                          'Reference: ideal gas at 298.15 K and 1 bar has H = 0, S = 0.',
                          style: theme.textTheme.bodySmall),
                    ]),
                  ),
                ),
                if (charts.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Graphs', style: theme.textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (var i = 0; i < charts.length; i++)
                                ChoiceChip(
                                  label: Text(charts[i].chip),
                                  selected: i == sel,
                                  onSelected: (_) => setState(() => sel = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(charts[sel].title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 300,
                            width: double.infinity,
                            child: CustomPaint(
                              painter: ChartPainter(
                                charts[sel],
                                textColor: scheme.onSurface,
                                gridColor: scheme.onSurface.withAlpha(35),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(charts[sel].caption,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                    'b = ${(eos.b * 1e6).toStringAsFixed(3)} cm³/mol,  κ = ${eos.kappa.toStringAsFixed(4)}',
                    style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 24),
              Divider(color: scheme.onSurface.withAlpha(40)),
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 12),
                child: Text(
                  'Created by Shrish Kumar and Yug Bhushan',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface.withAlpha(150),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
