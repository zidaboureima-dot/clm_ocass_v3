// =====================================================================
// Étage de minimisation — CLM-OCASS
//
// RÔLE
//   Nettoyer tout texte AVANT qu'il ne soit transmis à un prestataire tiers
//   (modèle de langage produisant le rapport périodique). Retire les
//   identifiants structurés : numéros de téléphone, adresses email, liens,
//   longues suites de chiffres.
//
// STATUT : PRÉREQUIS BLOQUANT
//   Le cadrage (CADRAGE_RAPPORT_LLM.md §4) conditionne l'inclusion des
//   descriptions citoyennes dans le périmètre du rapport à l'existence et au
//   test de cet étage. Aucun appel à un modèle ne doit être écrit sans passer
//   par `minimiserTexte`.
//
// CE QUE CET ÉTAGE NE FAIT PAS — À LIRE ABSOLUMENT
//   Il retire des identifiants de FORME reconnaissable. Il ne peut pas, et ne
//   prétend pas, retirer une identification par le CONTEXTE. Une phrase comme
//   « l'infirmière de garde mardi soir m'a renvoyée » ne contient aucun motif
//   détectable et passera intacte, alors qu'elle désigne une personne.
//
//   Cette limite est structurelle, pas un défaut d'implémentation : aucune
//   expression régulière ne la couvrira jamais. Elle est compensée ailleurs,
//   et ces compensations ne sont pas optionnelles :
//     - le rapport diffusé à l'extérieur est AGRÉGÉ, jamais verbatim ;
//     - un responsable RELIT et VALIDE avant toute diffusion externe.
//   Retirer l'une de ces deux compensations rouvre le risque en entier.
//
// ARBITRAGE ASSUMÉ
//   En cas de doute, on sur-nettoie. Une suite comme « 12 24 36 48 » sera
//   retirée alors qu'elle désigne peut-être des quantités. Perdre un chiffre
//   dans un rapport est sans gravité ; laisser fuir un numéro ne l'est pas.
//
// TESTÉ
//   Voir minimisation.test.ts — dates, montants, formats guinéens (+224) et
//   burkinabè (+226), locaux et internationaux.
// =====================================================================

const RE_EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/g;
const RE_URL = /https?:\/\/\S+/gi;

/** Numéro international : +224 621 42 67 91, +226 76 41 09 90… */
const RE_TEL_INTL = /\+\d[\d\s.\-()]{6,}\d/g;

/** Numéro local en quatre groupes : 76 41 09 90, 76.41.09.90, 76-41-09-90… */
const RE_TEL_LOCAL = /\b\d{2}[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2,4}\b/g;

/** Suite longue : matricule, numéro de dossier, téléphone collé. */
const RE_ID_LONG = /\b\d{6,}\b/g;

export const MARQUEUR_EMAIL = '[email retiré]';
export const MARQUEUR_URL = '[lien retiré]';
export const MARQUEUR_TEL = '[numéro retiré]';
export const MARQUEUR_ID = '[identifiant retiré]';

/**
 * Vrai si le motif est en réalité une date (jj mm aaaa) et non un numéro.
 *
 * Sans ce contrôle, « réunion du 15 08 2026 » perdrait sa date : huit
 * chiffres en quatre groupes, indiscernables d'un numéro par la seule forme.
 * Or les dates portent le sens temporel du rapport — les perdre le viderait.
 */
function ressembleADate(motif: string): boolean {
  const chiffres = motif.replace(/[^\d]/g, '');
  if (chiffres.length !== 8) return false;
  const jour = Number(chiffres.slice(0, 2));
  const mois = Number(chiffres.slice(2, 4));
  const annee = Number(chiffres.slice(4, 8));
  return (
    jour >= 1 && jour <= 31 &&
    mois >= 1 && mois <= 12 &&
    annee >= 1900 && annee <= 2099
  );
}

/**
 * Retire d'un texte libre les identifiants de forme reconnaissable.
 *
 * Les marqueurs remplacent plutôt qu'ils ne suppriment : le modèle voit
 * qu'une information a été retirée, ce qui vaut mieux qu'une phrase amputée
 * qu'il pourrait mal interpréter. C'est aussi vérifiable à la relecture.
 */
