import { gateway } from "./handler.ts";
import { DatabaseAuthBudget, unavailableAuthBudget } from "./auth_budget.ts";
import Anthropic from "@anthropic-ai/sdk";
import { anthropicFoodPhotoProposer } from "./food_photo.ts";
const supabaseURL = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
if (!supabaseURL || !publishableKey) {
  throw new Error("missing_server_configuration");
}
const guardSecret = Deno.env.get("CALIBER_AUTH_GUARD_SECRET");
const config = {
  supabaseURL,
  publishableKey,
  serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
};
const budget = guardSecret
  ? new DatabaseAuthBudget({ ...config, guardSecret })
  : unavailableAuthBudget;
// FUEL-10 stays off until the owner sets both: the provider key never reaches the app.
const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
const foodPhoto = anthropicKey && guardSecret &&
    Deno.env.get("CALIBER_FOOD_PHOTO_ENABLED") === "true"
  ? anthropicFoodPhotoProposer(new Anthropic({ apiKey: anthropicKey }))
  : undefined;
Deno.serve(gateway(config, fetch, budget, foodPhoto));
