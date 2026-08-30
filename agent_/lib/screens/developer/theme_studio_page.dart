import 'package:flutter/material.dart';
import '../../core/theme/theme_controller.dart';
import '../../services/settings_service.dart';

/// Live Theme Studio — bound to existing [ThemeController] (token system).
/// Does not bypass; only reads/writes existing tokens. No raw overrides.
class ThemeStudioPage extends StatefulWidget {
  const ThemeStudioPage({super.key});
  @override
  State<ThemeStudioPage> createState() => _ThemeStudioPageState();
}

class _ThemeStudioPageState extends State<ThemeStudioPage> {
  final _settings = SettingsService();
  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.of(context);
    final mode = controller.mode;
    return Scaffold(
      appBar: AppBar(title: const Text('Theme Studio')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Mode', style: TextStyle(fontWeight: FontWeight.bold)),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'system', label: Text('System')),
            ButtonSegment(value: 'light', label: Text('Light')),
            ButtonSegment(value: 'dark', label: Text('Dark')),
          ],
          selected: {mode},
          onSelectionChanged: (s) {
            controller.setMode(s.first);
            _settings.setThemeMode(s.first);
          },
        ),
        const SizedBox(height: 24),
        const Text('Accent', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: controller.availableAccents.map((a) {
          final selected = a == controller.accent;
          return ChoiceChip(
            label: Text(a),
            selected: selected,
            onSelected: (_) => controller.setAccent(a),
          );
        }).toList()),
        const SizedBox(height: 24),
        const Text('Gradient Preset', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 8, children: controller.availableGradients.map((g) {
          return ChoiceChip(
            label: Text(g),
            selected: g == controller.gradient,
            onSelected: (_) => controller.setGradient(g),
          );
        }).toList()),
      ]),
    );
  }
}
