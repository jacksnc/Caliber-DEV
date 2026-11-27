import { useEffect, useRef, useState } from "react";
import {
  ArrowDown,
  ArrowUpRight,
  BadgeCheck,
  Check,
  Mail,
  MapPin,
  Menu,
  Phone,
  X,
} from "lucide-react";
import AwardBadge from "./components/AwardBadge";
import BrandMark, { logo } from "./components/BrandMark";
import ContactForm from "./components/ContactForm";
import FaqList from "./components/FaqList";
import SeoHead from "./components/SeoHead";
import { highlights, navLinks, processSteps, quickBooksSteps, resources } from "./data/content";
import { QUICKBOOKS_SERVICE, services } from "./data/services";
import { EMAIL, PHONE_DISPLAY, PHONE_HREF } from "./data/site";

/** Fades sections marked with `data-reveal` in as they scroll into view. */
function useScrollReveal() {
  useEffect(() => {
    const reducedMotion = window.matchMedia?.("(prefers-reduced-motion: reduce)");
    if (!reducedMotion || reducedMotion.matches || typeof IntersectionObserver === "undefined") {
      return;
    }

    const targets = document.querySelectorAll<HTMLElement>("[data-reveal]");
    const observer = new IntersectionObserver(
      (entries) => {
        for (const entry of entries) {
          if (entry.isIntersecting) {
            (entry.target as HTMLElement).dataset.revealState = "visible";
            observer.unobserve(entry.target);
          }
        }
      },
      { threshold: 0.08, rootMargin: "0px 0px -24px 0px" },
    );

    for (const target of targets) {
      target.dataset.revealState = "pending";
      observer.observe(target);
    }

    const onMotionPreferenceChange = () => {
      if (reducedMotion.matches) {
        observer.disconnect();
        for (const target of targets) target.dataset.revealState = "visible";
      }
    };
    reducedMotion.addEventListener("change", onMotionPreferenceChange);

    return () => {
      observer.disconnect();
      reducedMotion.removeEventListener("change", onMotionPreferenceChange);
      for (const target of targets) delete target.dataset.revealState;
    };
  }, []);
}

