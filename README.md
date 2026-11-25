# Caliber-DEV — Repo Dashboard

A single-page dashboard that organizes every repository of a GitHub user or organization into one easy-to-scan view. Plain HTML, CSS and JavaScript: no build step, no dependencies.

## Features

- **Summary tiles**: repository count, total stars, forks, open issues/PRs, repos active this month, languages used
- **Language breakdown** bar; click a language to filter to it
- **Search** across names, descriptions and topics; click a topic chip to search for it
- **Filter** by type (sources, forks, archived, private, templates) and language
- **Sort** by last pushed, stars, name, newest, open issues or size
- **Group** by language, activity (active / recent / quiet / dormant / archived), topic or owner
- **Grid or list view**, light and dark themes, works on phones
- Shareable links: `index.html?user=<name>`
- Remembers your last user, sort, grouping and view

## Usage

Open `index.html` in a browser, or serve the folder:

```bash
python3 -m http.server 8000
```

It opens on **jacksnc**'s repositories by default (change `DEFAULT_USER` in `js/app.js`). To view another account, type it in the box or visit `http://localhost:8000/?user=<github-username-or-org>`.

### Host it on GitHub Pages

In the repository go to **Settings → Pages**, choose **Deploy from a branch**, pick the branch and `/ (root)`, and save. The dashboard will be at `https://<you>.github.io/Caliber-DEV/?user=<name>`.

### Private repositories and rate limits

Without a token the dashboard shows public repos only, and GitHub allows 60 API requests per hour. To include private repos (and get 5,000 requests per hour), open **Settings** (gear icon) and paste a [personal access token](https://github.com/settings/personal-access-tokens) with read-only access to repository metadata. When the token belongs to the user you load, private repos and ones you collaborate on are included.

The token is stored only in your browser's `localStorage` and sent only to `api.github.com`. API responses are cached in `sessionStorage` for 10 minutes to save requests.

## Files

| Path | Purpose |
| --- | --- |
| `index.html` | Page layout |
| `css/styles.css` | Styles, including dark mode and mobile layout |
| `js/app.js` | GitHub API calls, filtering, sorting, grouping, rendering |
