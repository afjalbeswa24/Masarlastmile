import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user: caller } } = await supabaseClient.auth.getUser();
    if (!caller) {
      return new Response(JSON.stringify({ error: 'Invalid session' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { data: callerProfile } = await supabaseClient
      .from('profiles')
      .select('role, can_manage_users, company_id')
      .eq('id', caller.id)
      .single();

    const allowed =
      callerProfile?.role === 'master_dispatcher' ||
      (callerProfile?.role === 'dispatcher' && callerProfile?.can_manage_users === true);

    if (!allowed) {
      return new Response(JSON.stringify({ error: 'Not permitted to manage users' }), { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // SECURITY: the new user's company is ALWAYS the caller's own company —
    // never trusted from the client request, so no dispatcher can create
    // an account under a different company.
    const callerCompanyId = callerProfile.company_id;

    const { email, password, fullName, role } = await req.json();

    // master_dispatcher and super_admin can never be created through this
    // path — master_dispatcher only via "Make Master Dispatcher" promotion
    // (same company), and super_admin only via manual setup.
    const validRoles = ['dispatcher', 'driver', 'warehouse', 'merchant'];
    if (!validRoles.includes(role)) {
      return new Response(JSON.stringify({ error: 'Invalid role' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: newUser, error: createError } = await supabaseAdmin.auth.admin.createUser({
      email, password, email_confirm: true,
    });

    if (createError || !newUser.user) {
      return new Response(JSON.stringify({ error: createError?.message ?? 'Failed to create user' }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const { error: profileError } = await supabaseAdmin.from('profiles').insert({
      id: newUser.user.id,
      role,
      full_name: fullName,
      company_id: callerCompanyId,
      email: newUser.user.email,
    });

    if (profileError) {
      await supabaseAdmin.auth.admin.deleteUser(newUser.user.id);
      return new Response(JSON.stringify({ error: profileError.message }), { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    return new Response(JSON.stringify({ success: true, userId: newUser.user.id }), { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
  }
});