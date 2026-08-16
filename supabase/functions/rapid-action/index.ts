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
    // On ne loggue que le statut HTTP, jamais le corps (contient l'adresse
    // et des détails). Suffisant pour diagnostiquer un échec d'envoi.
    console.error('Erreur envoi email reset, statut:', res.status)
  }
}

Deno.serve(async (req) => {
  try {
    // 1. Authentifier l'appelant et vérifier qu'il est admin actif.
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

    // 2. Lire l'id de la demande à traiter.
    const { demande_id } = await req.json()
    if (!demande_id) {
      return new Response(JSON.stringify({ ok: false, error: 'demande_id manquant' }), { status: 400 })
    }

    // 3. Charger la demande et vérifier qu'elle est bien en attente.
    const { data: demande, error: demandeErr } = await adminClient
      .from('demandes_reset')
      .select('id, email, statut')
      .eq('id', demande_id)
      .single()

    if (demandeErr || !demande) {
      return new Response(JSON.stringify({ ok: false, error: 'Demande introuvable' }), { status: 404 })
    }
    if (demande.statut !== 'en_attente') {
      return new Response(JSON.stringify({ ok: false, error: 'Demande déjà traitée' }), { status: 409 })
    }

    // 4. Résoudre le compte cible à partir de l'email (doit être actif).
    const { data: cible, error: cibleErr } = await adminClient
      .from('users')
      .select('id, nom, actif')
      .eq('email', demande.email)
      .maybeSingle()

    if (cibleErr || !cible || !cible.actif) {
      return new Response(JSON.stringify({ ok: false, error: 'Compte cible introuvable ou inactif' }), { status: 404 })
    }

    // 5. Générer un mot de passe temporaire et l'appliquer côté Auth.
    const motDePasseTemporaire = genererMotDePasseTemporaire()

    const { error: updateAuthErr } = await adminClient.auth.admin.updateUserById(cible.id, {
      password: motDePasseTemporaire,
    })
    if (updateAuthErr) {
      return new Response(JSON.stringify({ ok: false, error: updateAuthErr.message }), { status: 400 })
    }

    // 6. Forcer le changement de mot de passe au prochain accès.
    const { error: flagErr } = await adminClient
      .from('users')
      .update({ doit_changer_mdp: true })
      .eq('id', cible.id)
    if (flagErr) {
      console.error('Erreur maj doit_changer_mdp:', flagErr.code)
      // Non bloquant pour l'accès, mais on le signale.
    }

    // 7. Envoyer le mot de passe temporaire au demandeur.
    await envoyerEmail(
      demande.email,
      'CLM/OCASS Guinée — Réinitialisation de votre mot de passe',
      `<p>Bonjour ${cible.nom ?? ''},</p>
       <p>Votre mot de passe a été réinitialisé à la demande de l'administrateur.</p>
       <p>Mot de passe temporaire : <strong>${motDePasseTemporaire}</strong></p>
       <p>Connectez-vous avec ce mot de passe : il vous sera demandé de le changer immédiatement.</p>`
    )

    // 8. Marquer la demande comme traitée.
    const { error: statutErr } = await adminClient
      .from('demandes_reset')
      .update({ statut: 'traitee', traitee_le: new Date().toISOString() })
      .eq('id', demande.id)
    if (statutErr) {
      console.error('Erreur passage demande à traitee:', statutErr.code)
      // Le reset a réussi ; la ligne restera "en_attente" et pourra être rejouée.
      // À surveiller si ça arrive en pratique.
    }

    return new Response(JSON.stringify({ ok: true }), { headers: { 'Content-Type': 'application/json' } })
  } catch (e) {
    console.error('Erreur traiter-reset:', e)
    return new Response(JSON.stringify({ ok: false, error: String(e) }), { status: 500 })
  }
})
