// Pure helpers for the feedback board (no DOM, no network) — tested with `node --test Web/feedback`.
// Limits mirror Backend/supabase/migrations/20261123000000_feedback.sql.

export const LIMITS = Object.freeze({ titleMin: 3, titleMax: 80, bodyMax: 1000, reasonMax: 500 });
export const CATEGORIES = Object.freeze(["feature", "bug", "mission", "sound", "other"]);
export const LANGUAGES = Object.freeze(["en", "nl", "de", "fr", "es", "it", "pt-BR", "pt-PT"]);
export const SORTS = Object.freeze(["top", "new"]);

/** "fr-BE" → "fr", "pt" → "pt-PT", "pt-br" → "pt-BR", unknown → null. */
export function matchLanguage(code) {
  if (typeof code !== "string" || !code.trim()) return null;
  const parts = code.trim().replace("_", "-").split("-");
  const base = parts[0].toLowerCase();
  if (base === "pt") {
    const region = (parts[1] || "").toUpperCase();
    return region === "BR" ? "pt-BR" : "pt-PT";
  }
  return LANGUAGES.includes(base) ? base : null;
}

/** `?lang=` wins (set by the app), then the browser's languages, then English. */
export function pickLanguage(queryLang, browserLanguages = []) {
  for (const code of [queryLang, ...browserLanguages]) {
    const match = matchLanguage(code);
    if (match) return match;
  }
  return "en";
}

/** Fills `{name}` placeholders; unknown keys fall back to English, then to the key itself. */
export function translate(strings, fallback, key, values = {}) {
  const text = strings?.[key] ?? fallback?.[key] ?? key;
  return text.replace(/\{(\w+)\}/g, (all, name) => (name in values ? String(values[name]) : all));
}

/** Trimmed input + the i18n key of the first problem (null when it can be posted). */
export function validatePost({ title = "", body = "", category = "" } = {}) {
  const t = title.trim();
  const b = body.trim();
  let error = null;
  if (t.length < LIMITS.titleMin) error = "error_title_short";
  else if (t.length > LIMITS.titleMax || b.length > LIMITS.bodyMax) error = "error_too_long";
  else if (!CATEGORIES.includes(category)) error = "error_category";
  return { title: t, body: b, category, error };
}

/** Clicking ▲ (1) or ▼ (-1): same arrow again removes the vote. */
export function nextVote(current, clicked) {
  return current === clicked ? 0 : clicked;
}

/** Optimistic update of a list row after voting; returns a new object. */
export function applyVote(post, value) {
  const up = post.up - (post.my_vote === 1 ? 1 : 0) + (value === 1 ? 1 : 0);
  const down = post.down - (post.my_vote === -1 ? 1 : 0) + (value === -1 ? 1 : 0);
  return { ...post, up, down, score: up - down, my_vote: value };
}

/** Same order as the server: top = score then newest, new = newest. */
export function sortPosts(posts, sort) {
  const byDate = (a, b) => Date.parse(b.created_at) - Date.parse(a.created_at);
  return [...posts].sort(sort === "new" ? byDate : (a, b) => b.score - a.score || byDate(a, b));
}

/** Seconds until a JWT expires (negative = expired, null = unreadable). */
export function jwtSecondsLeft(token, nowMs = Date.now()) {
  try {
    const payload = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const json = JSON.parse(globalThis.atob(payload.padEnd(payload.length + ((4 - (payload.length % 4)) % 4), "=")));
    return typeof json.exp === "number" ? json.exp - Math.floor(nowMs / 1000) : null;
  } catch {
    return null;
  }
}

/** Token needs replacing when it expires within `marginSeconds`. */
export function tokenNeedsRefresh(token, nowMs = Date.now(), marginSeconds = 60) {
  if (!token) return true;
  const left = jwtSecondsLeft(token, nowMs);
  return left === null || left < marginSeconds;
}

/** Server messages (errcode P0001, English) → i18n keys; unknown → generic. */
export function errorKey(error) {
  const message = (error && (error.message || String(error))) || "";
  const known = [
    [/at least 3 characters/i, "error_title_short"],
    [/bit long/i, "error_too_long"],
    [/pick a category/i, "error_category"],
    [/posted a lot today/i, "error_rate_limited"],
    [/isn.t available any more/i, "error_gone"],
    [/not signed in|JWT|401/i, "error_signed_out"],
    [/invalid login credentials/i, "error_credentials"],
    [/email not confirmed/i, "error_confirm_email"],
  ];
  for (const [pattern, key] of known) if (pattern.test(message)) return key;
  return "error_generic";
}

/** Characters left in a field, for the counter under it. */
export function charsLeft(text, max) {
  return max - (text || "").trim().length;
}

/** Escapes text for innerHTML. */
export function escapeHTML(text) {
  return String(text ?? "").replace(/[&<>"']/g, (c) =>
    ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

/** Inline Markdown for the legal documents: **bold**, *italic*, [text](url), bare emails. */
function inline(text) {
  return escapeHTML(text)
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\*(.+?)\*/g, "<em>$1</em>")
    .replace(/\[([^\]]+)\]\((https?:\/\/[^)\s]+|mailto:[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>')
    .replace(/(^|[\s(])([\w.+-]+@[\w-]+\.[\w.-]+\w)/g, '$1<a href="mailto:$2">$2</a>');
}

/** Same subset as the app's LegalDocument parser: `#` title, `##` headings, `-` bullets, paragraphs. */
export function markdownToHTML(markdown) {
  const html = [];
  let list = null;
  let paragraph = [];
  const flush = () => {
    if (paragraph.length) html.push(`<p>${inline(paragraph.join(" "))}</p>`);
    paragraph = [];
    if (list) html.push(`<ul>${list.map((item) => `<li>${inline(item)}</li>`).join("")}</ul>`);
    list = null;
  };
  for (const raw of String(markdown).split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) { flush(); continue; }
    if (line.startsWith("## ")) { flush(); html.push(`<h3>${inline(line.slice(3))}</h3>`); continue; }
    if (line.startsWith("# ")) { flush(); html.push(`<h2>${inline(line.slice(2))}</h2>`); continue; }
    if (line.startsWith("- ")) {
      if (paragraph.length) { html.push(`<p>${inline(paragraph.join(" "))}</p>`); paragraph = []; }
      (list ??= []).push(line.slice(2));
      continue;
    }
    if (list) { list[list.length - 1] += " " + line; continue; }
    paragraph.push(line);
  }
  flush();
  return html.join("\n");
}

/** Legal file for a language: community.nl.md, pt-BR → community.pt.md, English = community.md. */
export function legalPath(doc, language) {
  const base = (language || "en").split("-")[0];
  return base === "en" ? `../legal/${doc}.md` : `../legal/${doc}.${base}.md`;
}
