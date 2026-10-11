import { gateway } from "./handler.ts";
import { DatabaseAuthBudget, unavailableAuthBudget } from "./auth_budget.ts";
const supabaseURL = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
if (!supabaseURL || !publishableKey) {
  throw new Error("missing_server_configuration");
}
const guardSecret = Deno.env.get("CALIBER_AUTH_GUARD_SECRET");
const config = { supabaseURL, publishableKey };
const budget = guardSecret
  ? new DatabaseAuthBudget({ ...config, guardSecret })
  : unavailableAuthBudget;
Deno.serve(gateway(config, fetch, budget));
