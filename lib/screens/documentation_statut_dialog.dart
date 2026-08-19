import 'package:flutter/material.dart';
import '../models/action_menee_model.dart';
import '../theme/app_colors.dart';

/// Résultat de la saisie de documentation exigée avant un changement de
/// statut. `null` si l'utilisateur annule.
class DocumentationSaisie {
  final String typeAction;
  final String description;
  final String resultat;

  const DocumentationSaisie({
    required this.typeAction,
    required this.description,
    required this.resultat,
  });
}

/// Dialogue de documentation obligatoire, affiché avant une transition de
/// statut. Deux variantes :
///
///   - `synthese: false` — le superviseur documente l'action menée avant de
///     marquer le cas « traité » (type de démarche, description, résultat).
///   - `synthese: true`  — l'admin rédige la note de synthèse avant de
///     clôturer le cas.
///
/// L'avertissement sur la destination du texte n'est pas décoratif : sans
/// lui, la distinction entre cet espace et celui des annotations ne tiendrait
/// pas à l'usage, et le garde-fou du rapport périodique perdrait son sens
/// (voir CADRAGE_RAPPORT_LLM.md).
class DocumentationStatutDialog extends StatefulWidget {
  final bool synthese;

  const DocumentationStatutDialog({super.key, required this.synthese});

  static Future<DocumentationSaisie?> afficher(
    BuildContext context, {
    required bool synthese,
  }) {
    return showDialog<DocumentationSaisie>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DocumentationStatutDialog(synthese: synthese),
    );
  }

  @override
  State<DocumentationStatutDialog> createState() => _DocumentationStatutDialogState();
}

class _DocumentationStatutDialogState extends State<DocumentationStatutDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  String _typeAction = ActionMenee.typeSaisine;
  String _resultat = ActionMenee.resultatEnAttente;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _valider() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.of(context).pop(
      DocumentationSaisie(
        typeAction: widget.synthese ? ActionMenee.typeSynthese : _typeAction,
        description: _descriptionController.text.trim(),
        resultat: widget.synthese ? ActionMenee.resultatObtenu : _resultat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final synthese = widget.synthese;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(synthese ? 'Note de synthèse' : 'Action menée'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.vertTresClair,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  synthese
                      ? 'Cette synthèse conclut le cas. Elle pourra figurer '
                        'dans un rapport transmis aux autorités sanitaires : '
                        'restez factuel, et n\'y consignez pas d\'échange interne.'
                      : 'Décrivez ce qui a été entrepris sur ce cas. Ce texte '
                        'pourra figurer dans un rapport transmis aux autorités '
                        'sanitaires — contrairement aux annotations, qui '
                        'restent internes.',
                  style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.grisTexte),
                ),
              ),
              const SizedBox(height: 16),
              if (!synthese) ...[
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _typeAction,
                  decoration: const InputDecoration(labelText: 'Type de démarche'),
                  items: ActionMenee.typesDemarche
                      .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              ActionMenee.libellesTypes[t]!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _typeAction = v ?? _typeAction),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: synthese
                      ? 'Synthèse du traitement du cas'
                      : 'Ce qui a été fait',
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().length < 10)
                    ? 'Décrivez en quelques mots (10 caractères minimum)'
                    : null,
              ),
              if (!synthese) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _resultat,
                  decoration: const InputDecoration(labelText: 'Résultat à ce jour'),
                  items: ActionMenee.resultats
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(
                              ActionMenee.libellesResultats[r]!,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _resultat = v ?? _resultat),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _valider,
          child: Text(synthese ? 'Enregistrer et clôturer' : 'Enregistrer et marquer traité'),
        ),
      ],
    );
  }
}
