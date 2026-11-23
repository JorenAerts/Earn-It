// Gloop feedback board. Talks to Supabase RPCs from 20261123000000_feedback.sql.
// Embedded mode (?embed=1, opened by the iOS app in a WKWebView): the app injects its access token
// (window.__gloopEmbed.accessToken) and hands out fresh ones on request; the page never sees or
// rotates the refresh token. Standalone: normal Supabase sign-in, session kept in localStorage.
import {
  CATEGORIES, LIMITS, applyVote, charsLeft, errorKey, escapeHTML, legalPath, markdownToHTML,
  nextVote, pickLanguage, sortPosts, tokenNeedsRefresh, translate, validatePost,
} from "./logic.js";

const PAGE_SIZE = 30;
const params = new URLSearchParams(location.search);
const embedded = params.get("embed") === "1";
const config = window.GLOOP_CONFIG || {};
const $ = (selector, root = document) => root.querySelector(selector);

const state = {
  language: pickLanguage(params.get("lang"), navigator.languages || [navigator.language]),
  strings: {},
  english: {},
  sort: "top",
  category: null,
  search: "",
  posts: [],
  hasMore: false,
  loading: false,
  targetPost: null,
};

const t = (key, values) => translate(state.strings, state.english, key, values);

// ---------------------------------------------------------------------------------------------
// Session handed over by the app

let embedToken = window.__gloopEmbed?.accessToken || null;
let pendingToken = null;

/** Called by the app (evaluateJavaScript) with a fresh access token. */
window.gloopReceiveSession = (token) => {
  embedToken = token || null;
  pendingToken?.resolve(embedToken);
  pendingToken = null;
};

function askAppForToken() {
  const bridge = window.webkit?.messageHandlers?.gloop;
  if (!bridge) return Promise.resolve(null);
  if (!pendingToken) {
    let resolve;
    const promise = new Promise((r) => { resolve = r; });
    pendingToken = { promise, resolve };
    bridge.postMessage({ type: "needsSession" });
    setTimeout(() => pendingToken?.resolve(null), 10000);
  }
  return pendingToken.promise;
}

async function embedAccessToken() {
  if (tokenNeedsRefresh(embedToken)) embedToken = await askAppForToken();
  return embedToken;
}

// ---------------------------------------------------------------------------------------------
// Supabase

function makeClient() {
  if (!config.supabaseUrl || !config.publishableKey || !window.supabase) return null;
  const options = embedded
    ? { accessToken: embedAccessToken }
    : { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } };
  return window.supabase.createClient(config.supabaseUrl, config.publishableKey, options);
}
const client = makeClient();

async function rpc(name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error) throw error;
  return data;
}

// ---------------------------------------------------------------------------------------------
// i18n

async function loadStrings(code) {
  const response = await fetch(`i18n/${code}.json`, { cache: "no-cache" });
  if (!response.ok) throw new Error(`i18n ${code}`);
  return response.json();
}

async function setupLanguage() {
  try { state.english = await loadStrings("en"); } catch { state.english = {}; }
  try {
    state.strings = state.language === "en" ? state.english : await loadStrings(state.language);
  } catch {
    state.strings = state.english;
    state.language = "en";
  }
  document.documentElement.lang = state.language;
  document.title = t("page_title");
  for (const el of document.querySelectorAll("[data-i18n]")) el.textContent = t(el.dataset.i18n);
  for (const el of document.querySelectorAll("[data-i18n-placeholder]")) el.placeholder = t(el.dataset.i18nPlaceholder);
  for (const el of document.querySelectorAll("[data-provider]")) {
    el.textContent = t("signin_with", { provider: el.dataset.provider === "apple" ? "Apple" : "Google" });
  }
  $("#consent").innerHTML = escapeHTML(t("consent", { link: "\u0000" }))
    .replace("\u0000", `<button type="button" class="link" data-legal="community">${escapeHTML(t("community"))}</button>`);
  const select = $("#post-form select[name=category]");
  select.innerHTML = CATEGORIES.map((c) => `<option value="${c}">${escapeHTML(t(`cat_${c}`))}</option>`).join("");
  renderChips();
}

