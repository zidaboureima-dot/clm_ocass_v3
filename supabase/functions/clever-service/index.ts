import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const CLEVER_SERVICE_KEY = Deno.env.get('CLEVER_SERVICE_KEY')!

// TODO SaaS multi-tenant : FROM_EMAIL ne doit PAS rester codé en dur.
// À externaliser vers la config par pays (par tenant) quand la couche de
// configuration multi-tenant existera. Voir DETTES_SAAS.md.
// En l'état (Guinée mono-pays), valeur en dur assumée et localisée ici.
const FROM_EMAIL = 'CLM/OCASS Guinée <notifications@clm-ocass-guinee.org>'

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)

async function envoyerEmail(destinataire: string, sujet: string, html: string) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: FROM_EMAIL,
      to: destinataire,
      subject: sujet,
      html,
    }),
  })
  // On ne loggue jamais l'adresse ni le corps complet (données personnelles).
  // En cas d'échec seulement, on garde le statut HTTP pour le diagnostic.
  if (!res.ok) {
    console.error('Echec envoi email, statut:', res.status)
  }
}


Deno.serve(async (req) => {
  // Verification de la cle partagee : rejette tout appel non authentifie.
  const cleFournie = req.headers.get('x-shared-key')
  if (!CLEVER_SERVICE_KEY || cleFournie !== CLEVER_SERVICE_KEY) {
    console.warn('Appel rejete : cle partagee absente ou invalide.')
    return new Response('Unauthorized', { status: 401 })
  }

  // Note confidentialité : on ne loggue PAS les métadonnées de traitement
  // (région, préfecture, volumes par zone). Dans un dispositif de signalement,
  // ces logs permettraient de reconstituer l'activité de signalement d'une
  // zone. Seules les erreurs techniques sont journalisées.
  const payload = await req.json()
  const { type, table, record, old_record } = payload

  try {
    if (table === 'signalements' && type === 'INSERT') {
      const { data: superviseurs } = await supabase
        .from('users')
        .select('email, nom')
        .eq('role', 'superviseur')
        .eq('region', record.region)
        .eq('actif', true)

      for (const s of superviseurs ?? []) {
        await envoyerEmail(
          s.email,
          `Nouveau signalement — ${record.region}`,
          `<p>Bonjour ${s.nom},</p>
           <p>Un nouveau signalement (${record.nature}) a été soumis pour la préfecture <strong>${record.prefecture}</strong>, centre de santé <strong>${record.centre_sante}</strong>, catégorie <strong>${record.categorie_libelle}</strong>.</p>
           <p>Connectez-vous à l'application CLM/OCASS Guinée pour l'affecter à un point focal.</p>`
        )
      }
    }

    if (table === 'signalements' && type === 'UPDATE' && record.assignee_uid && record.assignee_uid !== old_record?.assignee_uid) {
      const { data: focal } = await supabase
        .from('users')
        .select('email, nom')
        .eq('id', record.assignee_uid)
        .single()

      if (focal) {
        await envoyerEmail(
          focal.email,
          `Signalement assigné — ${record.prefecture}`,
          `<p>Bonjour ${focal.nom},</p>
           <p>Un signalement (${record.nature}) vous a été assigné pour le centre de santé <strong>${record.centre_sante}</strong>.</p>
           <p>Connectez-vous à l'application CLM/OCASS Guinée pour le traiter.</p>`
        )
      }
    }

    if (table === 'messages_vocaux_bruts' && type === 'INSERT') {
      const { data: admins } = await supabase
        .from('users')
        .select('email, nom')
        .eq('role', 'admin')
        .eq('actif', true)

      for (const a of admins ?? []) {
        await envoyerEmail(
          a.email,
          'Nouveau message vocal reçu',
          `<p>Bonjour ${a.nom},</p>
           <p>Un usager a déposé un message vocal (${record.duree_secondes ?? '?'} s) sans passer par le formulaire structuré.</p>
           <p>Connectez-vous à l'espace administrateur, onglet "Messages vocaux", pour l'écouter et le transformer en signalement.</p>`
        )
      }
    }

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } })
  } catch (e) {
    console.error('Erreur notify:', e)
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 })
  }
})
