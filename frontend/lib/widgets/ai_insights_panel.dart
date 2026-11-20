import 'package:flutter/material.dart';
import '../providers/studyflow_provider.dart';
import 'assistant_chat.dart';

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

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.amberAccent;
      case 'low':
        return Colors.tealAccent;
      default:
        return const Color(0xFF818CF8);
    }
  }

  void _openAssistantForInsight(BuildContext context, Map<String, dynamic> insight) {
    final title = insight['title']?.toString() ?? 'ce point';
    final explanation = insight['explanation']?.toString() ?? '';
    final action = insight['action']?.toString() ?? 'Agir';
    final prompt = 'Concernant "${widget.title}" ($title : $explanation), comment dois-je "$action" concrètement ?';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AssistantSheet(
        store: widget.store,
        module: widget.module,
        initialPrompt: prompt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGroq = _insights.any((i) => i['source'] == 'groq-llm');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const CircleAvatar(
          radius: 17,
          backgroundColor: Color(0xFF312E81),
          child: Icon(Icons.auto_awesome, size: 18, color: Color(0xFFC4B5FD)),
        ),
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(
          hasGroq
              ? 'Groq IA + analyse temps réel du module'
              : 'Analyse IA contextuelle · cliquez pour actualiser',
          style: const TextStyle(fontSize: 10),
        ),
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
                label: const Text('Générer les insights IA'),
              ),
            )
          else
            ..._insights.map((insight) {
              final confidence = insight['confidence'] is num
                  ? (insight['confidence'] as num).clamp(0, 1).toDouble()
                  : 0.0;
              final severity = insight['severity']?.toString();
              final sevColor = _severityColor(severity);
              final isLlm = insight['source'] == 'groq-llm';
              final metrics = insight['metrics'] is List
                  ? (insight['metrics'] as List).map((e) => e.toString()).toList()
                  : const <String>[];

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: sevColor, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isLlm) ...[
                          const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFC4B5FD)),
                          const SizedBox(width: 6),
                        ],
                        Expanded(
                          child: Text(
                            insight['title']?.toString() ?? insight['kind']?.toString() ?? 'Insight',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(confidence * 100).round()}%',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sevColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(insight['explanation']?.toString() ?? '', style: const TextStyle(fontSize: 12)),
                    if (metrics.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: metrics
                            .map((m) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(m, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ))
                            .toList(),
                      ),
                    ],
                    if (insight['action'] != null) ...[
                      const SizedBox(height: 8),
                      ActionChip(
                        avatar: const Icon(Icons.assistant, size: 14),
                        label: Text(insight['action'].toString(), style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _openAssistantForInsight(context, insight),
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