// ---------------------------------------------------------------------------------------------
// UI helpers

let toastTimer;
function toast(message) {
  const el = $("#toast");
  el.textContent = message;
  el.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => { el.hidden = true; }, 3200);
}

function showError(el, error) {
  el.textContent = typeof error === "string" ? error : t(errorKey(error));
  el.hidden = false;
}

const relative = () => new Intl.RelativeTimeFormat(state.language, { numeric: "auto" });
function ago(iso) {
  const seconds = (Date.parse(iso) - Date.now()) / 1000;
  const units = [["year", 31536000], ["month", 2592000], ["week", 604800], ["day", 86400], ["hour", 3600], ["minute", 60]];
  for (const [unit, size] of units) if (Math.abs(seconds) >= size) return relative().format(Math.round(seconds / size), unit);
  return relative().format(0, "minute");
}

function renderChips() {
  const all = [null, ...CATEGORIES];
  $("#chips").innerHTML = all.map((c) =>
    `<button type="button" class="chip" data-category="${c ?? ""}" aria-pressed="${state.category === c}">` +
    `${escapeHTML(t(c ? `cat_${c}` : "cat_all"))}</button>`).join("");
}

function renderTabs() {
  for (const tab of document.querySelectorAll("[data-sort]")) tab.setAttribute("aria-selected", String(tab.dataset.sort === state.sort));
}

function postHTML(post) {
  const body = post.body ? `<p>${escapeHTML(post.body)}</p>` : "";
  const mine = post.is_mine ? `<span class="tag mine">${escapeHTML(t("yours"))}</span>` : "";
  const menu = post.is_mine
    ? `<button type="button" class="danger" data-action="delete">${escapeHTML(t("delete"))}</button>`
    : `<button type="button" data-action="report">${escapeHTML(t("report"))}</button>`;
  return `<li class="card post${post.is_mine ? " mine" : ""}" data-id="${post.id}">
    <div class="vote">
      <button type="button" class="up" data-vote="1" aria-pressed="${post.my_vote === 1}" aria-label="${escapeHTML(t("upvote"))}">▲</button>
      <span class="score" aria-label="${escapeHTML(t("score", { n: post.score }))}" title="${escapeHTML(t("votes", { up: post.up, down: post.down }))}">${post.score}</span>
      <button type="button" class="down" data-vote="-1" aria-pressed="${post.my_vote === -1}" aria-label="${escapeHTML(t("downvote"))}">▼</button>
    </div>
    <div class="content">
      <h3>${escapeHTML(post.title)}</h3>
      ${body}
      <div class="meta"><span class="tag">${escapeHTML(t(`cat_${post.category}`))}</span>${mine}<span>${escapeHTML(ago(post.created_at))}</span></div>
    </div>
    <div class="menu">
      <button type="button" data-action="menu" aria-label="${escapeHTML(t("more"))}" aria-haspopup="true">⋯</button>
      <div class="menu-items" hidden>${menu}</div>
    </div>
  </li>`;
}

function renderList() {
  const list = $("#list");
  list.innerHTML = state.posts.map(postHTML).join("");
  $("#more").hidden = !state.hasMore;
  const status = $("#status");
  if (state.loading && !state.posts.length) status.textContent = t("loading");
  else if (!state.posts.length) status.textContent = t(state.search ? "empty_search" : "empty");
  else status.textContent = "";
}

// ---------------------------------------------------------------------------------------------
// Data

let loadToken = 0;
async function load({ append = false } = {}) {
  const token = ++loadToken;
  state.loading = true;
  if (!append) renderList();
  try {
    const rows = await rpc("feedback_list", {
      sort: state.sort, cat: state.category, search: state.search || null,
      lim: PAGE_SIZE + 1, off: append ? state.posts.length : 0,
    });
    if (token !== loadToken) return;
    state.hasMore = rows.length > PAGE_SIZE;
    const page = rows.slice(0, PAGE_SIZE);
    state.posts = append ? [...state.posts, ...page] : page;
  } catch (error) {
    if (token !== loadToken) return;
    state.loading = false;
    if (errorKey(error) === "error_signed_out" && !embedded) return showSignIn();
    $("#status").textContent = t(errorKey(error));
    return;
  }
  state.loading = false;
  renderList();
}

