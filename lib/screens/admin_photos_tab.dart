import 'package:flutter/material.dart';
import '../models/photo_brute_model.dart';
import '../services/photo_brute_service.dart';
import '../theme/app_colors.dart';
import 'traiter_photo_screen.dart';

class AdminPhotosTab extends StatefulWidget {
  final String adminUid;
  const AdminPhotosTab({super.key, required this.adminUid});

  @override
  State<AdminPhotosTab> createState() => _AdminPhotosTabState();
}

class _AdminPhotosTabState extends State<AdminPhotosTab> {
  late Stream<List<PhotoBrute>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = PhotoBruteService().streamPhotosNonTraitees();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PhotoBrute>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final photos = snapshot.data!;
        if (photos.isEmpty) {
          return const Center(
            child: Text('Aucune photo en attente de traitement.', style: TextStyle(color: AppColors.grisTexte)),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final p = photos[index];
            return _CartePhoto(photo: p, adminUid: widget.adminUid);
          },
        );
      },
    );
  }
}

class _CartePhoto extends StatefulWidget {
  final PhotoBrute photo;
  final String adminUid;
  const _CartePhoto({required this.photo, required this.adminUid});

  @override
  State<_CartePhoto> createState() => _CartePhotoState();
}

class _CartePhotoState extends State<_CartePhoto> {
  String? _url;

  @override
  void initState() {
    super.initState();
    PhotoBruteService().obtenirUrlSignee(widget.photo.cheminStockage).then((u) {
      if (mounted) setState(() => _url = u);
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TraiterPhotoScreen(photo: widget.photo, adminUid: widget.adminUid),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.bordure),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Expanded(
              child: _url == null
                  ? const Center(child: CircularProgressIndicator())
                  : Image.network(_url!, fit: BoxFit.cover, width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${widget.photo.createdAt.day}/${widget.photo.createdAt.month} ${widget.photo.createdAt.hour}:${widget.photo.createdAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: AppColors.grisTexte),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 16, color: AppColors.vertPrimaire),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
