import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // ── GET: check spots remaining ──────────────────────────────
    if (req.method === 'GET') {
      const { data } = await supabase
        .from('founding_driver_counter')
        .select('claimed, total')
        .single();
      return new Response(
        JSON.stringify({ spots_remaining: (data?.total ?? 200) - (data?.claimed ?? 0) }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // ── POST: submit founding driver form ───────────────────────
    if (req.method !== 'POST') {
      return new Response('Method not allowed', { status: 405, headers: corsHeaders });
    }

    const body = await req.json();
    const {
      full_name, name, email, phone, home_city, city,
      vehicle_plate, vehicle_make, vehicle_model, vehicle_year,
      kvk_number, chauffeurspas_number,
      agreed_to_terms, agree_terms,
    } = body;

    // Use frontend field names if backend names not provided
    const finalName = full_name || name;
    const finalCity = home_city || city;
    const finalAgreed = agreed_to_terms || agree_terms;

    // Validate required fields
    if (!finalName || !email || !phone || !finalCity || !finalAgreed) {
      return new Response(
        JSON.stringify({ error: 'Vereiste velden ontbreken.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Validate email format
    const emailRegex = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
    if (!emailRegex.test(email)) {
      return new Response(
        JSON.stringify({ error: 'Ongeldig e-mailadres.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check spots available
    const { data: counter } = await supabase
      .from('founding_driver_counter')
      .select('claimed, total')
      .single();

    const foundingEligible = !!counter && counter.claimed < counter.total;

    // Check if email already exists
    const { data: existing } = await supabase
      .from('founding_driver_signups')
      .select('id, founding_number, status')
      .eq('email', email.toLowerCase().trim())
      .single();

    if (existing) {
      return new Response(
        JSON.stringify({
          error: 'Je hebt je al aangemeld.',
          already_registered: true,
          founding_number: existing.founding_number,
          status: existing.status,
        }),
        { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Insert new founding driver signup
    const { data: signup, error: insertError } = await supabase
      .from('founding_driver_signups')
      .insert({
        full_name: finalName.trim(),
        email: email.toLowerCase().trim(),
        phone: phone.trim(),
        home_city: finalCity.trim(),
        vehicle_plate: vehicle_plate?.toUpperCase().trim() ?? null,
        vehicle_make: vehicle_make?.trim() ?? null,
        vehicle_model: vehicle_model?.trim() ?? null,
        vehicle_year: vehicle_year ?? null,
        kvk_number: kvk_number?.trim() ?? null,
        chauffeurspas_number: chauffeurspas_number?.trim() ?? null,
        agreed_to_terms: true,
        agreed_at: new Date().toISOString(),
        status: 'signup_received',
      })
      .select('id, founding_number, email, full_name')
      .single();

    if (insertError) {
      console.error('Insert error:', insertError);
      return new Response(
        JSON.stringify({ error: 'Er is een fout opgetreden. Probeer het opnieuw.' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({
        success: true,
        founding_number: foundingEligible ? signup!.founding_number : null,
        message: foundingEligible
          ? `Welkom! Je aanmelding is ontvangen. Verifieer je e-mail met de 6-cijferige code om je founding plek vast te zetten.`
          : `Je aanmelding is ontvangen. Verifieer je e-mail met de 6-cijferige code om door te gaan.`,
      }),
      { status: 201, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(
      JSON.stringify({ error: 'Interne serverfout.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

