import { gateway } from "./handler.ts";
const supabaseURL = Deno.env.get("SUPABASE_URL");
const publishableKey = Deno.env.get("SUPABASE_ANON_KEY");
if (!supabaseURL || !publishableKey) {
  throw new Error("missing_server_configuration");
}
Deno.serve(gateway({ supabaseURL, publishableKey }));
