import { createClient } from 'jsr:@supabase/supabase-js@2';

const VALID_EVENTS = ['app_open','page_view','pwa_install','ride_started','driver_signup'];

Deno.serve(async (req: Request) => {
  // CORS — allow from rydtap.nl and localhost
  const origin = req.headers.get('origin') ?? '';
  const allowed = origin.includes('rydtap') || origin.includes('localhost') || origin.includes('vercel.app');
  const corsHeaders = {
    'Access-Control-Allow-Origin': allowed ? origin : 'https://rydtap.nl',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, apikey',
  };

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405, headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const { event, page, session_id, referrer } = body;

    // Validate event
    if (!event || !VALID_EVENTS.includes(event)) {
      return new Response(JSON.stringify({ error: 'Invalid event' }), { status: 400, headers: corsHeaders });
    }

    // Detect mobile vs desktop from UA (no personal data stored)
    const ua = req.headers.get('user-agent') ?? '';
    const user_agent_hint = /mobile|android|iphone|ipad/i.test(ua) ? 'mobile' : 'desktop';

    // Clean referrer — just the source hint, not full URL
    let cleanReferrer = referrer ?? '';
    if (cleanReferrer.includes('whatsapp')) cleanReferrer = 'whatsapp';
    else if (cleanReferrer.includes('instagram')) cleanReferrer = 'instagram';
    else if (cleanReferrer.includes('facebook')) cleanReferrer = 'facebook';
    else if (cleanReferrer.includes('google')) cleanReferrer = 'google';
    else if (cleanReferrer === '') cleanReferrer = 'direct';
    else cleanReferrer = 'other';

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    await supabase.from('app_analytics').insert({
      event,
      page: page ?? '/',
      session_id: session_id ?? null,
      referrer: cleanReferrer,
      user_agent_hint,
    });

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: 'Internal error' }), {
      status: 500,
      headers: corsHeaders,
    });
  }
});

