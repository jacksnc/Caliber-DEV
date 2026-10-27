import Anthropic from "@anthropic-ai/sdk";
import type { AuthBudget } from "./auth_budget.ts";

// FUEL-10 / AI-07: a vision model proposes the foods in a meal photo and their weights. It never
// supplies calories or macros; the app maps each item to a database food and does the math, and
// the person confirms every item before anything is logged.

export type Confidence = "low" | "medium" | "high";
export interface FoodPhotoItem {
  name: string;
  grams: number;
  confidence: Confidence;
}
export interface FoodPhotoProposal {
  items: FoodPhotoItem[];
}
/** Returns null when the model declines the photo. */
export type FoodPhotoProposer = (
  jpegBase64: string,
) => Promise<FoodPhotoProposal | null>;

export const foodPhotoModel = "claude-opus-5-5";
export const foodPhotoPromptVersion = "food-photo-v1";
const maxItems = 8;

const schema = {
  type: "object",
  additionalProperties: false,
  required: ["items"],
  properties: {
    items: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "grams", "confidence"],
        properties: {
          name: { type: "string" },
          grams: { type: "number" },
          confidence: { type: "string", enum: ["low", "medium", "high"] },
        },
      },
    },
  },
};

const system =
  `You look at one photo of a meal and list the separate foods you can see, each with an estimate of its edible weight in grams as served, and how confident you are in that weight.
Name each food plainly, the way it would appear in a food database (for example "white rice, cooked" or "chicken breast, grilled").
List a sauce, dressing or cooking oil only when it is visible. Do not give calories, macros, nutrients, health advice or diet advice.
If the photo does not show food, return an empty list.`;

/** Checks a model reply before it reaches the app; anything unexpected is rejected, not repaired. */
export function parseProposal(text: string): FoodPhotoProposal | null {
  let data: unknown;
  try {
    data = JSON.parse(text);
  } catch {
    return null;
  }
  if (!data || typeof data !== "object" || Array.isArray(data)) return null;
  const items = (data as { items?: unknown }).items;
  if (!Array.isArray(items) || items.length > maxItems) return null;
  const parsed: FoodPhotoItem[] = [];
  for (const item of items) {
    if (!item || typeof item !== "object") return null;
    const { name, grams, confidence } = item as Record<string, unknown>;
    if (
      typeof name !== "string" || name.trim().length < 1 ||
      name.trim().length > 80 || typeof grams !== "number" ||
      !Number.isFinite(grams) || grams < 1 || grams > 3000 ||
      !["low", "medium", "high"].includes(confidence as string)
    ) return null;
    parsed.push({
      name: name.trim(),
      grams: Math.round(grams),
      confidence: confidence as Confidence,
    });
  }
  return { items: parsed };
}

export function anthropicFoodPhotoProposer(
  client: Anthropic,
): FoodPhotoProposer {
  return async (jpegBase64) => {
    const response = await client.beta.messages.create({
      model: foodPhotoModel,
      max_tokens: 16000,
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system,
      output_config: {
        effort: "medium",
        format: { type: "json_schema", schema },
      },
      messages: [{
        role: "user",
        content: [
          {
            type: "image",
            source: {
              type: "base64",
              media_type: "image/jpeg",
              data: jpegBase64,
            },
          },
          { type: "text", text: "List the foods in this meal photo." },
        ],
      }],
    });
    if (response.stop_reason === "refusal") return null;
    for (const block of response.content) {
      if (block.type === "text") return parseProposal(block.text);
    }
    return null;
  };
}

/** About 1.5 MB of JPEG; the app sends a downscaled photo with no metadata. */
export const maxImageBase64Length = 2_000_000;

/**
 * The `ai/food-photo` route after the body is read. The session token is checked with Supabase
 * Auth, the account's budget is spent, and only then is the provider called. The photo is not
 * stored or logged here.
 */
export async function foodPhotoRoute(
  body: Record<string, unknown>,
  authorization: string | null,
  verifySubject: (authorization: string) => Promise<string | null>,
  budget: AuthBudget,
  proposer: FoodPhotoProposer | undefined,
): Promise<
  { status: number; body: unknown; headers?: Record<string, string> }
> {
  if (!proposer) return { status: 503, body: { error: "not_configured" } };
  if (
    !authorization?.startsWith("Bearer ") || authorization.length > 16384
  ) return { status: 401, body: { error: "unauthorized" } };
  const image = body.image;
  if (
    Object.keys(body).length !== 1 || typeof image !== "string" ||
    image.length < 100 || image.length > maxImageBase64Length ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(image) || !image.startsWith("/9j/")
  ) return { status: 400, body: { error: "invalid_request" } };
  const subject = await verifySubject(authorization);
  if (!subject) return { status: 401, body: { error: "unauthorized" } };
  let allowance;
  try {
    allowance = await budget.consume("food-photo", subject);
  } catch {
    return { status: 503, body: { error: "temporarily_unavailable" } };
  }
  if (!allowance.allowed) {
    return {
      status: 429,
      body: { error: "rate_limited" },
      headers: { "retry-after": String(allowance.retryAfter) },
    };
  }
  let proposal;
  try {
    proposal = await proposer(image);
  } catch {
    return { status: 502, body: { error: "provider_unavailable" } };
  }
  if (!proposal) return { status: 422, body: { error: "no_estimate" } };
  return {
    status: 200,
    body: {
      items: proposal.items,
      model: foodPhotoModel,
      promptVersion: foodPhotoPromptVersion,
    },
  };
}