export function minimiserTexte(texte: string | null | undefined): string {
  if (!texte) return '';
  return texte
    .replace(RE_EMAIL, MARQUEUR_EMAIL)
    .replace(RE_URL, MARQUEUR_URL)
    .replace(RE_TEL_INTL, MARQUEUR_TEL)
    .replace(RE_TEL_LOCAL, (m) => (ressembleADate(m) ? m : MARQUEUR_TEL))
    .replace(RE_ID_LONG, MARQUEUR_ID);
}

/** Signalement tel qu'extrait de la base, avant minimisation. */
export interface SignalementBrut {
  id: string;
  region: string;
  prefecture: string;
  centre_sante: string;
  groupe: string;
  categorie_libelle: string;
  nature: string;
  statut: string;
  description: string;
  soumis_le: string;
}

/** Action menée telle qu'extraite de la base, avant minimisation. */
export interface ActionBrute {
  signalement_id: string;
  auteur_uid: string;
  role_auteur: string;
  type_action: string;
  description: string;
  resultat: string;
  created_at: string;
}

/** Signalement prêt à être transmis. Noter l'absence d'identifiant de cas. */
export interface SignalementMinimise {
  region: string;
  prefecture: string;
  centre_sante: string;
  groupe: string;
  categorie: string;
  gravite: string;
  statut: string;
  description: string;
  soumis_le: string;
  actions: ActionMinimisee[];
}

/** Action prête à être transmise. Noter l'absence d'auteur_uid. */
export interface ActionMinimisee {
  role_auteur: string;
  type_action: string;
  description: string;
  resultat: string;
  date: string;
}

/**
 * Construit la charge utile transmise au modèle.
 *
 * Deux minimisations distinctes s'appliquent ici :
 *
 *   1. TEXTUELLE — `minimiserTexte` sur chaque champ libre.
 *   2. STRUCTURELLE — on ne recopie QUE les champs utiles au rapport.
 *      Disparaissent notamment :
 *        - `auteur_uid` : seul le RÔLE est transmis (« un point focal »),
 *          jamais l'identité de l'agent ;
 *        - l'identifiant du signalement : le modèle produit une synthèse,
 *          il n'a aucun besoin de pouvoir désigner un cas précis.
 *
 * La seconde minimisation est la plus efficace des deux, et la moins
 * coûteuse : ce qui n'est pas recopié ne peut pas fuir. Toute évolution qui
 * ajouterait un champ ici doit se demander d'abord s'il est nécessaire au
 * rapport — la réponse par défaut étant non.
 */
export function construirePayload(
  signalements: SignalementBrut[],
  actions: ActionBrute[],
): SignalementMinimise[] {
  const actionsParCas = new Map<string, ActionBrute[]>();
  for (const a of actions) {
    const liste = actionsParCas.get(a.signalement_id) ?? [];
    liste.push(a);
    actionsParCas.set(a.signalement_id, liste);
  }

  return signalements.map((s) => ({
    region: s.region,
    prefecture: s.prefecture,
    centre_sante: s.centre_sante,
    groupe: s.groupe,
    categorie: s.categorie_libelle,
    gravite: s.nature,
    statut: s.statut,
    description: minimiserTexte(s.description),
    soumis_le: s.soumis_le,
    actions: (actionsParCas.get(s.id) ?? []).map((a) => ({
      role_auteur: a.role_auteur,
      type_action: a.type_action,
      description: minimiserTexte(a.description),
      resultat: a.resultat,
      date: a.created_at,
    })),
  }));
}

/**
 * Trace de ce qui a été transmis, à journaliser (cadrage §5).
 *
 * Volumes et compteurs uniquement : le CONTENU transmis n'est jamais
 * recopié dans les journaux. Journaliser le contenu reviendrait à créer une
 * seconde copie des données que l'on cherche précisément à protéger.
 */
export function traceTransmission(payload: SignalementMinimise[]) {
  const nbActions = payload.reduce((n, s) => n + s.actions.length, 0);
  const caracteres = JSON.stringify(payload).length;
  return {
    nb_signalements: payload.length,
    nb_actions: nbActions,
    taille_caracteres: caracteres,
  };
}
