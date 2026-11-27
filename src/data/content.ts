import { BadgeCheck, Earth, FileText, MapPin, type LucideIcon } from "lucide-react";

export const navLinks = [
  { href: "#services", label: "How I can help" },
  { href: "#about", label: "Meet Kimberly" },
  { href: "#approach", label: "Working with me" },
  { href: "#resources", label: "Tax resources" },
];

export const highlights: { icon: LucideIcon; title: string; body: string }[] = [
  { icon: MapPin, title: "My office", body: "Myrtle Beach, South Carolina" },
  { icon: BadgeCheck, title: "My CPA licenses", body: "South Carolina and Maryland" },
  { icon: Earth, title: "Work with me remotely", body: "Serving clients nationwide" },
];

export const quickBooksSteps = [
  {
    title: "Learn your way around QuickBooks",
    body: "I provide training for the tasks you handle in QuickBooks Online, using your business’s day-to-day needs as a starting point.",
  },
  {
    title: "Get help when you’re stuck",
    body: "I answer questions and help you work through issues with recording transactions and using your reports.",
  },
  {
    title: "Check what went where",
    body: "I review how your transactions are recorded and flag entries or categories that need attention.",
  },
  {
    title: "Match your books to your statements",
    body: "I reconcile your accounts and work through differences between your books and account statements.",
  },
  {
    title: "See what you earned and spent",
    body: "I analyze your financial statements and explain your income, expenses, and cash flow.",
  },
  {
    title: "Decide what to do next",
    body: "I provide proactive business advisory support. We’ll discuss what the review means for your budget, cash needs, and business decisions.",
  },
];

export const processSteps: [title: string, body: string][] = [
  [
    "Tell me what’s going on",
    "Send me a short note about your tax return, your business, or the question you keep putting off. I’ll ask what I need to understand the work.",
  ],
  [
    "Review the work and the price",
    "I’ll outline the services and customized pricing. You can ask questions and decide whether the plan fits.",
  ],
  [
    "Know what to send and when",
    "I’ll explain which records I need, how to share them, and the next steps for the work we agree on.",
  ],
];

export const resources: {
  title: string;
  body: string;
  href: string;
  action: string;
  label: string;
  icon: LucideIcon;
}[] = [
  {
    title: "The Tax Adviser",
    body: "Read tax news, updates, and articles about individual and business taxes. I can help you work through questions about your situation.",
    href: "https://www.thetaxadviser.com/",
    action: "Read tax updates",
    label: "TAX NEWS & ANALYSIS",
    icon: FileText,
  },
  {
    title: "IRS.gov",
    body: "Find federal tax forms, filing information, refund status tools, and payment options directly from the IRS.",
    href: "https://www.irs.gov/",
    action: "Visit IRS.gov",
    label: "OFFICIAL TAX INFORMATION",
    icon: Earth,
  },
];
