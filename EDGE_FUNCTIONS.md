# Registre des Edge Functions — CLM-OCASS

Le dashboard Supabase génère des noms automatiques indépendants du rôle réel de
la fonction (cf. doc technique §2.1). Ce registre documente la correspondance
NOM RÉEL DÉPLOYÉ → RÔLE. Toujours appeler une fonction par son nom réel déployé.

| Nom réel déployé | Rôle | Auth appelant | Notes |
|---|---|---|---|
| `clever-service` | Notifications de workflow (webhook → Resend) | header `x-shared-key` | Vuln n°3 fermée : appel authentifié par clé partagée |
| `quick-endpoint` | Création de compte responsable (admin) | JWT admin actif | Doit poser `doit_changer_mdp=true` (à ajouter — forçage n°4) |
| `super-worker` | Passerelle du site vitrine | — | Écrit en service_role → PAS de rate-limit (angle mort noté) |
| `quick-task` | Demande de réinitialisation (utilisateur déconnecté) | aucune (anti-énumération) | Vuln n°4, Modèle 2. Testée et validée |
| *(à créer)* | Traitement du reset (admin déclenche) | JWT admin actif | Vuln n°4 — reste à faire |

## Secrets utilisés (gestionnaire de secrets des fonctions)
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` : injectés automatiquement
- `RESEND_API_KEY` : clé Resend (partagée par clever-service, quick-endpoint, quick-task)
- `CLEVER_SERVICE_KEY` : clé partagée webhook → clever-service (Vuln n°3)

## Code source
Seul `quick-task` est versionné à ce jour (supabase/functions/quick-task/).
À FAIRE : récupérer et versionner clever-service, quick-endpoint, super-worker
depuis le dashboard (dette : Edge Functions non versionnées).
