import {
  BookOpen,
  Compass,
  FileText,
  Monitor,
  Settings2,
  SlidersHorizontal,
  type LucideIcon,
} from "lucide-react";

export type Service = {
  icon: LucideIcon;
  title: string;
  short: string;
  body: string;
  tag: string;
  cta: string;
};

export const QUICKBOOKS_SERVICE = "QuickBooks Online Training, Support, Review & Advisory";

export const services: Service[] = [
  {
    icon: FileText,
    title: "Income Tax Preparation & Planning",
    short: "Got a shoebox of receipts?",
    body: "I prepare federal and state income tax returns for individuals and small businesses. I’ll explain which records you need and help you plan for estimated payments and changes in your income.",
    tag: "Your return & the year ahead",
    cta: "Talk about your taxes",
  },
  {
    icon: Compass,
    title: "Tax Minimization & Compliance",
    short: "Make tax decisions before the deadline.",
    body: "I look for tax minimization strategies that fit your situation and comply with tax law. I’ll walk you through your options, filing requirements, and the records needed to support your return.",
    tag: "Tax strategies & filing obligations",
    cta: "Explore your tax options",
  },
  {
    icon: BookOpen,
    title: "Bookkeeping & Accounting Services",
    short: "Know where your money went.",
    body: "I help you keep transactions organized, reconcile accounts, and prepare financial reports. You can see what you earned, what you spent, and which accounts need attention.",
    tag: "Organized records & useful reports",
    cta: "Get help with your books",
  },
  {
    icon: Settings2,
    title: "Accounting System Setup & Maintenance",
    short: "Your side hustle just became a business.",
    body: "I set up and maintain an accounting system that fits how you work. I’ll help organize your accounts and build routines for recording income, tracking expenses, and keeping your books up to date.",
    tag: "A system you can use every day",
    cta: "Talk about your accounting setup",
  },
  {
    icon: Monitor,
    title: QUICKBOOKS_SERVICE,
    short: "Make QuickBooks work for you.",
    body: "I teach you how to use QuickBooks Online, help when you get stuck, and review your books. I’ll explain your reports and help you use the numbers in your business decisions.",
    tag: "Training, support & ongoing review",
    cta: "Ask about QuickBooks help",
  },
  {
    icon: SlidersHorizontal,
    title: "Customized Services",
    short: "Let’s build a plan around your business.",
    body: "I tailor services and pricing to your needs, from a tax project to ongoing advisory and CFO support. If your Myrtle Beach business follows tourism season, we can work on budgets and cash-flow forecasts for the quieter months.",
    tag: "Your needs, your scope, your pricing",
    cta: "Discuss a plan for you",
  },
];
