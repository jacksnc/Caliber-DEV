import { useId, useState } from "react";
import { AWARD_NAME } from "../data/site";

type AwardBadgeProps = {
  variant?: "hero" | "about";
  className?: string;
  /** Optional official award artwork. When set, it replaces the drawn SVG medal. */
  artworkSrc?: string;
};

// 96-point serrated rim around the medal (alternating outer/inner radius).
const RIM_POINTS = Array.from({ length: 96 }, (_, i) => {
  const angle = (i * Math.PI * 2) / 96 - Math.PI / 2;
  const radius = i % 2 === 0 ? 95 : 92;
  return `${110 + Math.cos(angle) * radius},${104 + Math.sin(angle) * radius}`;
}).join(" ");

export default function AwardBadge({ variant = "hero", className = "", artworkSrc }: AwardBadgeProps) {
  const id = `bronze-${useId().replace(/[^a-zA-Z0-9_-]/g, "")}`;
  // Bumped on hover so the shine element remounts and its animation replays.
  const [shineKey, setShineKey] = useState(0);

  return (
    <figure
      className={`award-badge award-badge--${variant} ${className}`}
      role="img"
      aria-label={AWARD_NAME}
      aria-describedby={variant === "about" ? `${id}-details` : undefined}
      onPointerEnter={() => setShineKey((key) => key + 1)}
    >
      <span className="award-badge__float" aria-hidden="true">
        <span className="award-badge__tilt">
          {artworkSrc ? (
            <span className="award-badge__official">
              <img src={artworkSrc} alt="" />
              <span key={shineKey} className="award-badge__official-shine" />
            </span>
          ) : (
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 220 270"
              className="award-badge__svg"
              aria-hidden="true"
              focusable="false"
            >
              <defs>
                <linearGradient id={`${id}-rim`} x1="0" y1="0" x2="1" y2="1">
                  <stop offset="0" stopColor="#ffe3bc" />
                  <stop offset="0.2" stopColor="#bb7446" />
                  <stop offset="0.42" stopColor="#f3c08e" />
                  <stop offset="0.65" stopColor="#844423" />
                  <stop offset="0.83" stopColor="#dca270" />
                  <stop offset="1" stopColor="#6e361d" />
                </linearGradient>
                <radialGradient id={`${id}-face`} cx="32%" cy="23%" r="83%">
                  <stop offset="0" stopColor="#ffe6c4" />
                  <stop offset="0.4" stopColor="#edbd8e" />
                  <stop offset="0.72" stopColor="#cf986a" />
                  <stop offset="1" stopColor="#c48a59" />
                </radialGradient>
                <linearGradient id={`${id}-ribbon`} x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0" stopColor="#f8d3a6" />
                  <stop offset="0.22" stopColor="#dca16b" />
                  <stop offset="0.5" stopColor="#f1c394" />
                  <stop offset="0.8" stopColor="#d39a65" />
                  <stop offset="1" stopColor="#b57142" />
                </linearGradient>
                <linearGradient id={`${id}-blue`} x1="0" y1="0" x2="1" y2="0">
                  <stop stopColor="#286d76" />
                  <stop offset="0.48" stopColor="#70b2cb" />
                  <stop offset="1" stopColor="#367a95" />
                </linearGradient>
                <linearGradient id={`${id}-orchid`} x1="0" y1="0" x2="1" y2="0">
                  <stop stopColor="#85315f" />
                  <stop offset="0.5" stopColor="#d58fbe" />
                  <stop offset="1" stopColor="#af3f86" />
                </linearGradient>
                <linearGradient id={`${id}-shine`} x1="0" y1="0" x2="1" y2="0">
                  <stop stopColor="#fff5e3" stopOpacity="0" />
                  <stop offset="0.5" stopColor="#fff5e3" stopOpacity="0.6" />
                  <stop offset="1" stopColor="#fff5e3" stopOpacity="0" />
                </linearGradient>
                <clipPath id={`${id}-disc`}>
                  <circle cx="110" cy="104" r="89" />
                </clipPath>
                <path id={`${id}-lettering`} d="M110 180 a76 76 0 1 1 0-152 a76 76 0 1 1 0 152" />
                <path
                  id={`${id}-star`}
                  d="M0-6 1.8-1.9 6-1.9 2.6 0.8 3.8 5.5 0 2.8-3.8 5.5-2.6 0.8-6-1.9-1.8-1.9Z"
                />
              </defs>

              {/* Ribbons */}
              <path
                d="M66 161 111 177 87 254 66 232 40 238Z"
                fill={`url(#${id}-blue)`}
                stroke="#fff5e5"
                strokeWidth="5"
                strokeLinejoin="round"
              />
              <path
                d="M112 177 155 161 181 238 155 232 137 254Z"
                fill={`url(#${id}-orchid)`}
                stroke="#fff5e5"
                strokeWidth="5"
                strokeLinejoin="round"
              />
              <path
                d="M73 174 54 224M145 174 166 224"
                fill="none"
                stroke="#fff5e5"
                strokeWidth="1.4"
                opacity="0.55"
              />

              {/* Medal */}
              <polygon
                points={RIM_POINTS}
                fill={`url(#${id}-rim)`}
                stroke="#fff5e5"
                strokeWidth="6"
                strokeLinejoin="round"
              />
              <circle cx="110" cy="104" r="89" fill={`url(#${id}-rim)`} stroke="#754022" strokeWidth="1.5" />
              <circle cx="110" cy="104" r="83" fill="#63371f" stroke="#ffdda9" strokeWidth="1.5" />
              <circle cx="110" cy="104" r="65" fill={`url(#${id}-face)`} stroke="#efc193" strokeWidth="1.6" />
              <circle cx="110" cy="104" r="60" fill="none" stroke="#8f522f" strokeWidth="0.9" opacity="0.75" />
              <circle cx="110" cy="105" r="58" fill="none" stroke="#fff0cf" strokeWidth="0.9" opacity="0.7" />
              <path d="M42 78 A73 73 0 0 1 139 38" fill="none" stroke="#fff0cf" strokeWidth="2" opacity="0.55" />

              <text fill="#fff3df" fontFamily="Arial, sans-serif" fontSize="12" fontWeight="700" textAnchor="middle">
                <textPath href={`#${id}-lettering`} startOffset="50%" textLength="420" lengthAdjust="spacing">
                  GEORGETOWN TIMES · READER'S CHOICE ·
                </textPath>
              </text>

              <g fill="#66391f">
                <use href={`#${id}-star`} transform="translate(88 78) scale(.7)" />
                <use href={`#${id}-star`} transform="translate(110 75)" />
                <use href={`#${id}-star`} transform="translate(132 78) scale(.7)" />
              </g>

              <text
                x="110"
                y="117"
                textAnchor="middle"
                fontFamily="Georgia, serif"
                fontSize="27"
                fontWeight="700"
                letterSpacing="1"
                fill="#fff1d5"
                opacity="0.75"
              >
                BRONZE
              </text>
              <text
                x="110"
                y="115.5"
                textAnchor="middle"
                fontFamily="Georgia, serif"
                fontSize="27"
                fontWeight="700"
                letterSpacing="1"
                fill="#372015"
              >
                BRONZE
              </text>
              <path d="M82 135H138M95 141H125" stroke="#764528" strokeWidth="1.2" opacity="0.8" />

              <g clipPath={`url(#${id}-disc)`}>
                <path
                  key={shineKey}
                  className="award-badge__shine"
                  d="M-90-5H-45L45 205H0Z"
                  fill={`url(#${id}-shine)`}
                />
              </g>

              {/* Banner */}
              <path
                d="M13 183H48V220H7L18 201Z"
                fill={`url(#${id}-ribbon)`}
                stroke="#fff5e5"
                strokeWidth="3"
                strokeLinejoin="round"
              />
              <path
                d="M172 183H207L202 201 214 220H172Z"
                fill={`url(#${id}-ribbon)`}
                stroke="#fff5e5"
                strokeWidth="3"
                strokeLinejoin="round"
              />
              <path d="M29 204 48 218V185L29 181ZM191 204 172 218V185L191 181Z" fill="#713c23" />
              <path
                d="M29 179Q110 166 191 179V210Q110 197 29 210Z"
                fill={`url(#${id}-ribbon)`}
                stroke="#794426"
                strokeWidth="1.3"
                strokeLinejoin="round"
              />
              <path
                d="M32 182Q110 170 188 182M32 206Q110 194 188 206"
                fill="none"
                stroke="#ffedce"
                strokeWidth="1"
                opacity="0.85"
              />
              <text
                x="110"
                y="195"
                textAnchor="middle"
                fontFamily="Arial, sans-serif"
                fontSize="15"
                fontWeight="800"
                letterSpacing="4"
                fill="#372015"
              >
                AWARD
              </text>
            </svg>
          )}
        </span>
      </span>

      <figcaption className="award-badge__caption">
        <span className="award-badge__name">{AWARD_NAME}</span>
        {variant === "about" && (
          <span id={`${id}-details`} className="award-badge__details">
            <span>[PLACEHOLDER: year]</span>
            <span>[PLACEHOLDER: category]</span>
          </span>
        )}
      </figcaption>
    </figure>
  );
}
