import { useForm, ValidationError } from "@formspree/react";
import { ArrowUpRight, CircleCheck } from "lucide-react";
import { services } from "../data/services";
import { FORMSPREE_FORM_ID, PHONE_DISPLAY, PHONE_HREF } from "../data/site";

const fieldClass =
  "mt-2 w-full min-w-0 rounded-[3px] border border-border bg-background/40 px-3.5 py-3 text-base text-foreground placeholder:text-muted-foreground/80 transition-colors focus:border-primary";

type ContactFormProps = {
  service: string;
  onServiceChange: (service: string) => void;
};

export default function ContactForm({ service, onServiceChange }: ContactFormProps) {
  const [state, handleSubmit] = useForm(FORMSPREE_FORM_ID);

  if (state.succeeded) {
    return (
      <div
        role="status"
        className="rounded-2xl border border-border bg-white p-8 text-center text-foreground"
      >
        <CircleCheck className="mx-auto h-10 w-10 text-primary" aria-hidden="true" />
        <h3 className="mt-5 font-display text-3xl">Your message is in.</h3>
        <p className="mt-4 text-base leading-7 text-muted-foreground">
          Thanks for getting in touch. I’ll follow up to ask a few questions and discuss the work
          you need.
        </p>
        <a className="text-link mt-6" href={PHONE_HREF}>
          Call me at {PHONE_DISPLAY}
        </a>
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="relative min-w-0 rounded-2xl border-2 border-white/50 bg-white p-6 text-foreground shadow-[0_20px_60px_#193a4030] sm:p-9 lg:-mt-12 lg:mb-12"
    >
      <h3 className="font-display text-[27px]">What do you need help with?</h3>
      <p className="mt-2 text-base leading-7 text-muted-foreground">
        Tell me a little about your situation. I’ll follow up to discuss the work you need.
      </p>

      <div className="mt-7 grid gap-5 sm:grid-cols-2">
        <div>
          <label htmlFor="name" className="text-xs font-medium">
            Your name
          </label>
          <input
            id="name"
            name="name"
            type="text"
            required
            autoComplete="name"
            placeholder="First and last name"
            className={fieldClass}
          />
          <ValidationError prefix="Name" field="name" errors={state.errors} />
        </div>

        <div>
          <label htmlFor="email" className="text-xs font-medium">
            Your email
          </label>
          <input
            id="email"
            name="email"
            type="email"
            required
            autoComplete="email"
            placeholder="you@example.com"
            className={fieldClass}
          />
          <ValidationError prefix="Email" field="email" errors={state.errors} />
        </div>

        <div className="sm:col-span-2">
          <label htmlFor="phone" className="text-xs font-medium">
            Your phone <span className="font-normal text-muted-foreground">(optional)</span>
          </label>
          <input
            id="phone"
            name="phone"
            type="tel"
            autoComplete="tel"
            placeholder="Best number to reach you"
            className={fieldClass}
          />
        </div>

        <div className="sm:col-span-2">
          <label htmlFor="service" className="text-xs font-medium">
            What can I help you with?
          </label>
          <select
            id="service"
            name="service"
            value={service}
            onChange={(event) => onServiceChange(event.target.value)}
            className={fieldClass}
          >
            {services.map(({ title }) => (
              <option key={title} value={title}>
                {title}
              </option>
            ))}
            <option>Help me choose</option>
          </select>
        </div>
      </div>

      <div className="mt-5">
        <label htmlFor="message" className="text-xs font-medium">
          What’s happening?
        </label>
        <textarea
          id="message"
          name="message"
          rows={4}
          required
          placeholder="For example: I started a business this year and need help with my books and taxes."
          aria-describedby="message-guidance"
          className={fieldClass}
        />
        <ValidationError prefix="Message" field="message" errors={state.errors} />
      </div>

      <p id="message-guidance" className="mt-2 text-base leading-5 text-muted-foreground">
        A short description is enough. Please don’t include Social Security numbers, account
        details, or tax documents here.
      </p>

      <div role="alert">
        <ValidationError errors={state.errors} className="mt-3 block text-base text-[#993e3e]" />
      </div>

      <button
        type="submit"
        disabled={state.submitting}
        className="button button-primary mt-6 w-full disabled:opacity-60"
      >
        {state.submitting ? "Sending your note…" : "Send me your note"}
        <ArrowUpRight size={17} aria-hidden="true" />
      </button>
    </form>
  );
}
