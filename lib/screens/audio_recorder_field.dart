import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import '../theme/app_colors.dart';

class AudioRecorderField extends StatefulWidget {
  final void Function(File? fichier, int? dureeSecondes) onEnregistrement;

  const AudioRecorderField({super.key, required this.onEnregistrement});

  @override
  State<AudioRecorderField> createState() => _AudioRecorderFieldState();
}

class _AudioRecorderFieldState extends State<AudioRecorderField> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  bool _enregistrementEnCours = false;
  bool _lectureEnCours = false;
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
    final chemin = '${dossier.path}/signalement_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
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
    if (chemin != null) {
      widget.onEnregistrement(File(chemin), duree);
    }
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
    widget.onEnregistrement(null, null);
  }

  String _formatDuree(int secondes) {
    final m = (secondes ~/ 60).toString().padLeft(2, '0');
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.grisLeger,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Message vocal (optionnel)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          const Text(
            'Utile si vous préférez expliquer les faits à voix haute plutôt que par écrit.',
            style: TextStyle(fontSize: 11, color: AppColors.grisTexte),
          ),
          const SizedBox(height: 10),
          if (_cheminFichier == null)
            Row(
              children: [
                IconButton.filled(
                  onPressed: _enregistrementEnCours ? _arreter : _demarrer,
                  style: IconButton.styleFrom(
                    backgroundColor: _enregistrementEnCours ? AppColors.rouge : AppColors.vertPrimaire,
                  ),
                  icon: Icon(_enregistrementEnCours ? Icons.stop : Icons.mic),
                ),
                const SizedBox(width: 10),
                Text(
                  _enregistrementEnCours ? 'Enregistrement en cours…' : 'Appuyez pour enregistrer',
                  style: const TextStyle(fontSize: 13, color: AppColors.grisTexte),
                ),
              ],
            )
          else
            Row(
              children: [
                IconButton.filled(
                  onPressed: _lectureEnCours ? null : _ecouter,
                  style: IconButton.styleFrom(backgroundColor: AppColors.vertPrimaire),
                  icon: Icon(_lectureEnCours ? Icons.volume_up : Icons.play_arrow),
                ),
                const SizedBox(width: 10),
                Text(_formatDuree(_dureeSecondes), style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _recommencer,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Recommencer'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
