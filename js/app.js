(() => {
  "use strict";

  const API = "https://api.github.com";
  const CACHE_MS = 10 * 60 * 1000; // reuse API responses for 10 minutes
  const DAY = 86400000;

  // ---------- Storage helpers (never let storage errors break the page) ----------
  const store = {
    get(k, area = localStorage) { try { return area.getItem(k); } catch { return null; } },
    set(k, v, area = localStorage) { try { area.setItem(k, v); } catch { /* ignore */ } },
    del(k, area = localStorage) { try { area.removeItem(k); } catch { /* ignore */ } },
  };

  // ---------- DOM ----------
  const $ = (sel) => document.querySelector(sel);
  const el = {
    form: $("#load-form"), user: $("#username"),
    settingsBtn: $("#settings-btn"), settings: $("#settings"),
    token: $("#token"), saveToken: $("#save-token"), clearToken: $("#clear-token"),
    status: $("#status"), empty: $("#empty"), dash: $("#dashboard"),
    profile: $("#profile"), stats: $("#stats"),
    langBar: $("#lang-bar"), langLegend: $("#lang-legend"), langNote: $("#lang-note"),
    search: $("#search"), type: $("#filter-type"), lang: $("#filter-lang"),
    sort: $("#sort"), group: $("#group"), viewBtns: document.querySelectorAll("[data-view]"),
    count: $("#result-count"), repos: $("#repos"), rate: $("#rate"),
  };

  const state = {
    repos: [],
    owner: null,
    view: store.get("rd:view") === "list" ? "list" : "grid",
  };

  // ---------- Language colors (subset of GitHub's linguist palette) ----------
  const LANG_COLORS = {
    JavaScript: "#f1e05a", TypeScript: "#3178c6", Python: "#3572A5", Java: "#b07219",
    "C#": "#178600", "C++": "#f34b7d", C: "#555555", Go: "#00ADD8", Rust: "#dea584",
    Ruby: "#701516", PHP: "#4F5D95", Swift: "#F05138", Kotlin: "#A97BFF", Dart: "#00B4AB",
    HTML: "#e34c26", CSS: "#563d7c", SCSS: "#c6538c", Vue: "#41b883", Svelte: "#ff3e00",
    Shell: "#89e051", PowerShell: "#012456", Lua: "#000080", R: "#198CE7", Scala: "#c22d40",
    Elixir: "#6e4a7e", Haskell: "#5e5086", "Objective-C": "#438eff", Perl: "#0298c3",
    "Jupyter Notebook": "#DA5B0B", Dockerfile: "#384d54", HCL: "#844FBA", Nix: "#7e7eff",
    Zig: "#ec915c", Clojure: "#db5855", "F#": "#b845fc", Julia: "#a270ba", MDX: "#fcb32c",
    Astro: "#ff5a03", Makefile: "#427819", CMake: "#DA3434", GDScript: "#355570",
    Solidity: "#AA6746", Assembly: "#6E4C13", "Vim Script": "#199f4b", TeX: "#3D6117",
  };
  const NO_LANG = "No language";
  function langColor(name) {
    if (!name || name === NO_LANG) return "#8b949e";
    if (LANG_COLORS[name]) return LANG_COLORS[name];
    let h = 0;
    for (const ch of name) h = (h * 31 + ch.charCodeAt(0)) >>> 0;
    return `hsl(${h % 360} 55% 52%)`;
  }

  // ---------- Formatting ----------
  const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
  const nf = new Intl.NumberFormat();
  const compact = new Intl.NumberFormat(undefined, { notation: "compact", maximumFractionDigits: 1 });
  const rtf = new Intl.RelativeTimeFormat(undefined, { numeric: "auto" });
  function ago(iso) {
    if (!iso) return "never";
    const diff = (new Date(iso).getTime() - Date.now()) / 1000;
    const units = [["year", 31536000], ["month", 2592000], ["week", 604800], ["day", 86400], ["hour", 3600], ["minute", 60]];
    for (const [u, s] of units) if (Math.abs(diff) >= s) return rtf.format(Math.round(diff / s), u);
    return "just now";
  }
  const ageDays = (iso) => (iso ? (Date.now() - new Date(iso).getTime()) / DAY : Infinity);

  function activityOf(repo) {
    if (repo.archived) return { key: "archived", label: "Archived", order: 4, cls: "act-cold" };
    const d = ageDays(repo.pushed_at);
    if (d <= 30) return { key: "active", label: "Active (last 30 days)", order: 0, cls: "act-hot" };
    if (d <= 180) return { key: "recent", label: "Recent (last 6 months)", order: 1, cls: "act-warm" };
    if (d <= 365) return { key: "quiet", label: "Quiet (last year)", order: 2, cls: "act-cold" };
    return { key: "dormant", label: "Dormant (over a year)", order: 3, cls: "act-cold" };
  }

  // ---------- Icons ----------
  const ICON = {
    star: '<svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path d="M8 .25a.75.75 0 0 1 .673.418l1.882 3.815 4.21.612a.75.75 0 0 1 .416 1.279l-3.046 2.97.719 4.192a.751.751 0 0 1-1.088.791L8 12.347l-3.766 1.98a.75.75 0 0 1-1.088-.79l.72-4.194L.818 6.374a.75.75 0 0 1 .416-1.28l4.21-.611L7.327.668A.75.75 0 0 1 8 .25Z"/></svg>',
    fork: '<svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path d="M5 5.372v.878c0 .414.336.75.75.75h4.5a.75.75 0 0 0 .75-.75v-.878a2.25 2.25 0 1 1 1.5 0v.878a2.25 2.25 0 0 1-2.25 2.25h-1.5v2.128a2.251 2.251 0 1 1-1.5 0V8.5h-1.5A2.25 2.25 0 0 1 3.5 6.25v-.878a2.25 2.25 0 1 1 1.5 0ZM5 3.25a.75.75 0 1 0-1.5 0 .75.75 0 0 0 1.5 0Zm6.75.75a.75.75 0 1 0 0-1.5.75.75 0 0 0 0 1.5Zm-3 8.75a.75.75 0 1 0-1.5 0 .75.75 0 0 0 1.5 0Z"/></svg>',
    issue: '<svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path d="M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Z"/><path d="M8 0a8 8 0 1 1 0 16A8 8 0 0 1 8 0ZM1.5 8a6.5 6.5 0 1 0 13 0 6.5 6.5 0 0 0-13 0Z"/></svg>',
    link: '<svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true"><path d="m7.775 3.275 1.25-1.25a3.5 3.5 0 1 1 4.95 4.95l-2.5 2.5a3.5 3.5 0 0 1-4.95 0 .751.751 0 0 1 .018-1.042.751.751 0 0 1 1.042-.018 1.998 1.998 0 0 0 2.83 0l2.5-2.5a2.002 2.002 0 0 0-2.83-2.83l-1.25 1.25a.751.751 0 0 1-1.042-.018.751.751 0 0 1-.018-1.042Zm-4.69 9.64a1.998 1.998 0 0 0 2.83 0l1.25-1.25a.751.751 0 0 1 1.042.018.751.751 0 0 1 .018 1.042l-1.25 1.25a3.5 3.5 0 1 1-4.95-4.95l2.5-2.5a3.5 3.5 0 0 1 4.95 0 .751.751 0 0 1-.018 1.042.751.751 0 0 1-1.042.018 1.998 1.998 0 0 0-2.83 0l-2.5 2.5a1.998 1.998 0 0 0 0 2.83Z"/></svg>',
  };

  // ---------- GitHub API ----------
  const getToken = () => store.get("rd:token") || "";

  async function gh(path) {
    const token = getToken();
    const cacheKey = `rd:cache:${token ? "auth" : "anon"}:${path}`;
    const cached = store.get(cacheKey, sessionStorage);
    if (cached) {
      try {
        const { t, data, next } = JSON.parse(cached);
        if (Date.now() - t < CACHE_MS) return { data, next };
      } catch { /* fall through */ }
    }
    const headers = { Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" };
    if (token) headers.Authorization = `Bearer ${token}`;
    const res = await fetch(path.startsWith("http") ? path : API + path, { headers });
    updateRate(res);
    if (!res.ok) {
      let msg = `GitHub returned ${res.status}`;
      if (res.status === 404) msg = "No GitHub user or organization by that name.";
      else if (res.status === 401) msg = "The saved token was rejected. Check it in Settings, or clear it.";
      else if (res.status === 403 || res.status === 429) {
        const reset = res.headers.get("x-ratelimit-reset");
        msg = res.headers.get("x-ratelimit-remaining") === "0"
          ? `GitHub's rate limit is used up${reset ? `; it resets ${ago(new Date(reset * 1000).toISOString())}` : ""}. Adding a token in Settings raises the limit.`
          : "GitHub refused the request (403).";
      }
      const err = new Error(msg);
      err.status = res.status;
      throw err;
    }
    const data = await res.json();
    const link = res.headers.get("link") || "";
    const next = (link.match(/<([^>]+)>;\s*rel="next"/) || [])[1] || null;
    store.set(cacheKey, JSON.stringify({ t: Date.now(), data, next }), sessionStorage);
    return { data, next };
  }

  async function ghAll(path, onPage) {
    let url = path, all = [];
    while (url) {
      const { data, next } = await gh(url);
      all = all.concat(data);
      onPage?.(all.length);
      url = next;
    }
    return all;
  }

  function updateRate(res) {
    const rem = res.headers.get("x-ratelimit-remaining");
    const lim = res.headers.get("x-ratelimit-limit");
    if (rem && lim) el.rate.textContent = `GitHub API: ${rem} of ${lim} requests left this hour${getToken() ? " (authenticated)" : ""}`;
  }

  async function loadOwner(name) {
    name = name.trim().replace(/^@/, "").replace(/^https?:\/\/github\.com\//i, "").split("/")[0];
    if (!name) return;
    el.user.value = name;
    const url = new URL(location.href);
    url.searchParams.set("user", name);
    history.replaceState(null, "", url);
    document.title = `${name} · Repo Dashboard`;

    setStatus(`Loading ${esc(name)}…`);
    el.empty.hidden = true;
    el.dash.hidden = false;
    el.profile.innerHTML = "";
    el.stats.innerHTML = "";
    el.repos.className = "grid";
    el.repos.innerHTML = Array.from({ length: 6 }, () => '<div class="card skeleton"></div>').join("");

    try {
      const { data: owner } = await gh(`/users/${encodeURIComponent(name)}`);
      let path;
      let me = null;
      if (getToken()) {
        try { me = (await gh("/user")).data; } catch { me = null; }
      }
      if (me && me.login.toLowerCase() === owner.login.toLowerCase()) {
        // Token belongs to this user: include private repos and ones they collaborate on.
        path = "/user/repos?per_page=100&affiliation=owner,collaborator,organization_member&sort=pushed";
      } else if (owner.type === "Organization") {
        path = `/orgs/${encodeURIComponent(owner.login)}/repos?per_page=100&type=all&sort=pushed`;
      } else {
        path = `/users/${encodeURIComponent(owner.login)}/repos?per_page=100&type=owner&sort=pushed`;
      }
      const repos = await ghAll(path, (n) => setStatus(`Loading ${esc(owner.login)}… ${n} repositories so far`));
      state.owner = owner;
      state.repos = repos;
      setStatus("");
      renderProfile();
      renderStats();
      renderLanguages();
      populateLangFilter();
      render();
    } catch (err) {
      el.repos.innerHTML = "";
      el.dash.hidden = true;
      el.empty.hidden = false;
      setStatus(esc(err.message || String(err)), true);
    }
  }

  function setStatus(html, isError = false) {
    el.status.innerHTML = html;
    el.status.classList.toggle("error", isError);
  }

  // ---------- Rendering: summary ----------
  function renderProfile() {
    const o = state.owner;
    const sub = [o.type === "Organization" ? "Organization" : "User", o.bio, o.location].filter(Boolean).map(esc).join(" · ");
    el.profile.innerHTML = `
      <img src="${esc(o.avatar_url)}&s=128" alt="" width="64" height="64" />
      <div>
        <h1><a href="${esc(o.html_url)}" target="_blank" rel="noopener">${esc(o.name || o.login)}</a>
          ${o.name ? `<span class="muted" style="font-weight:400;font-size:16px">@${esc(o.login)}</span>` : ""}</h1>
        <p>${sub}</p>
      </div>`;
  }

  function renderStats() {
    const r = state.repos;
    const sum = (f) => r.reduce((a, x) => a + (f(x) || 0), 0);
    const langs = new Set(r.map((x) => x.language).filter(Boolean));
    const active = r.filter((x) => !x.archived && ageDays(x.pushed_at) <= 30).length;
    const tiles = [
      ["Repositories", nf.format(r.length)],
      ["Total stars", nf.format(sum((x) => x.stargazers_count))],
      ["Total forks", nf.format(sum((x) => x.forks_count))],
      ["Open issues & PRs", nf.format(sum((x) => x.open_issues_count))],
      ["Active this month", nf.format(active)],
      ["Languages", nf.format(langs.size)],
    ];
    el.stats.innerHTML = tiles.map(([l, v]) => `<div class="stat"><div class="label">${l}</div><div class="value">${v}</div></div>`).join("");
  }

  function langCounts() {
    const m = new Map();
    for (const r of state.repos) {
      const k = r.language || NO_LANG;
      m.set(k, (m.get(k) || 0) + 1);
    }
    return [...m.entries()].sort((a, b) => b[1] - a[1]);
  }

  function renderLanguages() {
    const counts = langCounts().filter(([k]) => k !== NO_LANG);
    const total = counts.reduce((a, [, n]) => a + n, 0);
    el.langNote.textContent = "Share of repositories by primary language";
    if (!total) {
      el.langBar.innerHTML = "";
      el.langLegend.innerHTML = '<li class="muted small">No language data.</li>';
      return;
    }
    const top = counts.slice(0, 8);
    const rest = counts.slice(8).reduce((a, [, n]) => a + n, 0);
    const parts = rest ? [...top, ["Other", rest]] : top;
    el.langBar.setAttribute("aria-label", parts.map(([k, n]) => `${k} ${Math.round((n / total) * 100)}%`).join(", "));
    el.langBar.innerHTML = parts.map(([k, n]) =>
      `<span style="flex:${n};background:${k === "Other" ? "var(--muted)" : langColor(k)}" title="${esc(k)}: ${n}"></span>`).join("");
    el.langLegend.innerHTML = parts.map(([k, n]) => {
      const pct = ((n / total) * 100).toFixed(n / total < 0.1 ? 1 : 0);
      const color = k === "Other" ? "var(--muted)" : langColor(k);
      const inner = `<span class="dot" style="background:${color}"></span><span class="lname">${esc(k)}</span> <span class="pct">${pct}% · ${n}</span>`;
      return k === "Other" ? `<li><span class="small" style="display:inline-flex;gap:6px;align-items:center">${inner}</span></li>`
        : `<li><button type="button" data-lang="${esc(k)}" title="Show only ${esc(k)}">${inner}</button></li>`;
    }).join("");
  }

  function populateLangFilter() {
    const prev = el.lang.value;
    el.lang.innerHTML = `<option value="">All languages</option>` +
      langCounts().map(([k, n]) => `<option value="${esc(k)}">${esc(k)} (${n})</option>`).join("");
    el.lang.value = [...el.lang.options].some((o) => o.value === prev) ? prev : "";
  }

  // ---------- Rendering: repo list ----------
  function filtered() {
    const q = el.search.value.trim().toLowerCase();
    const type = el.type.value;
    const lang = el.lang.value;
    return state.repos.filter((r) => {
      if (type === "sources" && r.fork) return false;
      if (type === "forks" && !r.fork) return false;
      if (type === "archived" && !r.archived) return false;
      if (type === "private" && !r.private) return false;
      if (type === "templates" && !r.is_template) return false;
      if (lang && (r.language || NO_LANG) !== lang) return false;
      if (q) {
        const hay = [r.name, r.full_name, r.description, ...(r.topics || [])].join(" ").toLowerCase();
        if (!q.split(/\s+/).every((w) => hay.includes(w))) return false;
      }
      return true;
    });
  }

  const SORTS = {
    pushed: (a, b) => new Date(b.pushed_at || 0) - new Date(a.pushed_at || 0),
    stars: (a, b) => b.stargazers_count - a.stargazers_count || SORTS.pushed(a, b),
    name: (a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }),
    created: (a, b) => new Date(b.created_at) - new Date(a.created_at),
    issues: (a, b) => b.open_issues_count - a.open_issues_count || SORTS.pushed(a, b),
    size: (a, b) => b.size - a.size,
  };

  function groupRepos(repos, mode) {
    if (mode === "none") return [{ key: "all", label: null, repos }];
    const groups = new Map();
    const add = (key, label, repo, extra = {}) => {
      if (!groups.has(key)) groups.set(key, { key, label, repos: [], ...extra });
      groups.get(key).repos.push(repo);
    };
    for (const r of repos) {
      if (mode === "language") add(r.language || NO_LANG, r.language || NO_LANG, r, { color: langColor(r.language) });
      else if (mode === "activity") { const a = activityOf(r); add(a.key, a.label, r, { order: a.order, cls: a.cls }); }
      else if (mode === "owner") add(r.owner.login, r.owner.login, r);
      else if (mode === "topic") {
        const t = r.topics?.length ? r.topics : ["(no topics)"];
        for (const topic of t) add(topic, topic, r);
      }
    }
    let list = [...groups.values()];
    if (mode === "activity") list.sort((a, b) => a.order - b.order);
    else list.sort((a, b) => {
      const tail = (g) => g.key === NO_LANG || g.key === "(no topics)";
      return tail(a) - tail(b) || b.repos.length - a.repos.length || a.label.localeCompare(b.label);
    });
    return list;
  }

  function card(r) {
    const act = activityOf(r);
    const ownerPrefix = state.owner && r.owner.login.toLowerCase() !== state.owner.login.toLowerCase()
      ? `<span class="owner">${esc(r.owner.login)} / </span>` : "";
    const badges = [
      r.private && '<span class="badge private">Private</span>',
      r.archived && '<span class="badge archived">Archived</span>',
      r.fork && '<span class="badge">Fork</span>',
      r.is_template && '<span class="badge">Template</span>',
    ].filter(Boolean).join("");
    const topics = (r.topics || []).slice(0, 6).map((t) => `<button type="button" class="topic" data-topic="${esc(t)}">${esc(t)}</button>`).join("");
    const homepage = r.homepage && /^https?:\/\//i.test(r.homepage)
      ? `<span>${ICON.link}<a href="${esc(r.homepage)}" target="_blank" rel="noopener">Site</a></span>` : "";
    return `
      <article class="card">
        <div class="main">
          <div class="card-head">
            <a class="card-title" href="${esc(r.html_url)}" target="_blank" rel="noopener">${ownerPrefix}${esc(r.name)}</a>
            <div class="badges">${badges}</div>
          </div>
          <p class="desc${r.description ? "" : " none"}">${r.description ? esc(r.description) : "No description"}</p>
          ${topics ? `<div class="topics">${topics}</div>` : ""}
        </div>
        <div class="meta">
          ${r.language ? `<span><span class="dot" style="background:${langColor(r.language)}"></span>${esc(r.language)}</span>` : ""}
          <span title="Stars">${ICON.star}${compact.format(r.stargazers_count)}</span>
          <span title="Forks">${ICON.fork}${compact.format(r.forks_count)}</span>
          ${r.open_issues_count ? `<span title="Open issues and pull requests">${ICON.issue}${compact.format(r.open_issues_count)}</span>` : ""}
          <span title="Last pushed ${esc(r.pushed_at ? new Date(r.pushed_at).toLocaleString() : "never")}"><span class="activity-dot ${act.cls}"></span>${ago(r.pushed_at)}</span>
          ${homepage}
        </div>
      </article>`;
  }

  function render() {
    const list = filtered().sort(SORTS[el.sort.value] || SORTS.pushed);
    const total = state.repos.length;
    el.count.textContent = list.length === total ? `${total} repositories` : `Showing ${list.length} of ${total} repositories`;
    if (!list.length) {
      el.repos.className = "";
      el.repos.innerHTML = '<p class="no-results">No repositories match these filters.</p>';
      return;
    }
    const groups = groupRepos(list, el.group.value);
    el.repos.className = "";
    el.repos.innerHTML = groups.map((g) => {
      const body = `<div class="${state.view}">${g.repos.map(card).join("")}</div>`;
      if (!g.label) return body;
      const marker = g.color ? `<span class="dot" style="background:${g.color}"></span>`
        : g.cls ? `<span class="activity-dot ${g.cls}"></span>` : "";
      return `<section class="group"><h3 class="group-head">${marker}${esc(g.label)}<span class="count">${g.repos.length}</span></h3>${body}</section>`;
    }).join("");
  }

  // ---------- Preferences ----------
  const PREF_KEYS = ["sort", "group", "type"];
  function loadPrefs() {
    for (const k of PREF_KEYS) {
      const v = store.get(`rd:${k}`);
      if (v && [...el[k].options].some((o) => o.value === v)) el[k].value = v;
    }
    setView(state.view);
  }
  function setView(v) {
    state.view = v;
    store.set("rd:view", v);
    el.viewBtns.forEach((b) => {
      const on = b.dataset.view === v;
      b.classList.toggle("active", on);
      b.setAttribute("aria-pressed", String(on));
    });
  }

  // ---------- Events ----------
  el.form.addEventListener("submit", (e) => { e.preventDefault(); loadOwner(el.user.value); });

  el.settingsBtn.addEventListener("click", () => {
    const open = el.settings.hidden;
    el.settings.hidden = !open;
    el.settingsBtn.setAttribute("aria-expanded", String(open));
    if (open) el.token.focus();
  });
  el.saveToken.addEventListener("click", () => {
    const t = el.token.value.trim();
    if (!t) return;
    store.set("rd:token", t);
    el.token.value = "";
    el.token.placeholder = "Token saved";
    clearCache();
    if (el.user.value) loadOwner(el.user.value);
  });
  el.clearToken.addEventListener("click", () => {
    store.del("rd:token");
    el.token.value = "";
    el.token.placeholder = "ghp_… or github_pat_…";
    clearCache();
    if (el.user.value) loadOwner(el.user.value);
  });
  function clearCache() {
    try {
      Object.keys(sessionStorage).filter((k) => k.startsWith("rd:cache:")).forEach((k) => sessionStorage.removeItem(k));
    } catch { /* ignore */ }
  }

  let searchTimer;
  el.search.addEventListener("input", () => { clearTimeout(searchTimer); searchTimer = setTimeout(render, 120); });
  for (const k of ["type", "lang", "sort", "group"]) {
    el[k].addEventListener("change", () => {
      if (PREF_KEYS.includes(k)) store.set(`rd:${k}`, el[k].value);
      render();
    });
  }
  el.viewBtns.forEach((b) => b.addEventListener("click", () => { setView(b.dataset.view); render(); }));

  el.langLegend.addEventListener("click", (e) => {
    const b = e.target.closest("[data-lang]");
    if (!b) return;
    el.lang.value = el.lang.value === b.dataset.lang ? "" : b.dataset.lang;
    render();
  });
  el.repos.addEventListener("click", (e) => {
    const t = e.target.closest("[data-topic]");
    if (!t) return;
    el.search.value = t.dataset.topic;
    render();
    el.search.focus();
  });

  // ---------- Boot ----------
  loadPrefs();
  if (getToken()) el.token.placeholder = "Token saved";
  const initial = new URLSearchParams(location.search).get("user") || store.get("rd:lastUser");
  el.form.addEventListener("submit", () => store.set("rd:lastUser", el.user.value.trim()));
  if (initial) loadOwner(initial);
})();
