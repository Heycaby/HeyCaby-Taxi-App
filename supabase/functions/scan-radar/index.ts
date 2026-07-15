// scan-radar Edge Function v3
// Fully aligned to frontend contract
// driver_id derived from JWT — never trusted from request body

import { createClient } from 'jsr:@supabase/supabase-js'

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!

function json(obj: object, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
  })
}

function cors() {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'authorization, content-type',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
    }
  })
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return cors()

  try {
    // ── Derive driver_id from JWT (never trust body) ──────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Unauthorized' }, 401)

    // User-scoped client to resolve caller identity
    const userClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    })
    const { data: { user }, error: userError } = await userClient.auth.getUser()
    if (userError || !user) return json({ error: 'Unauthorized' }, 401)

    // Service-role client for all DB operations
    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    })

    // Resolve driver record from auth user
    const { data: driver } = await supabase
      .from('drivers')
      .select('id')
      .eq('user_id', user.id)
      .single()
    if (!driver) return json({ error: 'Driver not found' }, 403)
    const driverId = driver.id

    const body = await req.json()
    // Normalise action aliases from frontend
    const rawAction = body.action as string
    const action = rawAction === 'stop' ? 'stop_session'
                 : rawAction === 'dismiss' ? 'dismiss_match'
                 : rawAction

    const rideRequestId: string | undefined = body.ride_request_id
    const sessionId: string | undefined    = body.session_id

    // ── ACTION: start_session ─────────────────────────────────
    if (action === 'start_session') {
      if (!rideRequestId) return json({ error: 'Missing ride_request_id' }, 400)

      const { data: sessionUuid, error } = await supabase.rpc('fn_start_radar_session', {
        p_driver_id:       driverId,
        p_ride_request_id: rideRequestId,
      })
      if (error) {
        console.error('fn_start_radar_session error:', error)
        return json({ error: error.message }, 500)
      }

      // Run first scan immediately so screen has data on open
      await runScan(supabase, sessionUuid as string, driverId)

      // Return full state so frontend can immediately render
      const { data: state } = await supabase.rpc('fn_get_radar_state', { p_driver_id: driverId })
      return json({ session_id: sessionUuid, state })
    }

    // ── ACTION: scan ──────────────────────────────────────────
    if (action === 'scan') {
      // session_id optional — derive from active session if not provided
      let sid = sessionId
      if (!sid) {
        const { data: active } = await supabase
          .from('driver_radar_sessions')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'scanning')
          .order('created_at', { ascending: false })
          .limit(1)
          .single()
        sid = active?.id
      }
      if (!sid) return json({ error: 'No active radar session' }, 404)

      const newMatches = await runScan(supabase, sid, driverId)
      const { data: state } = await supabase.rpc('fn_get_radar_state', { p_driver_id: driverId })
      return json({ state, new_matches: newMatches })
    }

    // ── ACTION: get_state ─────────────────────────────────────
    if (action === 'get_state') {
      const { data: state } = await supabase.rpc('fn_get_radar_state', { p_driver_id: driverId })
      return json({ state })
    }

    // ── ACTION: soft_reserve ──────────────────────────────────
    if (action === 'soft_reserve') {
      if (!rideRequestId) return json({ error: 'Missing ride_request_id' }, 400)
      const { data } = await supabase.rpc('fn_soft_reserve_ride', {
        p_driver_id:       driverId,
        p_ride_request_id: rideRequestId,
      })
      return json({ reserved: data })
    }

    // ── ACTION: dismiss / dismiss_match ───────────────────────
    if (action === 'dismiss_match') {
      if (!rideRequestId) return json({ error: 'Missing ride_request_id' }, 400)
      // Resolve session_id if not provided
      let sid = sessionId
      if (!sid) {
        const { data: active } = await supabase
          .from('driver_radar_sessions')
          .select('id')
          .eq('driver_id', driverId)
          .eq('status', 'scanning')
          .order('created_at', { ascending: false })
          .limit(1)
          .single()
        sid = active?.id
      }
      if (sid) {
        await supabase
          .from('radar_matches')
          .update({ driver_action: 'dismissed', actioned_at: new Date().toISOString() })
          .eq('radar_session_id', sid)
          .eq('ride_request_id', rideRequestId)
      }
      return json({ ok: true })
    }

    // ── ACTION: stop / stop_session ───────────────────────────
    if (action === 'stop_session') {
      await supabase
        .from('driver_radar_sessions')
        .update({ status: 'cancelled', updated_at: new Date().toISOString() })
        .eq('driver_id', driverId)
        .eq('status', 'scanning')
      return json({ ok: true })
    }

    return json({ error: `Unknown action: ${rawAction}` }, 400)

  } catch (e) {
    console.error('scan-radar error:', e)
    return json({ error: String(e) }, 500)
  }
})

