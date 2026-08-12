// supabase/functions/quick-task/index.ts
// NOM RÉEL DÉPLOYÉ : quick-task (auto-généré par le dashboard).
// RÔLE : demande de réinitialisation de mot de passe (Vuln n°4, Modèle 2).
// Appelée par un utilisateur DÉCONNECTÉ depuis l'écran de login.
// Aucune authentification requise. Protections : anti-énumération (réponse
// toujours uniforme) + anti-doublon (index UNIQUE partiel sur demandes_reset).
// Email admin minimal (pas de données identifiantes dans le mail).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!
const FROM_EMAIL = 'CLM/OCASS Guinée <notifications@clm-ocass-guinee.org>'

function reponseUniforme(): Response {
  return new Response(
    JSON.stringify({
      ok: true,
      message: "Si un compte existe pour cette adresse, votre demande a été transmise à l'administrateur.",
    }),
    { headers: { 'Content-Type': 'application/json' } },
  )
}

async function envoyerEmail(destinataire: string, sujet: string, html: string) {
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: FROM_EMAIL, to: destinataire, subject: sujet, html }),
  })
  if (!res.ok) {
    console.error('Erreur envoi email notification admin, statut:', res.status)
  }
}

Deno.serve(async (req) => {
  try {
    const body = await req.json().catch(() => ({}))
    const email = typeof body.email === 'string' ? body.email.trim().toLowerCase() : ''

    if (!email || !email.includes('@')) {
      return reponseUniforme()
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    const { data: profil } = await adminClient
      .from('users')
      .select('id, actif')
      .eq('email', email)
      .maybeSingle()

    if (!profil || !profil.actif) {
      return reponseUniforme()
    }

    const { error: insertErr } = await adminClient
      .from('demandes_reset')
      .insert({ email })

    if (insertErr) {
      if (insertErr.code === '23505') {
        return reponseUniforme()
      }
      console.error('Erreur insert demande-reset, code:', insertErr.code)
      return reponseUniforme()
    }

    const { data: admins } = await adminClient
      .from('users')
      .select('email')
      .eq('role', 'admin')
      .eq('actif', true)

    if (admins && admins.length > 0) {
      await Promise.all(
        admins.map((a: { email: string }) =>
          envoyerEmail(
            a.email,
            'CLM/OCASS — Demande de réinitialisation en attente',
            `<p>Bonjour,</p>
             <p>Une demande de réinitialisation de mot de passe est en attente de traitement.</p>
             <p>Connectez-vous à votre espace d'administration, section « Demandes de réinitialisation », pour la traiter.</p>`,
          ),
        ),
      )
    }

    return reponseUniforme()
  } catch (e) {
    console.error('Erreur demande-reset:', e)
    return reponseUniforme()
  }
})