export default function App() {
  const [menuOpen, setMenuOpen] = useState(false);
  const [selectedService, setSelectedService] = useState(services[0].title);
  const menuButtonRef = useRef<HTMLButtonElement>(null);

  // Close the mobile menu with Escape and return focus to the toggle.
  useEffect(() => {
    if (!menuOpen) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setMenuOpen(false);
        menuButtonRef.current?.focus();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, [menuOpen]);

  useScrollReveal();

  return (
    <div className="min-h-screen bg-background text-foreground">
      <SeoHead />
      <a href="#main" className="skip-link">
        Skip to main content
      </a>

      {/* Top info bar */}
      <div className="border-b border-border/60 bg-secondary/65">
        <div className="page-width flex min-h-9 items-center justify-between gap-4 py-2 text-xs tracking-[0.06em] text-muted-foreground sm:text-xs">
          <span className="inline-flex items-center gap-2">
            <MapPin size={12} aria-hidden="true" /> My office is in Myrtle Beach. You can work with
            me nationwide.
          </span>
          <a
            href={PHONE_HREF}
            className="hidden items-center gap-2 transition-colors hover:text-primary sm:inline-flex"
          >
            <Phone size={11} aria-hidden="true" /> {PHONE_DISPLAY}
          </a>
        </div>
      </div>

      <header className="sticky top-0 z-40 border-b border-border/65 bg-background/95 backdrop-blur-md">
        <div className="page-width flex h-[96px] items-center justify-between gap-5 sm:h-[112px]">
          <BrandMark />
          <nav aria-label="Primary" className="hidden items-center gap-6 xl:flex">
            {navLinks.map((link) => (
              <a key={link.href} href={link.href} className="nav-link">
                {link.label}
              </a>
            ))}
          </nav>
          <a href="#contact" className="button button-primary hidden xl:inline-flex">
            Talk with me <ArrowUpRight size={16} aria-hidden="true" />
          </a>
          <button
            ref={menuButtonRef}
            type="button"
            aria-label={menuOpen ? "Close navigation" : "Open navigation"}
            aria-expanded={menuOpen}
            aria-controls="mobile-navigation"
            onClick={() => setMenuOpen(!menuOpen)}
            className="rounded-full border-2 border-border p-3 xl:hidden"
          >
            {menuOpen ? <X size={20} aria-hidden="true" /> : <Menu size={20} aria-hidden="true" />}
          </button>
        </div>
        <nav
          id="mobile-navigation"
          aria-label="Mobile"
          hidden={!menuOpen}
          className="border-t border-border bg-background px-6 pb-5 xl:hidden"
        >
          {[...navLinks, { href: "#contact", label: "Talk with me" }].map((link) => (
            <a
              key={link.href}
              href={link.href}
              onClick={() => setMenuOpen(false)}
              className="block border-b border-border/60 py-4 text-base"
            >
              {link.label}
            </a>
          ))}
        </nav>
      </header>

      <main id="main">
        {/* Hero */}
        <section
          aria-labelledby="hero-heading"
          className="page-width relative grid items-center gap-12 py-14 lg:grid-cols-[1.2fr_0.88fr] lg:gap-16 lg:py-20"
        >
          <div className="ka-rise">
            <p className="eyebrow">
              <span className="mr-2 inline-block h-1.5 w-1.5 rounded-full bg-primary" /> Kimberly
              Amaya, CPA · Myrtle Beach, SC
            </p>
            <h1
              id="hero-heading"
              className="mt-6 max-w-[640px] font-display text-[clamp(2.65rem,5.75vw,5.3rem)] leading-[1.06] tracking-[-0.045em]"
            >
              Taxes to file.
              <br />A business to run.
              <br />
              <em className="hero-flourish font-normal text-primary">Let’s get to work.</em>
            </h1>
            <p className="mt-7 max-w-[440px] text-[16px] leading-[1.85] text-muted-foreground">
              I’m Kimberly Amaya, CPA. I help individuals and small businesses prepare their tax
              returns, plan for taxes, and understand their books. My office is in Myrtle Beach. You
              can work with me locally or remotely, anywhere in the country.
            </p>
            <div className="mt-8 flex flex-wrap items-center gap-x-7 gap-y-4">
              <a href="#contact" className="button button-primary">
                Tell me what you need <ArrowUpRight size={16} aria-hidden="true" />
              </a>
              <a href="#services" className="text-link">
                See how I can help <ArrowDown size={14} aria-hidden="true" />
              </a>
            </div>
            <p className="mt-8 flex items-center gap-2 text-xs text-muted-foreground">
              <BadgeCheck size={16} className="text-primary" aria-hidden="true" /> I’m a licensed
              CPA in South Carolina and Maryland.
            </p>
          </div>

          <div className="hero-visual ka-rise relative mb-6 lg:mb-0">
            <span className="hero-orbit" aria-hidden="true" />
            <div
              className="absolute -top-4 -right-4 bottom-7 left-7 rounded-t-[160px] border-2 border-accent/45 sm:-right-5"
              aria-hidden="true"
            />
            <div className="relative overflow-hidden rounded-t-[160px] rounded-b-[5px] bg-secondary sm:rounded-t-[220px]">
              <img
                src="/images/coastal-shore.jpg"
                alt="Gentle waves meeting a sandy shore at sunrise"
                width={1400}
                height={907}
                fetchPriority="high"
                className="h-[430px] w-full object-cover object-[58%_center] sm:h-[520px] lg:h-[555px]"
              />
              <div
                className="absolute inset-0 bg-linear-to-t from-[#284953]/35 via-transparent to-white/5"
                aria-hidden="true"
              />
            </div>
            <AwardBadge variant="hero" className="hero-award" />
          </div>
        </section>

        {/* At a glance */}
        <section aria-label="Practice at a glance" className="local-band mt-4">
          <div className="page-width grid gap-6 py-7 sm:grid-cols-3 sm:gap-0">
            {highlights.map(({ icon: Icon, title, body }, index) => (
              <div
                key={title}
                className={`flex items-center gap-4 ${index ? "sm:border-l sm:border-border sm:pl-7 lg:pl-12" : ""}`}
              >
                <Icon size={23} strokeWidth={1.7} className="shrink-0 text-primary" aria-hidden="true" />
                <div>
                  <p className="text-base font-medium">{title}</p>
                  <p className="mt-1 text-xs text-muted-foreground">{body}</p>
                </div>
              </div>
            ))}
          </div>
        </section>

        {/* Services */}
        <section
          id="services"
          aria-labelledby="services-heading"
          className="page-width section-space grid items-start gap-12 lg:grid-cols-[0.72fr_1.28fr]"
          data-reveal
        >
          <div className="lg:sticky lg:top-36">
            <div>
              <p className="eyebrow">Your taxes. Your books. Your business.</p>
              <h2 id="services-heading" className="section-heading mt-4">
                Taxes coming due? Books falling behind?
              </h2>
            </div>
            <p className="mt-6 max-w-md text-base leading-8 text-muted-foreground">
              Maybe you need this year’s return filed. Maybe your books need attention, or your
              growing business needs an accounting system. Tell me what’s happening. I’ll help you
              choose the services that fit and put together pricing for the work involved.
            </p>
          </div>

          <div className="grid gap-6 sm:grid-cols-2">
            {services.map(({ icon: Icon, title, short, body, tag, cta }, index) => (
              <article key={title} className="service-card group flex min-w-0 flex-col">
                <div className="flex items-center justify-between">
                  <Icon size={30} strokeWidth={1.7} className="text-primary" aria-hidden="true" />
                  <span className="text-xs tracking-widest text-muted-foreground">0{index + 1}</span>
                </div>
                <h3 className="mt-7 font-display text-[27px] tracking-[-0.025em]">{title}</h3>
                <p className="mt-4 text-lg leading-7 font-semibold">{short}</p>
                <p className="mt-3 flex-1 text-base leading-7 text-muted-foreground">{body}</p>
                <p className="mt-6 text-xs tracking-wide text-muted-foreground">{tag}</p>
                <a
                  href="#contact"
                  onClick={() => setSelectedService(title)}
                  className="mt-5 inline-flex items-center justify-between border-t border-border pt-4 text-xs font-medium text-primary"
                  aria-label={cta}
                >
                  {cta}{" "}
                  <ArrowUpRight
                    size={17}
                    className="transition-transform group-hover:translate-x-1"
                    aria-hidden="true"
                  />
                </a>
              </article>
            ))}
          </div>
        </section>

        {/* QuickBooks review */}
        <section aria-labelledby="review-heading" className="review-section" data-reveal>
          <div className="page-width section-space grid gap-12 lg:grid-cols-[1.05fr_0.95fr] lg:gap-20">
            <div>
              <p className="eyebrow">What’s happening in your books?</p>
              <h2 id="review-heading" className="section-heading mt-4">
                QuickBooks Online
                <br />
                Training &amp; Support.
                <br />
                <em className="font-normal text-primary">Review &amp; Advisory.</em>
              </h2>
              <p className="mt-6 max-w-md text-base leading-7 text-muted-foreground">
                New to QuickBooks Online? Or using it every day with questions you haven’t sorted
                out? I offer training and support alongside transaction review, account
                reconciliation, and financial statement analysis. I’ll explain what needs attention
                and help you use your numbers to make business decisions.
              </p>
              <a
                href="#contact"
                onClick={() => setSelectedService(QUICKBOOKS_SERVICE)}
                className="text-link mt-7"
              >
                Get help with QuickBooks <ArrowUpRight size={16} aria-hidden="true" />
              </a>
            </div>
            <ol className="divide-y divide-white/20">
              {quickBooksSteps.map((step, index) => (
                <li key={step.title} className={`flex gap-5 py-5 ${index === 0 ? "!pt-0" : ""}`}>
                  <span className="mt-1 flex h-7 w-7 shrink-0 items-center justify-center rounded-full border border-white/40 text-xs text-[#f1b8d8]">
                    0{index + 1}
                  </span>
                  <div>
                    <h3 className="font-display text-xl">{step.title}</h3>
                    <p className="mt-2 text-base leading-6 text-muted-foreground">{step.body}</p>
                  </div>
                </li>
              ))}
            </ol>
          </div>
        </section>

        {/* About */}
        <section
          id="about"
          data-reveal
          aria-labelledby="about-heading"
          className="page-width section-space grid items-center gap-12 lg:grid-cols-[0.85fr_1.15fr] lg:gap-24"
        >
          <div className="portrait-placeholder flex flex-col items-center justify-center px-6 py-16 lg:-rotate-2">
            <img
              src={logo}
              alt="Kimberly Amaya, CPA logo"
              width={1068}
              height={1058}
              loading="lazy"
              className="portrait-logo"
            />
            <p className="mt-1 font-display text-3xl">Kimberly Amaya, CPA</p>
            <p className="mt-3 text-xs font-semibold tracking-[0.04em]">Certified Public Accountant</p>
            <p className="mt-5 max-w-xs text-center text-base leading-7">
              Bring your questions. I’ll explain the numbers.
            </p>
            <p className="portrait-label">[PLACEHOLDER] Kimberly’s portrait</p>
          </div>
          <div>
            <p className="eyebrow">Your CPA in Myrtle Beach</p>
            <h2 id="about-heading" className="section-heading mt-4">
              I’m Kimberly.
              <br />
              <em className="font-normal text-primary">I’ll explain the numbers.</em>
            </h2>
            <p className="mt-6 text-base leading-8 text-muted-foreground">
              I’m Kimberly Amaya, CPA. My office is in Myrtle Beach, and I’m licensed in South
              Carolina and Maryland. I work with individuals and small businesses here on the Grand
              Strand and with remote clients nationwide.
            </p>
            <p className="mt-4 text-base leading-7 text-muted-foreground">
              You might be filing a personal return, turning a side hustle into a business, or
              figuring out how summer revenue will cover winter bills. I’ll start with your
              situation. Then I’ll explain the records, the questions we need to answer, and the
              work involved.
            </p>
            <AwardBadge variant="about" className="mt-8" />
            <a href="#contact" className="text-link mt-7">
              Tell me what you’re working on <ArrowUpRight size={16} aria-hidden="true" />
            </a>
          </div>
        </section>

        {/* Process */}
        <section id="approach" data-reveal aria-labelledby="approach-heading" className="process-band">
          <div className="page-width section-space">
            <div className="mx-auto max-w-xl text-center">
              <p className="eyebrow">Before the work starts</p>
              <h2 id="approach-heading" className="section-heading mt-4">
                Here’s what working with me looks like.
              </h2>
              <p className="mt-5 text-base leading-7 text-muted-foreground">
                I’ll ask about your situation, the records involved, and the support you need. Then
                I’ll put together customized services and pricing for you to review.
              </p>
            </div>
            <ol className="mt-12 grid gap-9 md:grid-cols-3 md:gap-12">
              {processSteps.map(([title, body], index) => (
                <li key={title} className="border-t border-border pt-6">
                  <span className="font-display text-7xl leading-none text-accent lg:text-8xl">
                    0{index + 1}
                  </span>
                  <h3 className="mt-5 font-display text-2xl">{title}</h3>
                  <p className="mt-3 text-base leading-7 text-muted-foreground">{body}</p>
                </li>
              ))}
            </ol>
            <div className="mt-11 text-center">
              <a href="#contact" className="button button-primary">
                Ask about a plan for you <ArrowUpRight size={16} aria-hidden="true" />
              </a>
              <p className="mt-4 text-xs text-muted-foreground">
                You’ll review the services and price before we get started.
              </p>
            </div>
          </div>
        </section>

        {/* Resources */}
        <section
          id="resources"
          data-reveal
          aria-labelledby="resources-heading"
          className="page-width section-space"
        >
          <div className="flex flex-col justify-between gap-5 md:flex-row md:items-end">
            <div>
              <p className="eyebrow">Tax updates &amp; official information</p>
              <h2 id="resources-heading" className="section-heading mt-4">
                Two tax sites worth bookmarking.
              </h2>
            </div>
            <p className="max-w-xs text-base leading-7 text-muted-foreground">
              Follow tax updates or find official forms and tools. If you’re wondering how something
              applies to you, bring me your question.
            </p>
          </div>
          <div className="mt-10 grid gap-5 md:grid-cols-2">
            {resources.map(({ title, body, href, action, label, icon: Icon }) => (
              <a
                key={title}
                href={href}
                target="_blank"
                rel="noopener noreferrer"
                className="resource-card group"
              >
                <div className="flex items-center justify-between gap-4">
                  <Icon size={23} strokeWidth={1.7} className="shrink-0 text-primary" aria-hidden="true" />
                  <span className="text-right text-xs tracking-[0.12em] text-muted-foreground">
                    {label}
                  </span>
                </div>
                <h3 className="mt-6 font-display text-[25px]">{title}</h3>
                <p className="mt-3 text-base leading-7 text-muted-foreground">{body}</p>
                <span className="mt-7 inline-flex items-center gap-2 text-xs font-medium text-primary">
                  {action} <ArrowUpRight size={15} aria-hidden="true" />
                  <span className="sr-only"> (opens in a new tab)</span>
                </span>
              </a>
            ))}
          </div>
        </section>

        {/* FAQ */}
        <section
          id="faq"
          data-reveal
          aria-labelledby="faq-heading"
          className="page-width grid gap-9 border-t border-border py-16 lg:grid-cols-[0.7fr_1.3fr] lg:gap-20 lg:py-20"
        >
          <div>
            <p className="eyebrow">The practical details</p>
            <h2 id="faq-heading" className="section-heading mt-4">
              Questions before we start?
            </h2>
            <p className="mt-5 text-base text-muted-foreground">Don’t see your question here?</p>
            <a href="#contact" className="text-link mt-3">
              Send me your question <ArrowUpRight size={15} aria-hidden="true" />
            </a>
          </div>
          <FaqList />
        </section>

        {/* Contact */}
        <section id="contact" aria-labelledby="contact-heading" className="contact-section">
          <div className="page-width section-space grid gap-12 lg:grid-cols-[0.9fr_1.1fr] lg:gap-20">
            <div className="contact-intro">
              <p className="eyebrow">Start with what you need</p>
              <h2 id="contact-heading" className="section-heading mt-4">
                Tell me what’s
                <br />
                <em className="font-normal text-primary">piling up.</em>
              </h2>
              <p className="mt-6 max-w-sm text-base leading-7 text-muted-foreground">
                Behind on your books? Starting a business? Have a tax question you haven’t asked
                yet? Send me a short note about what you need help with.
              </p>
              <ul className="mt-9 space-y-6 text-base">
                <li>
                  <a href={PHONE_HREF} className="inline-flex items-center gap-3 hover:text-primary">
                    <Phone size={18} strokeWidth={1.5} className="text-primary" aria-hidden="true" />
                    {PHONE_DISPLAY}
                  </a>
                </li>
                <li>
                  <a
                    href={`mailto:${EMAIL}`}
                    className="inline-flex items-center gap-3 break-all hover:text-primary"
                  >
                    <Mail size={18} strokeWidth={1.5} className="shrink-0 text-primary" aria-hidden="true" />
                    {EMAIL}
                  </a>
                </li>
                <li className="flex items-start gap-3">
                  <MapPin size={19} strokeWidth={1.5} className="shrink-0 text-primary" aria-hidden="true" />
                  <address className="not-italic">
                    Myrtle Beach, South Carolina
                    <span className="mt-2 block text-xs text-muted-foreground">
                      My main office · Remote clients nationwide
                    </span>
                  </address>
                </li>
              </ul>
              <p className="mt-10 inline-flex items-center gap-2 border-t border-[#c9d9d8] pt-5 text-xs text-muted-foreground">
                <Check size={15} className="text-primary" aria-hidden="true" /> I’m a licensed CPA
                in South Carolina and Maryland.
              </p>
            </div>
            <ContactForm service={selectedService} onServiceChange={setSelectedService} />
          </div>
        </section>
      </main>

      <footer className="site-footer">
        <div className="page-width grid gap-10 py-12 sm:grid-cols-2 lg:grid-cols-[1.6fr_1fr_1fr]">
          <div>
            <BrandMark />
            <p className="mt-5 max-w-sm text-base leading-7 text-muted-foreground">
              I help you prepare your tax returns, plan for taxes, and use your books to make
              business decisions. Based in Myrtle Beach. Working with you nationwide.
            </p>
          </div>
          <nav aria-label="Footer services">
            <p className="eyebrow">How I can help</p>
            <ul className="mt-5 space-y-3 text-xs text-muted-foreground">
              {services.map((service) => (
                <li key={service.title}>
                  <a
                    href="#contact"
                    onClick={() => setSelectedService(service.title)}
                    className="hover:text-primary"
                  >
                    {service.title}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
          <nav aria-label="Footer navigation">
            <p className="eyebrow">Get in touch</p>
            <ul className="mt-5 space-y-3 text-xs text-muted-foreground">
              <li>
                <a href="#about" className="hover:text-primary">
                  Meet Kimberly
                </a>
              </li>
              <li>
                <a href="#resources" className="hover:text-primary">
                  Tax resources
                </a>
              </li>
              <li>
                <a href="#contact" className="hover:text-primary">
                  Tell me what you need
                </a>
              </li>
              <li>
                <a href={PHONE_HREF} className="hover:text-primary">
                  {PHONE_DISPLAY}
                </a>
              </li>
            </ul>
          </nav>
        </div>
        <div className="page-width flex flex-wrap justify-between gap-3 border-t border-border py-6 text-xs leading-5 text-muted-foreground">
          <p>© {new Date().getFullYear()} KA CPA Advisor. All rights reserved.</p>
          <p>Myrtle Beach, SC · CPA licensed in SC &amp; MD · Remote clients nationwide</p>
        </div>
      </footer>
    </div>
  );
}
