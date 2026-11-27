import logo from "../assets/logo.png";

export { logo };

export default function BrandMark() {
  return (
    <a
      href="#main"
      aria-label="KA CPA Advisor home"
      className="inline-flex shrink-0 items-center gap-2.5 sm:gap-3.5"
    >
      <span className="brand-logo">
        <img src={logo} alt="Kimberly Amaya, CPA logo" width={1068} height={1058} />
      </span>
      <span>
        <span className="block font-display text-[17px] leading-none tracking-[-0.025em] sm:text-[27px]">
          KA CPA Advisor
        </span>
        <span className="mt-2 block text-xs font-medium tracking-[0.02em] text-muted-foreground">
          Kimberly Amaya, CPA
        </span>
      </span>
    </a>
  );
}
