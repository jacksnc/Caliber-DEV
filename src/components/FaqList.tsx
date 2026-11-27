import { useState } from "react";
import { Minus, Plus } from "lucide-react";
import { faqs } from "../data/faqs";

export default function FaqList() {
  const [openIndex, setOpenIndex] = useState<number | null>(0);

  return (
    <div className="divide-y divide-border border-y border-border">
      {faqs.map((faq, index) => {
        const isOpen = openIndex === index;
        return (
          <div key={faq.q}>
            <h3>
              <button
                type="button"
                id={`faq-question-${index}`}
                aria-expanded={isOpen}
                aria-controls={`faq-panel-${index}`}
                onClick={() => setOpenIndex(isOpen ? null : index)}
                className="flex w-full items-center justify-between gap-5 py-6 text-left text-base font-medium transition-colors hover:text-primary"
              >
                <span>{faq.q}</span>
                {isOpen ? (
                  <Minus size={17} className="shrink-0 text-primary" aria-hidden="true" />
                ) : (
                  <Plus size={17} className="shrink-0 text-primary" aria-hidden="true" />
                )}
              </button>
            </h3>
            <div
              id={`faq-panel-${index}`}
              role="region"
              aria-labelledby={`faq-question-${index}`}
              hidden={!isOpen}
              className="max-w-xl pb-6 pr-7 text-base leading-7 text-muted-foreground"
            >
              {faq.a}
            </div>
          </div>
        );
      })}
    </div>
  );
}
