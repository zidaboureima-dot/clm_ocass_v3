import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!

// TODO SaaS multi-tenant : FROM_EMAIL ne doit PAS rester codé en dur.
// À externaliser vers la config par pays (par tenant) quand la couche de
// configuration multi-tenant existera. Voir DETTES_SAAS.md.
// En l'état (Guinée mono-pays), valeur en dur assumée et localisée ici.
const FROM_EMAIL = 'CLM/OCASS Guinée <notifications@clm-ocass-guinee.org>'

function base64UrlDecode(str: string): string {
  str = str.replace(/-/g, '+').replace(/_/g, '/')
  while (str.length % 4) str += '='
  return atob(str)
}

function getUserIdFromJwt(authHeader: string): string | null {
  try {
    const token = authHeader.replace('Bearer ', '')
    const payload = token.split('.')[1]
    const decoded = JSON.parse(base64UrlDecode(payload))
    return decoded.sub ?? null
  } catch {
    return null
  }
}

function genererMotDePasseTemporaire(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789'
  const bytes = new Uint8Array(12)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => chars[b % chars.length]).join('')
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
    // On ne loggue que le statut HTTP, jamais l'adresse ni le corps
    // (données personnelles). Suffisant pour diagnostiquer un échec d'envoi.
    console.error('Erreur envoi email, statut:', res.status)
  }
}

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const callerId = getUserIdFromJwt(authHeader)
    if (!callerId) {
      return new Response(JSON.stringify({ ok: false, error: 'Non authentifié' }), { status: 401 })
    }

    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY)

    const { data: callerProfile } = await adminClient
      .from('users')
      .select('role, actif')
      .eq('id', callerId)
      .single()

    if (!callerProfile || callerProfile.role !== 'admin' || !callerProfile.actif) {
      return new Response(JSON.stringify({ ok: false, error: 'Action réservée aux administrateurs actifs' }), { status: 403 })
    }

    const { email, role, nom, region, prefecture } = await req.json()

    if (!email || !role || !nom) {
      return new Response(JSON.stringify({ ok: false, error: 'Champs manquants' }), { status: 400 })
    }
    if (role !== 'superviseur' && role !== 'point_focal') {
      return new Response(JSON.stringify({ ok: false, error: 'Rôle invalide' }), { status: 400 })
    }

    const motDePasseTemporaire = genererMotDePasseTemporaire()

    const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
      email,
      password: motDePasseTemporaire,
      email_confirm: true,
    })
    if (createErr || !created?.user) {
      return new Response(JSON.stringify({ ok: false, error: createErr?.message ?? 'Création du compte impossible' }), { status: 400 })
    }

    const { error: insertErr } = await adminClient.from('users').insert({
      id: created.user.id,
      email,
      role,
      nom,
      region: region ?? null,
      prefecture: prefecture ?? null,
      actif: true,
      doit_changer_mdp: true,
    })
    if (insertErr) {
      await adminClient.auth.admin.deleteUser(created.user.id)
      return new Response(JSON.stringify({ ok: false, error: insertErr.message }), { status: 400 })
    }

    const libelleRole = role === 'superviseur' ? 'superviseur' : 'point focal'
    await envoyerEmail(
      email,
      'Votre compte CLM/OCASS Guinée',
      `<p>Bonjour ${nom},</p>
       <p>Un compte ${libelleRole} vient d'être créé pour vous sur l'application CLM/OCASS Guinée.</p>
       <p>Identifiants de première connexion :</p>
       <p>Email : <strong>${email}</strong><br>Mot de passe temporaire : <strong>${motDePasseTemporaire}</strong></p>
       <p>Merci de vous connecter puis de changer immédiatement ce mot de passe depuis l'icône cadenas de votre espace.</p>`
    )

    return new Response(JSON.stringify({ ok: true, id: created.user.id }), { headers: { 'Content-Type': 'application/json' } })
  } catch (e) {
    console.error('Erreur quick-endpoint:', e)
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 })
  }
})
