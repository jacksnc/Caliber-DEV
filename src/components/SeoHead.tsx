import { useEffect } from "react";
import { faqs } from "../data/faqs";
import { services } from "../data/services";
import {
  AWARD_NAME,
  PHONE_E164,
  SITE_DESCRIPTION,
  SITE_IMAGE,
  SITE_TITLE,
  SITE_URL,
} from "../data/site";

function upsertMeta(selector: string, attributes: Record<string, string>) {
  let element = document.head.querySelector(selector);
  if (!element) {
    element = document.createElement("meta");
    document.head.appendChild(element);
  }
  for (const [name, value] of Object.entries(attributes)) {
    element.setAttribute(name, value);
  }
}

function upsertLink(rel: string, href: string) {
  let element = document.head.querySelector<HTMLLinkElement>(`link[rel="${rel}"]`);
  if (!element) {
    element = document.createElement("link");
    element.rel = rel;
    document.head.appendChild(element);
  }
  element.href = href;
}

const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "AccountingService",
      "@id": `${SITE_URL}/#business`,
      name: "KA CPA Advisor",
      alternateName: "Kimberly Amaya, CPA",
      description:
        "Kimberly Amaya, CPA provides income tax preparation and planning, tax minimization strategies and compliance, bookkeeping and accounting, accounting system setup and maintenance, QuickBooks Online training, support, review and advisory, and customized services. Based in Myrtle Beach, SC. Licensed in South Carolina and Maryland. Serving remote clients nationwide.",
      url: SITE_URL,
      telephone: PHONE_E164,
      image: SITE_IMAGE,
      award: AWARD_NAME,
      address: {
        "@type": "PostalAddress",
        addressLocality: "Myrtle Beach",
        addressRegion: "SC",
        addressCountry: "US",
      },
      areaServed: [
        { "@type": "City", name: "Myrtle Beach" },
        { "@type": "State", name: "South Carolina" },
        { "@type": "State", name: "Maryland" },
        { "@type": "Country", name: "United States" },
      ],
      founder: {
        "@type": "Person",
        name: "Kimberly Amaya",
        jobTitle: "Certified Public Accountant",
        honorificSuffix: "CPA",
        hasCredential: [
          "Certified Public Accountant, South Carolina",
          "Certified Public Accountant, Maryland",
        ].map((name) => ({
          "@type": "EducationalOccupationalCredential",
          credentialCategory: "Professional certification",
          name,
        })),
      },
      hasOfferCatalog: {
        "@type": "OfferCatalog",
        name: "CPA and tax services",
        itemListElement: services.map(({ title }) => ({
          "@type": "Offer",
          itemOffered: { "@type": "Service", name: title },
        })),
      },
    },
    {
      "@type": "FAQPage",
      "@id": `${SITE_URL}/#faq`,
      mainEntity: faqs.map(({ q, a }) => ({
        "@type": "Question",
        name: q,
        acceptedAnswer: { "@type": "Answer", text: a },
      })),
    },
  ],
};

/** Sets the document title, social/SEO meta tags and JSON-LD structured data. */
export default function SeoHead() {
  useEffect(() => {
    document.title = SITE_TITLE;
    document.documentElement.lang = "en";

    upsertMeta('meta[name="description"]', { name: "description", content: SITE_DESCRIPTION });
    upsertMeta('meta[property="og:type"]', { property: "og:type", content: "website" });
    upsertMeta('meta[property="og:title"]', { property: "og:title", content: SITE_TITLE });
    upsertMeta('meta[property="og:description"]', {
      property: "og:description",
      content: SITE_DESCRIPTION,
    });
    upsertMeta('meta[property="og:url"]', { property: "og:url", content: `${SITE_URL}/` });
    upsertMeta('meta[property="og:image"]', { property: "og:image", content: SITE_IMAGE });
    upsertMeta('meta[property="og:site_name"]', {
      property: "og:site_name",
      content: "KA CPA Advisor",
    });
    upsertMeta('meta[name="twitter:card"]', {
      name: "twitter:card",
      content: "summary_large_image",
    });
    upsertMeta('meta[name="twitter:title"]', { name: "twitter:title", content: SITE_TITLE });
    upsertMeta('meta[name="twitter:description"]', {
      name: "twitter:description",
      content: SITE_DESCRIPTION,
    });
    upsertMeta('meta[name="twitter:image"]', { name: "twitter:image", content: SITE_IMAGE });
    upsertLink("canonical", `${SITE_URL}/`);

    let script = document.head.querySelector<HTMLScriptElement>("script[data-ka-schema]");
    if (!script) {
      script = document.createElement("script");
      script.type = "application/ld+json";
      script.setAttribute("data-ka-schema", "");
      document.head.appendChild(script);
    }
    script.textContent = JSON.stringify(structuredData);
  }, []);

  return null;
}
