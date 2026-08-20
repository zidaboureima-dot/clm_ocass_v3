// =====================================================================
// Edge Function : rapport-periodique
//
// Produit une synthèse périodique des signalements et des actions menées,
// assistée par un modèle de langage (Mistral). Voir CADRAGE_RAPPORT_LLM.md.
//
// ORDRE DES OPÉRATIONS — NE PAS RÉORGANISER
//   1. Vérifier que la fonctionnalité est ACTIVE pour ce pays.
//   2. Extraire les données de la période.
//   3. MINIMISER.
//   4. Seulement alors, appeler le prestataire.
//   5. Enregistrer le rapport en BROUILLON, jamais diffusé directement.
//
//   Chaque étape est un préalable à la suivante. Déplacer l'appel au
//   prestataire avant la minimisation, ou l'insertion avant la vérification
//   du drapeau, revient à supprimer le garde-fou correspondant.
//
// CE QUE CETTE FONCTION NE FAIT PAS, DÉLIBÉRÉMENT
//   Elle n'envoie RIEN à personne. Le rapport est enregistré en statut
//   'brouillon' et attend une validation humaine explicite. La diffusion aux
//   autorités sanitaires est un acte engageant : un modèle peut
//   sur-interpréter un cas isolé ou formuler une causalité que les données
//   ne soutiennent pas. Cette responsabilité ne se délègue pas.
//
// VARIABLES D'ENVIRONNEMENT
//   MISTRAL_API_KEY      clé du prestataire
//   RAPPORT_CRON_KEY     clé partagée protégeant l'appel de cette fonction
//   PAYS_CODE            pays de ce déploiement (défaut : GN)
// =====================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { construirePayload, traceTransmission } from '../_shared/minimisation.ts';
import { exigerRapportLlmActif } from '../_shared/config_pays.ts';
import { ACTIONS_DEMO, SIGNALEMENTS_DEMO } from './demonstration.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const MISTRAL_API_KEY = Deno.env.get('MISTRAL_API_KEY') ?? '';
const RAPPORT_CRON_KEY = Deno.env.get('RAPPORT_CRON_KEY') ?? '';
const PAYS_CODE = Deno.env.get('PAYS_CODE') ?? 'GN';

const MODELE = 'mistral-large-latest';

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, x-cron-key',
};

const reponse = (corps: unknown, statut = 200) =>
  new Response(JSON.stringify(corps), {
    status: statut,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });

// ---------------------------------------------------------------------
// L'invite.
//
// Les interdictions y sont explicites plutôt que sous-entendues. Deux
// d'entre elles portent des engagements pris ailleurs :
//
//   - ne citer aucune fonction individuelle : contrepartie du maintien du
//     nom de l'établissement dans le périmètre transmis (cadrage §5.1).
//     Sans elle, « le médecin-chef du CSI camp » désigne une personne.
//   - ne rien reproduire verbatim : le rapport est destiné à sortir du
//     dispositif, les descriptions non.
//
// Rappel sur la portée : une consigne n'est pas une garantie technique. Elle
// réduit la fréquence du problème ; c'est la relecture humaine qui l'arrête.
// ---------------------------------------------------------------------
function construireInvite(
  libellePays: string,
  debut: string,
  fin: string,
  donnees: unknown,
): string {
  return `Tu rédiges une synthèse périodique pour CLM-OCASS ${libellePays}, un dispositif de suivi des services de santé dirigé par les communautés.

PÉRIODE : du ${debut} au ${fin}.

RÈGLES IMPÉRATIVES
1. Ne cite JAMAIS une fonction ou un rôle individuel ("le médecin-chef", "l'infirmière de garde", "le gestionnaire du stock"). Parle d'établissements et de dysfonctionnements, jamais de personnes.
2. Ne reproduis AUCUNE description mot pour mot. Synthétise toujours.
3. N'affirme que ce que les données soutiennent. Si une tendance est incertaine, dis-le. N'invente aucune causalité.
4. Si les données sont trop peu nombreuses pour conclure, écris-le plutôt que de meubler.
5. QUI SIGNALE : les signalements émanent d'usagers des services de santé, jamais des établissements eux-mêmes. N'écris donc JAMAIS "le centre X a signalé" — écris "un dysfonctionnement a été signalé au centre X", "le centre X fait l'objet de N signalements". L'établissement est ce dont on parle, pas celui qui parle. Inverser les deux dénature le dispositif.

STRUCTURE ATTENDUE
- Vue d'ensemble : volume, répartition par zone géographique et par catégorie.
- Ce qui ressort : les dysfonctionnements récurrents, les établissements ou zones qui concentrent les signalements.
- Suites données : ce qui a été entrepris, ce qui a abouti, ce qui est resté sans réponse.
- Points d'attention : ce qui mérite une action de plaidoyer, avec sa justification.

TON : factuel, sobre, destiné à des autorités sanitaires. Pas de superlatifs.

DONNÉES (JSON) :
${JSON.stringify(donnees, null, 2)}`;
}

