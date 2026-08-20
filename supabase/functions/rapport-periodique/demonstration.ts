// =====================================================================
// Jeu de données de DÉMONSTRATION.
//
// POURQUOI CE FICHIER EXISTE
//   Présenter le dispositif à un partenaire ou à une autorité suppose de
//   montrer à quoi ressemble un rapport. Les signalements réels n'ont pas
//   leur place dans une démonstration : ce sont des cas déposés par des
//   personnes qui n'ont pas consenti à figurer dans un support commercial,
//   et la politique de confidentialité s'engage à ne jamais exposer un
//   signalement individuel.
//
//   Ces données sont donc INTÉGRALEMENT FABRIQUÉES. Les établissements
//   nommés ci-dessous sont fictifs : le libellé « (exemple) » les rend
//   reconnaissables comme tels dans le rapport produit, y compris si
//   celui-ci circule hors de son contexte d'origine.
//
// CE QUE LE MODE DÉMONSTRATION NE CONTOURNE PAS
//   Il ne lit RIEN en base et n'écrit RIEN en base. Il n'a donc aucun accès
//   aux données réelles, et le rapport qu'il produit n'est pas enregistré.
//   Le drapeau `rapport_llm_actif` continue de protéger exactement ce qu'il
//   protégeait : le traitement de données réelles.
//
//   Autrement dit, ce mode ne fait passer aucune donnée de citoyen ou
//   d'agent chez le prestataire. Il valide la chaîne technique et produit un
//   spécimen, rien de plus.
// =====================================================================

export const SIGNALEMENTS_DEMO = [
  {
    id: 'demo-001',
    region: 'Conakry',
    prefecture: 'Ratoma',
    centre_sante: 'Centre de santé Nord (exemple)',
    groupe: 'Accès et Disponibilité des Services',
    categorie_libelle: 'Rupture de médicaments essentiels',
    nature: 'urgent',
    statut: 'traite',
    description: 'Rupture d\'antipaludiques signalée depuis trois semaines. Les patients sont orientés vers des officines privées.',
    soumis_le: '2026-07-04T09:12:00Z',
  },
  {
    id: 'demo-002',
    region: 'Conakry',
    prefecture: 'Ratoma',
    centre_sante: 'Centre de santé Nord (exemple)',
    groupe: 'Accès et Disponibilité des Services',
    categorie_libelle: 'Rupture de médicaments essentiels',
    nature: 'urgent',
    statut: 'en_cours',
    description: 'Toujours pas d\'antipaludiques disponibles. Situation identique au signalement précédent.',
    soumis_le: '2026-07-19T16:40:00Z',
  },
  {
    id: 'demo-003',
    region: 'Kankan',
    prefecture: 'Siguiri',
    centre_sante: 'Poste de santé Est (exemple)',
    groupe: 'Infrastructure, Équipement et Hygiène',
    categorie_libelle: 'Pannes d\'équipement',
    nature: 'normal',
    statut: 'traite',
    description: 'Réfrigérateur de la chaîne du froid en panne. Risque pour la conservation des vaccins.',
    soumis_le: '2026-07-08T11:05:00Z',
  },
  {
    id: 'demo-004',
    region: 'Kankan',
    prefecture: 'Kankan',
    centre_sante: 'Centre de santé Centre (exemple)',
    groupe: 'Qualité des Soins et Relation avec les Patients',
    categorie_libelle: 'Temps d\'attente excessif',
    nature: 'normal',
    statut: 'nouveau',
    description: 'Attente de plus de cinq heures en consultation externe, sans information donnée aux patients.',
    soumis_le: '2026-07-22T08:30:00Z',
  },
  {
    id: 'demo-005',
    region: 'Nzérékoré',
    prefecture: 'Nzérékoré',
    centre_sante: 'Centre de santé Sud (exemple)',
    groupe: 'Infrastructure, Équipement et Hygiène',
    categorie_libelle: 'Accès à l\'eau',
    nature: 'critique',
    statut: 'en_cours',
    description: 'Coupure d\'eau prolongée dans le service de maternité. Hygiène compromise.',
    soumis_le: '2026-07-11T14:20:00Z',
  },
  {
    id: 'demo-006',
    region: 'Nzérékoré',
    prefecture: 'Yomou',
    centre_sante: 'Poste de santé Ouest (exemple)',
    groupe: 'Accès et Disponibilité des Services',
    categorie_libelle: 'Absence de personnel',
    nature: 'urgent',
    statut: 'nouveau',
    description: 'Poste fermé plusieurs jours par semaine, sans affichage des horaires.',
    soumis_le: '2026-07-27T07:55:00Z',
  },
];

export const ACTIONS_DEMO = [
  {
    signalement_id: 'demo-001',
    auteur_uid: 'demo-uid-a',
    role_auteur: 'point_focal',
    type_action: 'saisine',
    description: 'Saisine de la direction de l\'établissement et transmission au district sanitaire.',
    resultat: 'en_attente',
    created_at: '2026-07-07T10:00:00Z',
  },
  {
    signalement_id: 'demo-001',
    auteur_uid: 'demo-uid-b',
    role_auteur: 'superviseur',
    type_action: 'plaidoyer',
    description: 'Démarche auprès de la direction régionale pour un réapprovisionnement d\'urgence.',
    resultat: 'obtenu',
    created_at: '2026-07-15T09:30:00Z',
  },
  {
    signalement_id: 'demo-002',
    auteur_uid: 'demo-uid-b',
    role_auteur: 'superviseur',
    type_action: 'relance',
    description: 'Relance du district après constat que la rupture persiste malgré le réapprovisionnement annoncé.',
    resultat: 'en_attente',
    created_at: '2026-07-24T11:15:00Z',
  },
  {
    signalement_id: 'demo-003',
    auteur_uid: 'demo-uid-c',
    role_auteur: 'point_focal',
    type_action: 'correction',
    description: 'Réparation du groupe froid obtenue, chaîne du froid rétablie et vérifiée sur place.',
    resultat: 'obtenu',
    created_at: '2026-07-14T15:45:00Z',
  },
  {
    signalement_id: 'demo-005',
    auteur_uid: 'demo-uid-d',
    role_auteur: 'superviseur',
    type_action: 'plaidoyer',
    description: 'Saisine des services techniques municipaux pour le rétablissement de l\'alimentation en eau.',
    resultat: 'en_attente',
    created_at: '2026-07-16T13:00:00Z',
  },
];
