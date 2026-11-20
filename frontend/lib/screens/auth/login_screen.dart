import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../providers/studyflow_provider.dart';
import '../../widgets/studyflow_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.store});
  final StudyFlowStore store;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  bool _createProject = false;
  bool _obscurePass = true;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _inviteTokenCtrl = TextEditingController();
  final _projectNameCtrl = TextEditingController();
  final _projectDescriptionCtrl = TextEditingController();

  String _generateStrongPassword() {
    const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower = 'abcdefghijkmnopqrstuvwxyz';
    const digits = '23456789';
    const symbols = '!@#\$%&*?';
    const all = '$upper$lower$digits$symbols';
    final rng = Random.secure();
    final chars = <String>[
      upper[rng.nextInt(upper.length)],
      lower[rng.nextInt(lower.length)],
      digits[rng.nextInt(digits.length)],
      symbols[rng.nextInt(symbols.length)],
      for (var i = 0; i < 10; i++) all[rng.nextInt(all.length)],
    ]..shuffle(rng);
    return chars.join();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _inviteTokenCtrl.dispose();
    _projectNameCtrl.dispose();
    _projectDescriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isRegisterMode) {
      await widget.store.register(
        _nameCtrl.text,
        _emailCtrl.text,
        _passCtrl.text,
        _createProject ? '' : _inviteTokenCtrl.text,
        projectName: _createProject ? _projectNameCtrl.text : null,
        projectDescription: _createProject ? _projectDescriptionCtrl.text : null,
      );
    } else {
      await widget.store.login(_emailCtrl.text, _passCtrl.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Titre
                  const Center(
                    child: StudyFlowLogo(size: 60),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _isRegisterMode ? 'Créer un compte StudyFlow' : 'Connexion à StudyFlow',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gestion de projets, tâches et coaching collaboratif',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 20),

                  // Formulaire Email / Mot de passe
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.store.statusMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF881337).withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              widget.store.statusMessage!,
                              style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 12),
                            ),
                          ),
                        ],
                        if (_isRegisterMode) ...[
                          TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDeco('Nom complet', Icons.person_outline),
                          ),
                          const SizedBox(height: 12),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Rejoindre'),
                                icon: Icon(Icons.group_add_outlined),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Créer un projet'),
                                icon: Icon(Icons.add_business_outlined),
                              ),
                            ],
                            selected: {_createProject},
                            onSelectionChanged: (values) {
                              setState(() => _createProject = values.first);
                            },
                            showSelectedIcon: false,
                          ),
                          const SizedBox(height: 12),
                          if (_createProject) ...[
                            TextField(
                              controller: _projectNameCtrl,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDeco('Nom du projet', Icons.folder_outlined),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _projectDescriptionCtrl,
                              maxLines: 2,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDeco('Description du projet', Icons.description_outlined),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Le compte créé sera propriétaire de ce projet.',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                            const SizedBox(height: 12),
                          ] else
                            TextField(
                              controller: _inviteTokenCtrl,
                              textCapitalization: TextCapitalization.characters,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                              decoration: _inputDeco('Code d’invitation de l’équipe', Icons.group_add_outlined),
                            ),
                          if (_createProject || _inviteTokenCtrl.text.isNotEmpty)
                            const SizedBox(height: 12),
                        ],
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDeco('Adresse e-mail', Icons.mail_outline),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          obscureText: _obscurePass,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDeco('Mot de passe', Icons.lock_outline).copyWith(
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isRegisterMode)
                                  IconButton(
                                    tooltip: 'Auto-générer un mot de passe',
                                    icon: const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 18),
                                    onPressed: () async {
                                      final generated = _generateStrongPassword();
                                      setState(() {
                                        _passCtrl.text = generated;
                                        _obscurePass = false;
                                      });
                                      await Clipboard.setData(ClipboardData(text: generated));
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Mot de passe généré et copié dans le presse-papiers'),
                                        ),
                                      );
                                    },
                                  ),
                                IconButton(
                                  tooltip: _obscurePass ? 'Afficher' : 'Masquer',
                                  icon: Icon(
                                    _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                    color: const Color(0xFF94A3B8),
                                    size: 18,
                                  ),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: widget.store.isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: widget.store.isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  _isRegisterMode ? 'Créer mon compte' : 'Se connecter',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                          child: Text(
                            _isRegisterMode
                                ? 'Déjà inscrit ? Se connecter'
                                : 'Nouveau sur StudyFlow ? Créer un compte',
                            style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
    );
  }
}

