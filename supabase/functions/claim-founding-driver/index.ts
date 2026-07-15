// claim-founding-driver
// Called when a founding driver logs into the Flutter app for the first time.
// Looks up their email in founding_driver_signups and merges the pre-auth
// data into the drivers table, skipping all onboarding steps.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders });
  }

  // This function requires a valid JWT (the driver must be logged in)
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Not authenticated' }), {
      status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    // Get the authenticated user from the JWT
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid session' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }

    const email = user.email!.toLowerCase().trim();

    // Find the founding driver signup by email
    const { data: signup, error: signupError } = await supabase
      .from('founding_driver_signups')
      .select('*')
      .eq('email', email)
      .in('status', ['signup_received', 'veriff_invited', 'veriff_started', 'veriff_approved'])
      .single();

    if (signupError || !signup) {
      // Not a founding driver — normal app flow applies
      return new Response(
        JSON.stringify({ is_founding_driver: false }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Check if already claimed
    if (signup.driver_id) {
      return new Response(
        JSON.stringify({
          is_founding_driver: true,
          already_claimed: true,
          founding_number: signup.founding_number,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Upsert the drivers row with all the data from the web form
    // driver ID = Supabase auth user ID
    const { error: driverError } = await supabase
      .from('drivers')
      .upsert({
        id: user.id,
        email: email,
        full_name: signup.full_name,
        phone: signup.phone,
        home_city: signup.home_city,
        vehicle_plate: signup.vehicle_plate,
        vehicle_make: signup.vehicle_make,
        vehicle_model: signup.vehicle_model,
        kvk_number: signup.kvk_number,
        chauffeurspas_number: signup.chauffeurspas_number,
        is_founding_driver: true,
        founding_number: signup.founding_number,
        founding_rate_locked: true,
        weekly_rate_euros: 30.00,
        billing_starts_after_euros: 100.00,
        // Compliance carried over from Veriff if approved
        rijbewijs_verified: signup.veriff_decision === 'approved',
        veriff_status: signup.veriff_decision,
        veriff_session_id: signup.veriff_session_id,
        veriff_session_url: signup.veriff_session_url,
        veriff_completed_at: signup.veriff_completed_at,
        // Profile status: jump straight to pending_review if Veriff approved
        profile_status: signup.veriff_decision === 'approved' ? 'pending_review' : 'incomplete',
        compliance_status: signup.veriff_decision === 'approved' ? 'pending_review' : 'incomplete',
        // Mark onboarding steps as done — they did these on the web
        onboarding_feature_tour_shown: false, // Show the app tour once
      }, { onConflict: 'id' });

    if (driverError) {
      console.error('Driver upsert error:', driverError);
      return new Response(
        JSON.stringify({ error: 'Failed to create driver profile' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Create onboarding steps row, mark web steps as done
    await supabase
      .from('driver_onboarding_steps')
      .upsert({
        driver_id: user.id,
        step_personal_done: true,
        step_personal_done_at: signup.created_at,
        step_vehicle_done: !!signup.vehicle_plate,
        step_vehicle_done_at: signup.vehicle_plate ? signup.created_at : null,
        step_business_done: !!signup.kvk_number,
        step_business_done_at: signup.kvk_number ? signup.created_at : null,
        step_compliance_done: signup.veriff_decision === 'approved',
        step_compliance_done_at: signup.veriff_decision === 'approved' ? signup.veriff_completed_at : null,
        sub_rijbewijs_done: signup.veriff_decision === 'approved',
        sub_chauffeurspas_done: !!signup.chauffeurspas_number,
        onboarding_submitted_at: signup.created_at,
        current_step: signup.veriff_decision === 'approved' ? 5 : 4,
      }, { onConflict: 'driver_id' });

    // Mark the signup row as app_claimed
    await supabase
      .from('founding_driver_signups')
      .update({
        driver_id: user.id,
        app_claimed_at: new Date().toISOString(),
        status: 'app_claimed',
      })
      .eq('id', signup.id);

    return new Response(
      JSON.stringify({
        is_founding_driver: true,
        founding_number: signup.founding_number,
        needs_profile_photo: true,   // Only thing left in the app
        needs_vehicle_photo: true,
        veriff_approved: signup.veriff_decision === 'approved',
        message: `Welkom terug, Founding Driver #${signup.founding_number}! Je account is gekoppeld.`,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (err) {
    console.error('Unexpected error:', err);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});

