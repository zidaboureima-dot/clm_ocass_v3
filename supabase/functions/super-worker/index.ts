import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const SITE_BRIDGE_KEY = Deno.env.get('SITE_BRIDGE_KEY')

// Vérification de présence du secret au démarrage, SANS révéler sa valeur
// ni sa longueur (un secret ne doit jamais apparaître dans les logs).
if (!SITE_BRIDGE_KEY) {
  console.error('SITE_BRIDGE_KEY manquante : la passerelle refusera toutes les requêtes.')
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type, x-site-key',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

function reponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}

// Rate-limit par IP : max 8 soumissions sur une fenêtre glissante de 5 min.
// Purge opportuniste des lignes de plus d'une heure à chaque passage, pour
// empêcher la table bridge_rate_limit de croître indéfiniment (pas de
// pg_cron sur le projet). La fenêtre utile n'étant que de 5 min, tout ce
// qui dépasse 1 h est du poids mort.
async function verifierDebit(ip: string): Promise<boolean> {
  const maintenant = Date.now()
  const depuis = new Date(maintenant - 5 * 60 * 1000).toISOString()

  // Purge opportuniste (best-effort : une erreur ici ne bloque pas le dépôt).
  const seuilPurge = new Date(maintenant - 60 * 60 * 1000).toISOString()
  await supabase.from('bridge_rate_limit').delete().lt('created_at', seuilPurge)

  const { count } = await supabase
    .from('bridge_rate_limit')
    .select('*', { count: 'exact', head: true })
    .eq('ip', ip)
    .gte('created_at', depuis)
  if ((count ?? 0) >= 8) return false
  await supabase.from('bridge_rate_limit').insert({ ip })
  return true
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: CORS })

  // Comparaison de la clé de passerelle SANS journaliser la clé (reçue ou
  // attendue). On ne logge que le résultat booléen en cas d'échec, ce qui
  // suffit au diagnostic sans exposer le secret.
  const cle = req.headers.get('x-site-key')
  if (cle !== SITE_BRIDGE_KEY) {
    console.warn('Passerelle : requête rejetée (clé invalide ou absente).')
    return reponse({ ok: false, error: 'Clé invalide' }, 401)
  }

  const ip = req.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'inconnu'
  const url = new URL(req.url)
  const action = url.searchParams.get('action')

  try {
    if (req.method === 'GET' && action === 'categories') {
      const { data, error } = await supabase
        .from('categories')
        .select('id, groupe, libelle')
        .eq('actif', true)
        .order('ordre', { ascending: true })
      if (error) throw error
      return reponse({ ok: true, categories: data })
    }

    if (req.method === 'GET' && action === 'stats') {
      const { data, error } = await supabase.from('signalements').select('statut, nature, region, groupe, categorie_libelle')
      if (error) throw error
      const total = data.length
      const parStatut: Record<string, number> = {}
      const parNature: Record<string, number> = {}
      const parRegion: Record<string, number> = {}
      const parCategorie: Record<string, number> = {}
      for (const s of data) {
        parStatut[s.statut] = (parStatut[s.statut] ?? 0) + 1
        parNature[s.nature] = (parNature[s.nature] ?? 0) + 1
        parRegion[s.region] = (parRegion[s.region] ?? 0) + 1
        const cat = s.categorie_libelle || s.groupe
        if (cat) parCategorie[cat] = (parCategorie[cat] ?? 0) + 1
      }
      return reponse({ ok: true, total, parStatut, parNature, parRegion, parCategorie })
    }

    if (req.method === 'POST' && action === 'signalement') {
      if (!(await verifierDebit(ip))) {
        return reponse({ ok: false, error: 'Trop de demandes, réessayez plus tard' }, 429)
      }
      const body = await req.json()
      const { region, prefecture, centre_sante, nature, groupe, categorie_id, categorie_libelle, description } = body

      if (!region || !prefecture || !centre_sante || !nature || !groupe || !categorie_libelle || !description) {
        return reponse({ ok: false, error: 'Champs manquants' }, 400)
      }
      if (description.length < 10) {
        return reponse({ ok: false, error: 'Description trop courte' }, 400)
      }

      const id = crypto.randomUUID()
      const { error } = await supabase.from('signalements').insert({
        id,
        anonyme: true,
        region,
        prefecture,
        centre_sante,
        nature,
        groupe,
        categorie_id: categorie_id ?? null,
        categorie_libelle,
        description,
        soumis_le: new Date().toISOString(),
        statut: 'nouveau',
      })
      if (error) throw error
      return reponse({ ok: true, id })
    }

    return reponse({ ok: false, error: 'Action inconnue' }, 400)
  } catch (e) {
    console.error('Erreur site-bridge:', e)
    return reponse({ ok: false, error: String(e) }, 500)
  }
})
