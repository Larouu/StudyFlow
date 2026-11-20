import 'package:flutter/material.dart';
import '../providers/studyflow_provider.dart';

class AiInsightsPanel extends StatefulWidget {
  const AiInsightsPanel({
    super.key,
    required this.store,
    required this.module,
    required this.title,
  });

  final StudyFlowStore store;
  final String module;
  final String title;

  @override
  State<AiInsightsPanel> createState() => _AiInsightsPanelState();
}

class _AiInsightsPanelState extends State<AiInsightsPanel> {
  List<Map<String, dynamic>> _insights = [];
  bool _loading = false;

  Future<void> _analyze() async {
    setState(() => _loading = true);
    final insights = await widget.store.generateAiInsights(widget.module);
    if (!mounted) return;
    setState(() {
      _insights = insights;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFF312E81),
          child: Icon(Icons.auto_awesome, size: 18, color: Color(0xFFC4B5FD)),
        ),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: const Text('Analyse locale explicable · aucune donnée externe', style: TextStyle(fontSize: 10)),
        trailing: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : IconButton(
                tooltip: 'Analyser',
                onPressed: _analyze,
                icon: const Icon(Icons.refresh, size: 18),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (_insights.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _analyze,
                icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                label: const Text('Générer les insights'),
              ),
            )
          else
            ..._insights.map((insight) {
              final confidence = insight['confidence'] is num
                  ? (insight['confidence'] as num).clamp(0, 1).toDouble()
                  : 0.0;
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            insight['title']?.toString() ?? insight['kind']?.toString() ?? 'Insight',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Text('${(confidence * 100).round()}%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(insight['explanation']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                    if (insight['action'] != null) ...[
                      const SizedBox(height: 8),
                      Chip(
                        label: Text(insight['action'].toString(), style: const TextStyle(fontSize: 10)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
