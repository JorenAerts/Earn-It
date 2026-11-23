// node --test Web/feedback/logic.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import {
  CATEGORIES, LANGUAGES, applyVote, charsLeft, errorKey, escapeHTML, jwtSecondsLeft, legalPath,
  markdownToHTML, matchLanguage, nextVote, pickLanguage, sortPosts, tokenNeedsRefresh, translate,
  validatePost,
} from "./logic.js";

const i18n = new URL("./i18n/", import.meta.url);

test("language: query wins, then browser, then English", () => {
  assert.equal(pickLanguage("nl", ["fr-FR"]), "nl");
  assert.equal(pickLanguage(null, ["xx", "de-AT"]), "de");
  assert.equal(pickLanguage("zz", ["xx"]), "en");
  assert.equal(matchLanguage("pt-br"), "pt-BR");
  assert.equal(matchLanguage("pt_BR"), "pt-BR");
  assert.equal(matchLanguage("pt"), "pt-PT");
  assert.equal(matchLanguage("fr-BE"), "fr");
  assert.equal(matchLanguage(""), null);
});

test("translate fills placeholders and falls back to English", () => {
  assert.equal(translate({ a: "Hoi {name}" }, {}, "a", { name: "Jo" }), "Hoi Jo");
  assert.equal(translate({}, { a: "Hi" }, "a"), "Hi");
  assert.equal(translate({}, {}, "missing"), "missing");
  assert.equal(translate({ a: "{x} {y}" }, {}, "a", { x: 1 }), "1 {y}");
});

test("every language file has exactly the English keys and the same placeholders", () => {
  const english = JSON.parse(readFileSync(new URL("en.json", i18n)));
  const files = readdirSync(i18n).filter((f) => f.endsWith(".json")).sort();
  assert.deepEqual(files, LANGUAGES.map((c) => `${c}.json`).sort());
  const placeholders = (s) => (s.match(/\{\w+\}/g) || []).sort().join();
  for (const file of files) {
    const strings = JSON.parse(readFileSync(new URL(file, i18n)));
    assert.deepEqual(Object.keys(strings).sort(), Object.keys(english).sort(), file);
    for (const [key, value] of Object.entries(english)) {
      assert.equal(placeholders(strings[key]), placeholders(value), `${file} ${key}`);
      assert.ok(strings[key].trim(), `${file} ${key} empty`);
    }
    for (const category of CATEGORIES) assert.ok(strings[`cat_${category}`], `${file} cat_${category}`);
  }
});

test("post validation mirrors the SQL limits", () => {
  assert.equal(validatePost({ title: "  ab ", category: "feature" }).error, "error_title_short");
  assert.equal(validatePost({ title: "x".repeat(81), category: "feature" }).error, "error_too_long");
  assert.equal(validatePost({ title: "Good", body: "x".repeat(1001), category: "bug" }).error, "error_too_long");
  assert.equal(validatePost({ title: "Good", category: "nope" }).error, "error_category");
  const ok = validatePost({ title: "  Water plants ", body: " pls ", category: "mission" });
  assert.deepEqual(ok, { title: "Water plants", body: "pls", category: "mission", error: null });
});

test("voting toggles and updates the score optimistically", () => {
  assert.equal(nextVote(0, 1), 1);
  assert.equal(nextVote(1, 1), 0);
  assert.equal(nextVote(1, -1), -1);
  const post = { up: 3, down: 1, score: 2, my_vote: 1 };
  assert.deepEqual(applyVote(post, -1), { up: 2, down: 2, score: 0, my_vote: -1 });
  assert.deepEqual(applyVote(post, 0), { up: 2, down: 1, score: 1, my_vote: 0 });
  assert.deepEqual(applyVote({ up: 0, down: 0, score: 0, my_vote: 0 }, 1), { up: 1, down: 0, score: 1, my_vote: 1 });
});

test("sorting matches the server", () => {
  const posts = [
    { id: "a", score: 1, created_at: "2026-11-01T00:00:00Z" },
    { id: "b", score: 5, created_at: "2026-10-01T00:00:00Z" },
    { id: "c", score: 1, created_at: "2026-11-02T00:00:00Z" },
  ];
  assert.deepEqual(sortPosts(posts, "top").map((p) => p.id), ["b", "c", "a"]);
  assert.deepEqual(sortPosts(posts, "new").map((p) => p.id), ["c", "a", "b"]);
});

test("JWT expiry", () => {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const token = `${b64({ alg: "HS256" })}.${b64({ exp: 1000 })}.sig`;
  assert.equal(jwtSecondsLeft(token, 900_000), 100);
  assert.equal(tokenNeedsRefresh(token, 900_000), false);
  assert.equal(tokenNeedsRefresh(token, 950_000), true);
  assert.equal(tokenNeedsRefresh(null), true);
  assert.equal(tokenNeedsRefresh("garbage"), true);
});

test("server errors map to i18n keys", () => {
  assert.equal(errorKey({ message: "You've posted a lot today — try again tomorrow." }), "error_rate_limited");
  assert.equal(errorKey({ message: "not signed in" }), "error_signed_out");
  assert.equal(errorKey({ message: "Invalid login credentials" }), "error_credentials");
  assert.equal(errorKey(new Error("Failed to fetch")), "error_generic");
  assert.equal(errorKey(null), "error_generic");
});

test("escaping and counters", () => {
  assert.equal(escapeHTML(`<b a="1">&'</b>`), "&lt;b a=&quot;1&quot;&gt;&amp;&#39;&lt;/b&gt;");
  assert.equal(charsLeft("  abc  ", 80), 77);
});

test("legal markdown renders the app's subset safely", () => {
  const html = markdownToHTML("# Title\n\nIntro **bold**\n\n## Head\n\n- one\n- two <x>\n\nMail a@b.be");
  assert.match(html, /<h2>Title<\/h2>/);
  assert.match(html, /<strong>bold<\/strong>/);
  assert.match(html, /<h3>Head<\/h3>/);
  assert.match(html, /<li>two &lt;x&gt;<\/li>/);
  assert.match(html, /href="mailto:a@b.be"/);
  assert.equal(legalPath("community", "pt-BR"), "../legal/community.pt.md");
  assert.equal(legalPath("privacy", "en"), "../legal/privacy.md");
});

test("the real legal docs render", () => {
  const legal = new URL("../../docs/legal/", import.meta.url);
  for (const file of ["community.md", "privacy.md"]) {
    const html = markdownToHTML(readFileSync(new URL(file, legal), "utf8"));
    assert.match(html, /^<h2>/);
  }
});
