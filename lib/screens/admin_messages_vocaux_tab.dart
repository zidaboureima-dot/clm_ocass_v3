import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/message_vocal_brut_model.dart';
import '../services/message_vocal_service.dart';
import '../theme/app_colors.dart';
import 'traiter_message_vocal_screen.dart';

class AdminMessagesVocauxTab extends StatefulWidget {
  final String adminUid;
  const AdminMessagesVocauxTab({super.key, required this.adminUid});

  @override
  State<AdminMessagesVocauxTab> createState() => _AdminMessagesVocauxTabState();
}

class _AdminMessagesVocauxTabState extends State<AdminMessagesVocauxTab> {
  late Stream<List<MessageVocalBrut>> _stream;
  final _player = AudioPlayer();
  String? _idEnLecture;

  @override
  void initState() {
    super.initState();
    _stream = MessageVocalService().streamMessagesNonTraites();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _ecouter(MessageVocalBrut message) async {
    setState(() => _idEnLecture = message.id);
    try {
      final url = await MessageVocalService().obtenirUrlSignee(message.cheminStockage);
      await _player.play(UrlSource(url));
      _player.onPlayerComplete.first.then((_) {
        if (mounted) setState(() => _idEnLecture = null);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _idEnLecture = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur lecture : $e')));
    }
  }

  String _formatDuree(int secondes) {
    final m = (secondes ~/ 60).toString().padLeft(2, '0');
    final s = (secondes % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MessageVocalBrut>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data!;
        if (messages.isEmpty) {
          return const Center(
            child: Text('Aucun message vocal en attente de traitement.', style: TextStyle(color: AppColors.grisTexte)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final m = messages[index];
            final enLecture = _idEnLecture == m.id;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.bordure)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: AppColors.vertPrimaire.withValues(alpha: 0.15),
                  child: IconButton(
                    icon: Icon(enLecture ? Icons.volume_up : Icons.play_arrow, color: AppColors.vertPrimaire),
                    onPressed: () => _ecouter(m),
                  ),
                ),
                title: Text('Message vocal · ${_formatDuree(m.dureeSecondes ?? 0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Reçu le ${m.createdAt.day}/${m.createdAt.month}/${m.createdAt.year} à ${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}'),
                trailing: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => TraiterMessageVocalScreen(message: m, adminUid: widget.adminUid),
                      ),
                    );
                  },
                  child: const Text('Traiter'),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
