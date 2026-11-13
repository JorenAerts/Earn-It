// Deletes the calling user's account (App Store Review Guideline 5.1.1(v)).
// The user is identified from their JWT; the service-role key is injected by Supabase
// into the function environment and never leaves the server.
import { createClient } from "npm:@supabase/supabase-js@2";

Deno.serve(async (req) => {
  const jwt = req.headers.get("Authorization")?.replace("Bearer ", "");
  if (!jwt) return new Response("Unauthorized", { status: 401 });

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: { user }, error } = await admin.auth.getUser(jwt);
  if (error || !user) return new Response("Unauthorized", { status: 401 });

  // profiles row is removed by `on delete cascade`.
  const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteError) return new Response(deleteError.message, { status: 500 });

  return new Response(JSON.stringify({ deleted: true }), {
    headers: { "Content-Type": "application/json" },
  });
});
