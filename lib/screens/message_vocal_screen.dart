import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../services/message_vocal_service.dart';
import '../theme/app_colors.dart';

class MessageVocalScreen extends StatefulWidget {
  const MessageVocalScreen({super.key});

  @override
  State<MessageVocalScreen> createState() => _MessageVocalScreenState();
}

class _MessageVocalScreenState extends State<MessageVocalScreen> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  bool _enregistrementEnCours = false;
  bool _lectureEnCours = false;
  bool _envoiEnCours = false;
  String? _cheminFichier;
  int _dureeSecondes = 0;
  DateTime? _debutEnregistrement;

  @override
  void dispose() {
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _demarrer() async {
    final autorise = await _recorder.hasPermission();
    if (!autorise) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Autorisation micro refusée. Activez-la dans les réglages du téléphone.')),
      );
      return;
    }
    final dossier = await getTemporaryDirectory();
    final chemin = '${dossier.path}/message_vocal_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: chemin);
    setState(() {
      _enregistrementEnCours = true;
      _cheminFichier = null;
      _debutEnregistrement = DateTime.now();
    });
  }

  Future<void> _arreter() async {
    final chemin = await _recorder.stop();
    final duree = _debutEnregistrement == null
        ? 0
        : DateTime.now().difference(_debutEnregistrement!).inSeconds;
    setState(() {
      _enregistrementEnCours = false;
      _cheminFichier = chemin;
      _dureeSecondes = duree;
    });
  }

  Future<void> _ecouter() async {
    if (_cheminFichier == null) return;
    setState(() => _lectureEnCours = true);
    await _player.play(DeviceFileSource(_cheminFichier!));
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _lectureEnCours = false);
    });
  }

  void _recommencer() {
    setState(() {
      _cheminFichier = null;
      _dureeSecondes = 0;
    });
  }

  Future<void> _envoyer() async {
    if (_cheminFichier == null) return;
    setState(() => _envoiEnCours = true);
    try {
      await MessageVocalService().uploaderMessageVocal(
        fichier: File(_cheminFichier!),
        dureeSecondes: _dureeSecondes,
      );
      if (!mounted) return;
      _afficherConfirmation();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _envoiEnCours = false);
    }
  }

  void _afficherConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.statusTraite, size: 32),
            SizedBox(width: 12),
            Text('Message envoyé'),
          ],
        ),
        content: const Text(
          'Votre message a bien été reçu et sera écouté rapidement.',
          style: TextStyle(height: 1.5, fontSize: 16),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Retour'),
          ),
        ],
      ),
    );
  }

  String _formatDuree(int secondes) {
    final m = (secondes ~/ 60).toString().padLeft(2, '0');
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Message vocal')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.record_voice_over, size: 64, color: AppColors.vertPrimaire),
              const SizedBox(height: 16),
              const Text(
                'Appuyez sur le micro et parlez',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.vertFonce),
              ),
              const SizedBox(height: 48),
              if (_cheminFichier == null)
                GestureDetector(
                  onTap: _enregistrementEnCours ? _arreter : _demarrer,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _enregistrementEnCours ? AppColors.rouge : AppColors.vertPrimaire,
                    ),
                    child: Icon(
                      _enregistrementEnCours ? Icons.stop : Icons.mic,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    GestureDetector(
                      onTap: _lectureEnCours ? null : _ecouter,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.vertPrimaire,
                        ),
                        child: Icon(
                          _lectureEnCours ? Icons.volume_up : Icons.play_arrow,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_formatDuree(_dureeSecondes), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              const SizedBox(height: 48),
              if (_cheminFichier != null) ...[
                FilledButton.icon(
                  onPressed: _envoiEnCours ? null : _envoyer,
                  icon: _envoiEnCours
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_envoiEnCours ? 'Envoi…' : 'Envoyer'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _envoiEnCours ? null : _recommencer,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recommencer'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
