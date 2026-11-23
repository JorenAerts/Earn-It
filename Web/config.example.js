// Copy to Web/config.js for local testing (git-ignored). On GitHub Pages the workflow
// (.github/workflows/pages.yml) writes it from the repo secrets SUPABASE_URL and
// SUPABASE_PUBLISHABLE_KEY. Publishable key only — never an sb_secret_… key.
window.GLOOP_CONFIG = {
  supabaseUrl: "https://<project-ref>.supabase.co",
  publishableKey: "sb_publishable_…",
};