async function vote(id, clicked) {
  const index = state.posts.findIndex((p) => p.id === id);
  if (index < 0) return;
  const before = state.posts[index];
  const value = nextVote(before.my_vote, clicked);
  state.posts[index] = applyVote(before, value);
  renderList();
  try {
    await rpc("feedback_vote", { post: id, value });
  } catch (error) {
    state.posts[index] = before;
    renderList();
    toast(t(errorKey(error)));
  }
}

// ---------------------------------------------------------------------------------------------
// Dialogs

function openDialog(id) {
  const dialog = $(id);
  for (const el of dialog.querySelectorAll(".error")) el.hidden = true;
  dialog.showModal();
  return dialog;
}

function updateCounters(form) {
  for (const counter of form.querySelectorAll(".counter")) {
    const field = form.elements[counter.dataset.for];
    const max = counter.dataset.for === "title" ? LIMITS.titleMax : LIMITS.bodyMax;
    const left = charsLeft(field.value, max);
    counter.textContent = left <= Math.min(40, max / 4) ? t("chars_left", { n: left }) : "";
  }
}

let similarTimer;
function findSimilar(title) {
  clearTimeout(similarTimer);
  const box = $("#similar");
  if (title.trim().length < 4) { box.hidden = true; return; }
  similarTimer = setTimeout(async () => {
    try {
      const rows = await rpc("feedback_list", { sort: "top", cat: null, search: title.trim(), lim: 3, off: 0 });
      if (!rows.length) { box.hidden = true; return; }
      box.innerHTML = `${escapeHTML(t("similar"))}<ul>${rows.map((r) =>
        `<li>${escapeHTML(r.title)} <span class="muted">(${r.score})</span></li>`).join("")}</ul>`;
      box.hidden = false;
    } catch { box.hidden = true; }
  }, 400);
}

async function showLegal(doc) {
  const dialog = openDialog("#legal-dialog");
  const body = $(".legal-body", dialog);
  body.textContent = t("loading");
  for (const path of [legalPath(doc, state.language), legalPath(doc, "en")]) {
    try {
      const response = await fetch(path);
      if (!response.ok) continue;
      body.innerHTML = markdownToHTML(await response.text());
      return;
    } catch { /* try English */ }
  }
  body.textContent = t("error_generic");
}

// ---------------------------------------------------------------------------------------------
// Auth (standalone)

function showSignIn() {
  $("#signin").hidden = false;
  $("#board").hidden = true;
  $("#account").hidden = true;
}

async function showBoard(email) {
  $("#signin").hidden = true;
  $("#board").hidden = false;
  const account = $("#account");
  if (email && !embedded) {
    account.innerHTML = `<span>${escapeHTML(t("signed_in_as", { email }))}</span>` +
      `<button type="button" class="link" id="signout">${escapeHTML(t("signout"))}</button>`;
    account.hidden = false;
  }
  renderTabs();
  await load();
}

// ---------------------------------------------------------------------------------------------
// Events

