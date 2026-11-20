import 'package:flutter/material.dart';
import '../providers/studyflow_provider.dart';
import '../services/assistant/assistant_api_service.dart';

/// Bouton flottant ouvrant l'assistant d'aide dans une feuille modale.
class AssistantFab extends StatelessWidget {
  const AssistantFab({super.key, required this.store});
  final StudyFlowStore store;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'assistant-fab',
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => AssistantSheet(store: store),
      ),
      icon: const Icon(Icons.support_agent),
      label: const Text('Aide'),
    );
  }
}

class AssistantSheet extends StatefulWidget {
  const AssistantSheet({
    super.key,
    required this.store,
    this.module,
    this.initialPrompt,
  });
  final StudyFlowStore store;
  final String? module;
  final String? initialPrompt;

  @override
  State<AssistantSheet> createState() => _AssistantSheetState();
}

class _AssistantSheetState extends State<AssistantSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic> _status = const {};
  final List<AssistantMessage> _messages = [
    const AssistantMessage(
      role: 'assistant',
      content: 'Bonjour ! Je peux vous aider à utiliser StudyFlow : tâches, Kanban, équipes, fichiers, formations, coaching. Que souhaitez-vous faire ?',
    ),
  ];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.store.assistantStatus().then((status) {
      if (mounted) setState(() => _status = status);
    });
    if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _send(widget.initialPrompt);
      });
    }
  }

  List<String> get _suggestions {
    switch (widget.module) {
      case 'kanban':
        return const [
          'Comment débloquer une colonne WIP ?',
          'Quelles cartes sont en retard ?',
          'Comment déplacer une tâche ?',
        ];
      case 'tasks':
        return const [
          'Quelles sont mes 3 priorités ?',
          'Quelles tâches sont en retard ?',
          'Comment découper une tâche avec l’IA ?',
        ];
      case 'teams':
        return const [
          'Comment inviter un membre ?',
          'Quel est mon rôle dans StudyFlow ?',
          'Quelles permissions a un coach ?',
        ];
      case 'calendar':
        return const [
          'Quelles sont mes prochaines échéances ?',
          'Comment ajouter un jalon ?',
          'Comment exporter un rapport ?',
        ];
      case 'files':
      case 'chat':
        return const [
          'Comment versionner un fichier ?',
          'Quels fichiers sont partagés ?',
          'Résume l’activité récente',
        ];
      case 'coaching':
        return const [
          'Quelle formation me convient ?',
          'Comment demander un coaching ?',
          'Quand est ma prochaine séance ?',
        ];
      default:
        return const [
          'Quelles sont mes 3 priorités ?',
          'Quelles sont mes échéances ?',
          'Comment demander un coaching ?',
        ];
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    final user = widget.store.currentUser;
    if (text.isEmpty || _loading || user == null) return;

    // Historique envoyé au serveur = messages précédents (sans le message d'accueil).
    final history = _messages.skip(1).toList();
    setState(() {
      _messages.add(AssistantMessage(role: 'user', content: text));
      _loading = true;
    });
    _ctrl.clear();
    _scrollDown();

    final reply = await widget.store.askAssistant(text, history: history, module: widget.module);
    if (!mounted) return;
    setState(() {
      _messages.add(AssistantMessage(role: 'assistant', content: reply));
      _loading = false;
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.support_agent)),
              title: const Text('Assistant StudyFlow', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                _status['provider'] == 'groq'
                    ? 'Assistant Groq actif · ne modifie aucune donnée'
                    : 'Mode aide locale · ne modifie aucune donnée',
              ),
              trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_loading ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i == _messages.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  }
                  final m = _messages[i];
                  final isMe = m.role == 'user';
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? const Color(0xFF4F46E5) : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SelectableText(
                        m.content,
                        style: TextStyle(color: isMe ? Colors.white : scheme.onSurface),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_messages.length == 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final s in _suggestions)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(label: Text(s), onPressed: () => _send(s)),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Posez votre question…',
                        border: OutlineInputBorder(),
                        counterText: '',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _loading ? null : _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
