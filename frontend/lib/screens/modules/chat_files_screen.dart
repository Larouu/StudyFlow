import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../core/models/studyflow_models.dart';
import '../../providers/studyflow_provider.dart';
import '../../widgets/ai_insights_panel.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.store});
  final StudyFlowStore store;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl = TextEditingController();

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_msgCtrl.text.trim().isEmpty) return;
    widget.store.sendMessage(_msgCtrl.text);
    _msgCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.currentUser!;
    final messages = widget.store.currentMessages;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AiInsightsPanel(
            store: widget.store,
            module: 'chat',
            title: 'Assistant IA du chat',
          ),
        ),
        Expanded(
          child: messages.isEmpty
              ? const Center(child: Text('Aucun message dans ce canal.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, idx) {
                    final m = messages[idx];
                    final isMe = m.authorId == user.id;
                    final canModerate = user.role == UserRole.owner ||
                        user.role == UserRole.coach;
                    final author = widget.store.users.firstWhere(
                      (u) => u.id == m.authorId,
                      orElse: () => user,
                    );

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 340),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? const Color(0xFF4F46E5)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isMe
                                      ? '${author.name} (Moi)'
                                      : '${author.name} · ${author.role.name.toUpperCase()}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Colors.white70 : Colors.grey,
                                  ),
                                ),
                                if (isMe)
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(left: 6),
                                    iconSize: 14,
                                    tooltip: 'Modifier',
                                    icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                                    onPressed: () => _openEditMessage(context, m),
                                  ),
                                if (isMe || canModerate)
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.only(left: 6),
                                    iconSize: 14,
                                    tooltip: 'Supprimer',
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: isMe ? Colors.white70 : Colors.redAccent,
                                    ),
                                    onPressed: () => widget.store.deleteMessage(m.id),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m.content,
                              style: TextStyle(
                                fontSize: 13,
                                color: isMe ? Colors.white : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Écrire en tant que ${user.name.split(' ').first}...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _send,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Icon(Icons.send, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openEditMessage(BuildContext context, ChatMessageItem m) {
    final ctrl = TextEditingController(text: m.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                widget.store.editMessage(m.id, ctrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.store});
  final StudyFlowStore store;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  String _search = '';
  String _category = 'ALL';
  bool _uploading = false;

  String _fileCategory(FileAssetItem f) {
    final lower = f.name.toLowerCase();
    if (f.mimeType.startsWith('image/') ||
        ['.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg'].any(lower.endsWith)) {
      return 'IMAGE';
    }
    if (['.pdf', '.doc', '.docx', '.txt', '.md'].any(lower.endsWith) ||
        f.mimeType.contains('pdf') ||
        f.mimeType.startsWith('text/')) {
      return 'DOC';
    }
    if (['.xls', '.xlsx', '.csv'].any(lower.endsWith)) {
      return 'SHEET';
    }
    return 'OTHER';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} Mo';
  }

  Future<void> _downloadFile(BuildContext context, FileAssetItem f) async {
    final uri = Uri.tryParse('${widget.store.serverUrl}/api/mobile/files/${f.id}');
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de télécharger le fichier.')),
      );
    }
  }

  Future<void> _createTextNoteDialog(BuildContext context) async {
    final nameCtrl = TextEditingController(text: 'notes-reunion.md');
    final bodyCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Créer une note stockée'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nom du fichier (.md ou .txt)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Contenu',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (created != true) return;
    final fileName = nameCtrl.text.trim().isEmpty ? 'note.txt' : nameCtrl.text.trim();
    final bytes = Uint8List.fromList(utf8.encode(bodyCtrl.text));
    setState(() => _uploading = true);
    final ok = await widget.store.uploadRealFile(name: fileName, bytes: bytes);
    if (mounted) setState(() => _uploading = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Note « $fileName » enregistrée.' : 'Échec de l’enregistrement.')),
      );
    }
  }

  Future<void> _renameFileDialog(BuildContext context, FileAssetItem f) async {
    final ctrl = TextEditingController(text: f.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer le fichier'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Renommer')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await widget.store.renameFile(f.id, ctrl.text.trim());
    }
  }

  Future<void> _uploadNewVersion(BuildContext context, FileAssetItem f) async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 18 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier trop volumineux (max 18 Mo).')),
          );
        }
        return;
      }
      setState(() => _uploading = true);
      final ok = await widget.store.uploadFileVersion(fileId: f.id, bytes: bytes);
      if (mounted) setState(() => _uploading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok ? 'Nouvelle version téléversée pour « ${f.name} ».' : 'Échec du versionnage.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _uploading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sélection : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFiles = widget.store.currentFiles;
    final totalBytes = allFiles.fold<int>(0, (sum, f) => sum + f.size);
    final files = allFiles.where((f) {
      if (_category != 'ALL' && _fileCategory(f) != _category) return false;
      if (_search.trim().isNotEmpty &&
          !f.name.toLowerCase().contains(_search.trim().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: AiInsightsPanel(
            store: widget.store,
            module: 'files',
            title: 'Assistant IA des fichiers',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stockage du projet (${allFiles.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('${_formatSize(totalBytes)} utilisés',
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (widget.store.currentUser?.isCoachOrViewer != true) ...[
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : () => _createTextNoteDialog(context),
                      icon: const Icon(Icons.note_add_outlined, size: 17),
                      label: const Text('Note'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _uploading ? null : () => _pickAndUploadFile(context),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.upload_file, size: 18),
                      label: const Text('Téléverser'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un fichier…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const [
                      ('ALL', 'Tous'),
                      ('DOC', 'Documents'),
                      ('IMAGE', 'Images'),
                      ('SHEET', 'Tableurs'),
                      ('OTHER', 'Autres'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(entry.$2, style: const TextStyle(fontSize: 12)),
                          selected: _category == entry.$1,
                          onSelected: (_) => setState(() => _category = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: files.isEmpty
              ? const Center(child: Text('Aucun fichier correspondant.', style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final f = files[idx];
                    final isImage = f.mimeType.startsWith('image/');
                    final fileUrl = '${widget.store.serverUrl}/api/mobile/files/${f.id}?inline=1';

                    return Card(
                      child: ListTile(
                        onTap: () => _openFilePreview(context, f),
                        leading: isImage
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  fileUrl,
                                  width: 42,
                                  height: 42,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_outlined,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                              )
                            : Icon(
                                f.mimeType.contains('pdf')
                                    ? Icons.picture_as_pdf
                                    : Icons.insert_drive_file_outlined,
                                color: const Color(0xFF4F46E5),
                              ),
                        title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        subtitle: Text(
                          '${_formatSize(f.size)} · ${f.createdAt.day}/${f.createdAt.month}/${f.createdAt.year}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Visualiser',
                              icon: const Icon(Icons.visibility_outlined, size: 18),
                              onPressed: () => _openFilePreview(context, f),
                            ),
                            IconButton(
                              tooltip: 'Télécharger',
                              icon: const Icon(Icons.download_outlined, size: 18),
                              onPressed: () => _downloadFile(context, f),
                            ),
                            if (widget.store.currentUser?.isCoachOrViewer != true)
                              PopupMenuButton<String>(
                                iconSize: 18,
                                onSelected: (action) {
                                  if (action == 'version') _uploadNewVersion(context, f);
                                  if (action == 'rename') _renameFileDialog(context, f);
                                  if (action == 'delete') widget.store.deleteFile(f.id);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'version', child: Text('Nouvelle version')),
                                  PopupMenuItem(value: 'rename', child: Text('Renommer')),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadFile(BuildContext context) async {
    try {
      final picked = await FilePicker.pickFile();
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 18 * 1024 * 1024) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fichier trop volumineux (max 18 Mo).')),
          );
        }
        return;
      }
      setState(() => _uploading = true);
      final ok = await widget.store.uploadRealFile(name: picked.name, bytes: bytes);
      if (mounted) setState(() => _uploading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ok ? 'Fichier « ${picked.name} » téléversé !' : 'Échec du téléversement.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _uploading = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléversement : $e')),
        );
      }
    }
  }

  bool _isTextFile(FileAssetItem f) {
    if (f.mimeType.startsWith('text/')) return true;
    final lower = f.name.toLowerCase();
    const exts = ['.txt', '.md', '.json', '.csv', '.log', '.xml', '.yaml', '.yml', '.dart', '.js', '.ts', '.css', '.html'];
    return exts.any((e) => lower.endsWith(e));
  }

  void _openFilePreview(BuildContext context, FileAssetItem f) {
    final fileUrl = '${widget.store.serverUrl}/api/mobile/files/${f.id}?inline=1';
    final isImage = f.mimeType.startsWith('image/');
    final isText = _isTextFile(f);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Télécharger',
                      icon: const Icon(Icons.download_outlined, size: 20),
                      onPressed: () => _downloadFile(context, f),
                    ),
                    IconButton(
                      tooltip: 'Copier le lien',
                      icon: const Icon(Icons.link, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: fileUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Lien du fichier copié !')),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: isImage
                      ? InteractiveViewer(
                          child: Center(
                            child: Image.network(
                              fileUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) => progress == null
                                  ? child
                                  : const Center(child: CircularProgressIndicator()),
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('Aperçu image indisponible.'),
                              ),
                            ),
                          ),
                        )
                      : isText
                          ? FutureBuilder<http.Response>(
                              future: http.get(Uri.parse(fileUrl)),
                              builder: (_, snap) {
                                if (snap.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }
                                if (snap.hasError || snap.data == null || snap.data!.statusCode != 200) {
                                  return const Center(child: Text('Impossible de charger le contenu texte.'));
                                }
                                final text = utf8.decode(snap.data!.bodyBytes, allowMalformed: true);
                                return SingleChildScrollView(
                                  child: SelectableText(
                                    text,
                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    f.mimeType.contains('pdf')
                                        ? Icons.picture_as_pdf
                                        : Icons.insert_drive_file_outlined,
                                    size: 54,
                                    color: const Color(0xFF4F46E5),
                                  ),
                                  const SizedBox(height: 12),
                                  Text('${_formatSize(f.size)} · ${f.mimeType}'),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () => _downloadFile(context, f),
                                    icon: const Icon(Icons.download_outlined, size: 18),
                                    label: const Text('Télécharger / Ouvrir'),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