function wire() {
  document.addEventListener("click", (event) => {
    const target = event.target.closest("button");
    // Close any open ⋯ menu on outside clicks.
    for (const menu of document.querySelectorAll(".menu-items")) {
      if (!target || !menu.parentElement.contains(target)) menu.hidden = true;
    }
    if (!target) return;
    if (target.dataset.close !== undefined) return target.closest("dialog").close();
    if (target.dataset.legal) return showLegal(target.dataset.legal);
    if (target.id === "signout") return client.auth.signOut().then(showSignIn);
    if (target.dataset.provider) {
      return client.auth.signInWithOAuth({
        provider: target.dataset.provider,
        options: { redirectTo: location.origin + location.pathname },
      });
    }
    if (target.dataset.sort) {
      state.sort = target.dataset.sort;
      state.posts = sortPosts(state.posts, state.sort);
      renderTabs();
      return load();
    }
    if (target.dataset.category !== undefined) {
      state.category = target.dataset.category || null;
      renderChips();
      return load();
    }
    if (target.id === "suggest") {
      const form = $("#post-form");
      form.reset();
      $("#similar").hidden = true;
      updateCounters(form);
      if (state.category) form.elements.category.value = state.category;
      openDialog("#form-dialog");
      return form.elements.title.focus();
    }
    if (target.id === "more") return load({ append: true });
    const item = target.closest(".post");
    if (!item) return;
    if (target.dataset.vote) return vote(item.dataset.id, Number(target.dataset.vote));
    if (target.dataset.action === "menu") {
      const menu = $(".menu-items", item);
      menu.hidden = !menu.hidden;
      return;
    }
    state.targetPost = item.dataset.id;
    if (target.dataset.action === "report") { $("#report-form").reset(); openDialog("#report-dialog"); }
    if (target.dataset.action === "delete") openDialog("#delete-dialog");
  });

  let searchTimer;
  $("#search").addEventListener("input", (event) => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => { state.search = event.target.value.trim(); load(); }, 300);
  });

  const postForm = $("#post-form");
  postForm.addEventListener("input", (event) => {
    updateCounters(postForm);
    if (event.target.name === "title") findSimilar(event.target.value);
  });
  postForm.addEventListener("submit", async (event) => {
    event.preventDefault();
    const error = $(".error", postForm);
    const input = validatePost({
      title: postForm.elements.title.value, body: postForm.elements.body.value,
      category: postForm.elements.category.value,
    });
    if (input.error) return showError(error, t(input.error));
    const submit = $("button[type=submit]", postForm);
    submit.disabled = true;
    try {
      await rpc("feedback_submit", { title: input.title, body: input.body, category: input.category });
      $("#form-dialog").close();
      toast(t("posted"));
      state.sort = "new";
      state.search = "";
      $("#search").value = "";
      renderTabs();
      await load();
    } catch (e) {
      showError(error, e);
    } finally {
      submit.disabled = false;
    }
  });

  $("#report-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const reason = event.target.elements.reason.value.trim().slice(0, LIMITS.reasonMax);
    $("#report-dialog").close();
    try {
      await rpc("feedback_report", { post: state.targetPost, reason });
      toast(t("reported"));
    } catch (error) { toast(t(errorKey(error))); }
  });

  $("#delete-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    $("#delete-dialog").close();
    try {
      await rpc("feedback_delete_own", { post: state.targetPost });
      state.posts = state.posts.filter((p) => p.id !== state.targetPost);
      renderList();
      toast(t("deleted"));
    } catch (error) { toast(t(errorKey(error))); }
  });

  $("#signin-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = event.target;
    const error = $(".error", form);
    error.hidden = true;
    const { error: failure } = await client.auth.signInWithPassword({
      email: form.elements.email.value.trim(), password: form.elements.password.value,
    });
    if (failure) showError(error, failure);
  });
}

// ---------------------------------------------------------------------------------------------
// Start

async function start() {
  if (embedded) document.body.classList.add("embed");
  await setupLanguage();
  wire();
  if (!client) {
    $("#status").textContent = t("error_not_configured");
    $("#board").hidden = false;
    $("#suggest").hidden = true;
    return;
  }
  if (embedded) {
    if (!(await embedAccessToken())) {
      $("#board").hidden = false;
      $("#suggest").hidden = true;
      $("#status").textContent = t("error_signed_out");
      return;
    }
    return showBoard(null);
  }
  const { data } = await client.auth.getSession();
  if (data.session) await showBoard(data.session.user.email);
  else showSignIn();
  client.auth.onAuthStateChange((event, session) => {
    if (event === "SIGNED_IN" && $("#board").hidden) showBoard(session?.user?.email);
    if (event === "SIGNED_OUT") showSignIn();
  });
}

start();