// ─────────────────────────────────────────────────────────────
// runScan — calls fn_scan_radar_matches, upserts results,
// handles auto-accept and push notifications
// ─────────────────────────────────────────────────────────────
async function runScan(
  supabase: ReturnType<typeof createClient>,
  sessionId: string,
  driverId: string
): Promise<number> {

  const { data: session } = await supabase
    .from('driver_radar_sessions')
    .select('auto_accept_enabled, auto_accept_min_score, auto_accept_min_fare')
    .eq('id', sessionId)
    .single()

  if (!session) return 0

  const { data: matches, error } = await supabase.rpc('fn_scan_radar_matches', {
    p_session_id: sessionId,
  })
  if (error || !matches?.length) return 0

  let newHighScoreCount = 0

  for (const match of matches) {
    // Check if we've already processed this match
    const { data: existing } = await supabase
      .from('radar_matches')
      .select('id, driver_action, notified_at')
      .eq('radar_session_id', sessionId)
      .eq('ride_request_id', match.ride_request_id)
      .maybeSingle()

    if (existing?.driver_action) continue

    // Upsert match record
    await supabase.from('radar_matches').upsert({
      radar_session_id:  sessionId,
      driver_id:         driverId,
      ride_request_id:   match.ride_request_id,
      match_score:       match.match_score,
      offered_fare:      match.offered_fare,
      eta_to_pickup_min: match.eta_to_pickup_min,
      is_feasible:       match.is_feasible,
    }, { onConflict: 'radar_session_id,ride_request_id' })

    const isNew       = !existing
    const isHighScore = match.match_score >= (session.auto_accept_min_score ?? 85)
    const meetsFare   = (match.offered_fare ?? 0) >= (session.auto_accept_min_fare ?? 0)

    // ── Auto-accept path ──────────────────────────────────────
    if (session.auto_accept_enabled && isHighScore && meetsFare && match.is_feasible) {
      const { data: reserved } = await supabase.rpc('fn_soft_reserve_ride', {
        p_driver_id:       driverId,
        p_ride_request_id: match.ride_request_id,
      })
      if (reserved) {
        await supabase.from('radar_matches').update({
          auto_accepted: true,
          driver_action: 'accepted',
          actioned_at:   new Date().toISOString(),
        })
        .eq('radar_session_id', sessionId)
        .eq('ride_request_id', match.ride_request_id)

        await supabase.from('notifications').insert({
          user_type: 'driver',
          user_id:   driverId,
          agent:     'driver_agent',
          category:  'radar_auto_accept',
          title:     '✅ Return ride auto-accepted',
          body:      `${match.pickup_zone_name} → ${match.destination_zone_name} · €${match.offered_fare}`,
          data:      { ride_request_id: match.ride_request_id, screen: 'radar' },
          priority:  'high',
          channel:   'both',
        })
      }
      continue
    }

    // ── Push notification for strong new matches ──────────────
    if (isNew && isHighScore && match.is_feasible) {
      await supabase.from('radar_matches').update({
        notified_at: new Date().toISOString()
      })
      .eq('radar_session_id', sessionId)
      .eq('ride_request_id', match.ride_request_id)

      await supabase.from('notifications').insert({
        user_type: 'driver',
        user_id:   driverId,
        agent:     'driver_agent',
        category:  'radar_match',
        title:     match.match_score >= 90 ? '🔥 Perfect return ride nearby' : '⭐ Strong return ride match',
        body:      `${match.pickup_zone_name} → ${match.destination_zone_name} · €${match.offered_fare}`,
        data:      { ride_request_id: match.ride_request_id, screen: 'radar' },
        priority:  match.match_score >= 90 ? 'high' : 'medium',
        channel:   'both',
      })

      newHighScoreCount++
    }
  }

  return newHighScoreCount
}

