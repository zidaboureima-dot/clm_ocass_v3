// =====================================================================
// Tests de l'étage de minimisation.
//
// EXÉCUTION (depuis la racine du dépôt) :
//   deno test supabase/functions/_shared/minimisation.test.ts
//
// POURQUOI CES TESTS EXISTENT
//   Une expression régulière trop gourmande abîme le rapport en silence ;
//   une expression trop timide laisse fuir un identifiant. Les deux erreurs
//   sont invisibles à l'œil nu sur un corpus réel. Ces tests fixent le
//   comportement attendu dans les deux directions : ce qui DOIT être retiré,
//   et ce qui doit rester INTACT.
//
//   Les cas « intacts » sont aussi importants que les autres : ce sont eux
//   qui ont fait corriger la détection des dates pendant l'écriture.
// =====================================================================

import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts';
import {
  construirePayload,
  MARQUEUR_EMAIL,
  MARQUEUR_ID,
  MARQUEUR_TEL,
  MARQUEUR_URL,
  minimiserTexte,
  traceTransmission,
} from './minimisation.ts';

// ---------------------------------------------------------------------
// Ce qui DOIT être retiré
// ---------------------------------------------------------------------

Deno.test('retire un numéro international guinéen', () => {
  assertEquals(
    minimiserTexte('Appelez-moi au +224 621 42 67 91 svp'),
    `Appelez-moi au ${MARQUEUR_TEL} svp`,
  );
});

Deno.test('retire un numéro international burkinabè', () => {
  assertEquals(
    minimiserTexte('Contact : +226 76 41 09 90'),
    `Contact : ${MARQUEUR_TEL}`,
  );
});

Deno.test('retire un numéro local séparé par des espaces', () => {
  assertEquals(
    minimiserTexte('joindre au 76 41 09 90 rapidement'),
    `joindre au ${MARQUEUR_TEL} rapidement`,
  );
});

Deno.test('retire un numéro local séparé par des points', () => {
  assertEquals(minimiserTexte('tel: 76.41.09.90'), `tel: ${MARQUEUR_TEL}`);
});

Deno.test('retire une adresse email', () => {
  assertEquals(
    minimiserTexte('mon mail zida@example.com merci'),
    `mon mail ${MARQUEUR_EMAIL} merci`,
  );
});

Deno.test('retire un lien', () => {
  assertEquals(
    minimiserTexte('voir https://exemple.org/page infos'),
    `voir ${MARQUEUR_URL} infos`,
  );
});

Deno.test('retire une longue suite de chiffres (matricule)', () => {
  assertEquals(
    minimiserTexte('Matricule 1234567 de l\'agent'),
    `Matricule ${MARQUEUR_ID} de l'agent`,
  );
});

// ---------------------------------------------------------------------
// Ce qui doit rester INTACT
// ---------------------------------------------------------------------

Deno.test('préserve une date en jj/mm/aaaa', () => {
  const t = 'Le 12/08/2026 a 14h30, rupture constatée';
  assertEquals(minimiserTexte(t), t);
});

Deno.test('préserve une date séparée par des espaces', () => {
  const t = 'réunion du 15 08 2026 au centre';
  assertEquals(minimiserTexte(t), t);
});

Deno.test('préserve une date séparée par des tirets', () => {
  const t = 'constaté le 01-09-2026 sur place';
  assertEquals(minimiserTexte(t), t);
});

Deno.test('préserve les petits nombres', () => {
  const t = 'Rupture depuis 3 mois dans 2 centres';
  assertEquals(minimiserTexte(t), t);
});

Deno.test('préserve un montant espacé', () => {
  const t = 'coût estimé 1 000 000 GNF';
  assertEquals(minimiserTexte(t), t);
});

Deno.test('préserve un texte sans identifiant', () => {
  const t = 'Équipements pour les examens virologiques en panne depuis 1 mois';
  assertEquals(minimiserTexte(t), t);
});

Deno.test('tolère null et chaîne vide', () => {
  assertEquals(minimiserTexte(null), '');
  assertEquals(minimiserTexte(undefined), '');
  assertEquals(minimiserTexte(''), '');
});

// ---------------------------------------------------------------------
// Minimisation structurelle : ce qui ne doit PAS sortir de la base
// ---------------------------------------------------------------------

const signalement = {
  id: 'sig-123',
  region: 'Conakry',
  prefecture: 'Lambanyi',
  centre_sante: 'CSI camp',
  groupe: 'Infrastructure, Équipement et Hygiène',
  categorie_libelle: 'Pannes d\'équipement',
  nature: 'normal',
  statut: 'traite',
  description: 'Panne depuis 1 mois, joindre le 76 41 09 90',
  soumis_le: '2026-08-01T10:00:00Z',
};

const action = {
  signalement_id: 'sig-123',
  auteur_uid: 'uid-secret-de-l-agent',
  role_auteur: 'point_focal',
  type_action: 'saisine',
  description: 'Saisine du chef de centre, contact zida@example.com',
  resultat: 'en_attente',
  created_at: '2026-08-05T09:00:00Z',
};

Deno.test('le payload ne contient ni auteur_uid ni identifiant de cas', () => {
  const payload = construirePayload([signalement], [action]);
  const brut = JSON.stringify(payload);
  assertEquals(brut.includes('uid-secret-de-l-agent'), false);
  assertEquals(brut.includes('sig-123'), false);
});

Deno.test('le payload conserve le rôle de l\'auteur', () => {
  const payload = construirePayload([signalement], [action]);
  assertEquals(payload[0].actions[0].role_auteur, 'point_focal');
});

Deno.test('le payload minimise les textes libres', () => {
  const payload = construirePayload([signalement], [action]);
  assertEquals(payload[0].description.includes('76 41 09 90'), false);
  assertEquals(payload[0].actions[0].description.includes('zida@example.com'), false);
});

Deno.test('un signalement sans action donne une liste vide, pas une erreur', () => {
  const payload = construirePayload([signalement], []);
  assertEquals(payload[0].actions.length, 0);
});

Deno.test('la trace ne contient que des compteurs, aucun contenu', () => {
  const payload = construirePayload([signalement], [action]);
  const trace = traceTransmission(payload);
  assertEquals(trace.nb_signalements, 1);
  assertEquals(trace.nb_actions, 1);
  assertEquals(typeof trace.taille_caracteres, 'number');
  assertEquals(Object.keys(trace).sort(), [
    'nb_actions',
    'nb_signalements',
    'taille_caracteres',
  ]);
});
