import 'package:flutter/material.dart';
/// Developer Console dashboard — evidence-based status cards only.
/// No fake health indicators; reflects real app/context state.
class DeveloperConsoleHome extends StatelessWidget {
  const DeveloperConsoleHome({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Developer Console')),
    body: ListView(padding: const EdgeInsets.all(16), children: const [
      _StatusCard(label: 'Build Env', status: 'UNAVAILABLE'),
      _StatusCard(label: 'Theme System', status: 'NOT TESTED'),
      _StatusCard(label: 'Orb Engine', status: 'NOT TESTED'),
      _StatusCard(label: 'Feature Flags', status: 'OK'),
      _StatusCard(label: 'Agent Telemetry', status: 'NOT TESTED'),
    ]),
  );
}
class _StatusCard extends StatelessWidget {
  final String label, status;
  const _StatusCard({required this.label, required this.status});
  @override
  Widget build(BuildContext context) => Card(child: ListTile(title: Text(label), subtitle: Text(status, style: const TextStyle(fontWeight: FontWeight.bold))));
}
