// Deletes morning photos older than 24 h (rows + files), and files left behind by deleted
// accounts. Run hourly: Dashboard › Integrations › Cron › new job › "Supabase Edge Function"
// › cleanup-morning-posts, schedule `0 * * * *`.
//
// Uses the service role key that Supabase injects into Edge Functions; it never leaves the server.
import { createClient } from "jsr:@supabase/supabase-js@2";

const BUCKET = "morning";

Deno.serve(async () => {
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 1. Expired posts.
  const { data: expired, error } = await admin
    .from("morning_posts")
    .select("id, image_path")
    .lt("expires_at", new Date().toISOString())
    .limit(1000);
  if (error) return json({ error: error.message }, 500);

  let files = 0;
  if (expired && expired.length > 0) {
    const paths = expired.map((p) => p.image_path);
    const { error: removeError } = await admin.storage.from(BUCKET).remove(paths);
    if (removeError) return json({ error: removeError.message }, 500);
    files += paths.length;
    await admin.from("morning_posts").delete().in("id", expired.map((p) => p.id));
  }

  // 2. Folders of users that no longer exist (account deleted).
  const { data: folders } = await admin.storage.from(BUCKET).list("", { limit: 1000 });
  for (const folder of folders ?? []) {
    if (folder.id !== null) continue; // a file at the root, not a folder
    const { data: user } = await admin.auth.admin.getUserById(folder.name);
    if (user?.user) continue;
    const { data: orphaned } = await admin.storage.from(BUCKET).list(folder.name, { limit: 1000 });
    const paths = (orphaned ?? []).map((f) => `${folder.name}/${f.name}`);
    if (paths.length > 0) {
      await admin.storage.from(BUCKET).remove(paths);
      files += paths.length;
    }
  }

  return json({ expiredPosts: expired?.length ?? 0, filesRemoved: files });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
