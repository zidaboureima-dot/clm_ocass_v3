// =====================================================================
// Lecture de la configuration par pays.
//
// Chaque pays contractant relève d'un cadre juridique distinct : ce qui est
// licite dans l'un ne l'est pas nécessairement dans l'autre. Toute
// fonctionnalité dont la licéité dépend du pays doit passer par ici.
//
// Voir 20260819_configuration_pays_et_rapports.sql.
// =====================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface ConfigurationPays {
  pays_code: string;
  libelle_pays: string;
  from_email: string | null;
  rapport_llm_actif: boolean;
  rapport_llm_motif: string | null;
}

/**
 * Lit la configuration d'un pays. Renvoie null si le pays est inconnu.
 *
 * Le client doit être en service_role : `configuration_pays` n'expose aucune
 * policy de lecture en dehors du rôle admin.
 */
export async function lireConfigurationPays(
  supabase: ReturnType<typeof createClient>,
  paysCode: string,
): Promise<ConfigurationPays | null> {
  const { data, error } = await supabase
    .from('configuration_pays')
    .select('pays_code, libelle_pays, from_email, rapport_llm_actif, rapport_llm_motif')
    .eq('pays_code', paysCode)
    .maybeSingle();

  if (error) throw new Error(`Lecture configuration pays ${paysCode} : ${error.message}`);
  return (data as ConfigurationPays | null) ?? null;
}

/**
 * Vérifie que le rapport assisté par modèle est autorisé pour ce pays.
 *
 * Échoue en cas de pays inconnu — et non en laissant passer. Un pays absent
 * de la table est un pays dont on ignore le cadre juridique : le silence ne
 * vaut pas autorisation.
 *
 * Cette vérification double celle du trigger en base. La redondance est
 * voulue : elle évite un appel inutile au prestataire, et surtout elle évite
 * de transmettre des données avant de découvrir, à l'insertion, que la
 * fonctionnalité était éteinte. L'ordre importe — on vérifie AVANT de sortir
 * quoi que ce soit, pas après.
 */
export async function exigerRapportLlmActif(
  supabase: ReturnType<typeof createClient>,
  paysCode: string,
): Promise<ConfigurationPays> {
  const config = await lireConfigurationPays(supabase, paysCode);

  if (!config) {
    throw new Error(
      `Pays ${paysCode} absent de configuration_pays : aucune génération possible tant que son cadre n'est pas renseigné.`,
    );
  }

  if (!config.rapport_llm_actif) {
    throw new Error(
      `Génération refusée pour ${config.libelle_pays} : fonctionnalité désactivée. Motif enregistré : ${config.rapport_llm_motif ?? 'non renseigné'}`,
    );
  }

  return config;
}