async function appelerMistral(invite: string): Promise<string> {
  const res = await fetch('https://api.mistral.ai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${MISTRAL_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: MODELE,
      messages: [{ role: 'user', content: invite }],
      temperature: 0.2,
    }),
  });

  if (!res.ok) {
    // On ne journalise ni l'invite ni la réponse : elles contiennent les
    // données transmises. Seuls le code et le message d'erreur remontent.
    const detail = await res.text();
    throw new Error(`Appel Mistral en échec (${res.status}) : ${detail.slice(0, 300)}`);
  }

  const json = await res.json();
  const contenu = json?.choices?.[0]?.message?.content;
  if (!contenu) throw new Error('Réponse Mistral vide ou inattendue.');
  return contenu;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS });

  // Clé partagée : cette fonction est déclenchée par planification, jamais
  // par un utilisateur. On ne journalise pas la clé, seulement l'échec.
  if (!RAPPORT_CRON_KEY || req.headers.get('x-cron-key') !== RAPPORT_CRON_KEY) {
    console.warn('rapport-periodique : requête rejetée (clé absente ou invalide).');
    return reponse({ ok: false, error: 'Clé invalide' }, 401);
  }

  try {
    const url = new URL(req.url);

    // --- MODE DÉMONSTRATION ---------------------------------------------
    // Produit un rapport spécimen à partir d'un jeu de données FABRIQUÉ,
    // pour présenter le dispositif sans exposer de signalements réels.
    //
    // Il ne lit rien et n'écrit rien en base : il n'a donc accès à aucune
    // donnée réelle, et ne contourne pas le drapeau `rapport_llm_actif` —
    // celui-ci protège le traitement de données réelles, ce que ce mode ne
    // fait pas. Le rapport produit n'est pas enregistré.
    const modeDemo = url.searchParams.get('demo') === '1';

    if (!MISTRAL_API_KEY) {
      return reponse({ ok: false, error: 'MISTRAL_API_KEY non configurée.' }, 500);
    }

    if (modeDemo) {
      const payloadDemo = construirePayload(SIGNALEMENTS_DEMO as never, ACTIONS_DEMO as never);
      const inviteDemo = construireInvite(
        'Guinée',
        '2026-07-01',
        '2026-07-31',
        payloadDemo,
      );
      const contenuDemo = await appelerMistral(inviteDemo);
      return reponse({
        ok: true,
        mode: 'demonstration',
        contenu: contenuDemo,
        trace: traceTransmission(payloadDemo),
        avertissement:
          'Rapport produit à partir de données FABRIQUÉES, à des fins de présentation. '
          + 'Aucun signalement réel n\'a été lu ni transmis. Non enregistré en base.',
      });
    }

    // --- 1. La fonctionnalité est-elle autorisée pour ce pays ? ---------
    // AVANT toute extraction : inutile de sortir des données de la base pour
    // découvrir ensuite qu'on n'avait pas le droit de les traiter.
    const config = await exigerRapportLlmActif(supabase, PAYS_CODE);

    // --- 2. Période : le mois écoulé, ou celle passée en paramètre -------
    const finParam = url.searchParams.get('fin');
    const debutParam = url.searchParams.get('debut');

    const fin = finParam ? new Date(finParam) : new Date();
    const debut = debutParam
      ? new Date(debutParam)
      : new Date(Date.UTC(fin.getUTCFullYear(), fin.getUTCMonth() - 1, fin.getUTCDate()));

    if (!(debut < fin)) {
      return reponse({ ok: false, error: 'Période invalide : début doit précéder fin.' }, 400);
    }

    // --- 3. Extraction --------------------------------------------------
    const { data: signalements, error: errSig } = await supabase
      .from('signalements')
      .select('id, region, prefecture, centre_sante, groupe, categorie_libelle, nature, statut, description, soumis_le')
      .gte('soumis_le', debut.toISOString())
      .lt('soumis_le', fin.toISOString());
    if (errSig) throw new Error(`Extraction signalements : ${errSig.message}`);

    if (!signalements || signalements.length === 0) {
      return reponse({ ok: true, message: 'Aucun signalement sur la période, aucun rapport produit.' });
    }

    const ids = signalements.map((s) => s.id);
    const { data: actions, error: errAct } = await supabase
      .from('actions_menees')
      .select('signalement_id, auteur_uid, role_auteur, type_action, description, resultat, created_at')
      .in('signalement_id', ids);
    if (errAct) throw new Error(`Extraction actions : ${errAct.message}`);

    // --- 4. MINIMISATION ------------------------------------------------
    // Rien ne doit sortir de la base sans passer par ici. C'est cet appel,
    // et lui seul, qui rend licite l'étape suivante.
    const payload = construirePayload(signalements as never, (actions ?? []) as never);
    const trace = traceTransmission(payload);

    // --- 5. Appel au prestataire ----------------------------------------
    const invite = construireInvite(
      config.libelle_pays,
      debut.toISOString().slice(0, 10),
      fin.toISOString().slice(0, 10),
      payload,
    );
    const contenu = await appelerMistral(invite);

    // --- 6. Enregistrement en BROUILLON ---------------------------------
    // Le trigger trg_verifier_rapport_llm_autorise revérifie ici le drapeau :
    // seconde barrière, au cas où cette fonction serait un jour contournée.
    const { data: rapport, error: errIns } = await supabase
      .from('rapports_periodiques')
      .insert({
        pays_code: PAYS_CODE,
        periode_debut: debut.toISOString().slice(0, 10),
        periode_fin: fin.toISOString().slice(0, 10),
        contenu,
        statut: 'brouillon',
        modele_utilise: MODELE,
        trace,
      })
      .select('id')
      .single();
    if (errIns) throw new Error(`Enregistrement du rapport : ${errIns.message}`);

    // Aucun envoi ici. La diffusion suppose une validation humaine.
    return reponse({
      ok: true,
      rapport_id: rapport.id,
      statut: 'brouillon',
      trace,
      message: 'Rapport produit en brouillon. Il doit être relu et validé avant toute diffusion.',
    });
  } catch (e) {
    console.error('rapport-periodique : échec —', (e as Error).message);
    return reponse({ ok: false, error: (e as Error).message }, 500);
  }
});
