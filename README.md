# KA CPA Advisor website

Single-page marketing site for Kimberly Amaya, CPA (Myrtle Beach, SC).

These sources were rebuilt from the production `dist/` build after the original
sources were lost. Building them gives output that matches the original
pixel for pixel at desktop and phone widths.

## Stack

- [Vite](https://vite.dev) + React 19 + TypeScript
- Tailwind CSS v4 (via `@tailwindcss/vite`)
- [lucide-react](https://lucide.dev) icons
- [Formspree](https://formspree.io) for the contact form (`@formspree/react`)

## Commands

```bash
npm install
npm run dev        # local dev server
npm run build      # production build into dist/
npm run preview    # serve the built dist/
npm run typecheck
```

Upload the contents of `dist/` to the host's `public_html/` to deploy.

## Layout

```
index.html                 HTML shell
public/                    copied to dist/ as-is
  robots.txt               currently "Disallow: /" (site is hidden from search)
  images/                  hero photo, bronze award SVG/PNG
src/
  main.tsx                 React entry point
  App.tsx                  the page: header, hero, sections, footer
  index.css                Tailwind theme, component classes, custom styles
  assets/logo.png          logo (bundled and hashed by Vite)
  components/
    AwardBadge.tsx         animated bronze award medal
    BrandMark.tsx          logo + name link
    ContactForm.tsx        Formspree contact form
    FaqList.tsx            accordion FAQ
    SeoHead.tsx            meta tags, canonical link, JSON-LD structured data
  data/
    site.ts                URL, phone, email, Formspree form ID
    services.ts            the six services
    faqs.ts                FAQ questions and answers
    content.ts             nav links, highlights, QuickBooks steps, process, resources
```

## Before launch

- `index.html` has `<meta name="robots" content="noindex, nofollow">` and
  `public/robots.txt` disallows everything. Remove both to let search engines index the site.
- The About section still shows `[PLACEHOLDER]` text for Kimberly's portrait and the award's
  year and category (`src/App.tsx`, `src/components/AwardBadge.tsx`).
