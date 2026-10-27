export type AuthRoute =
  | "sign-in"
  | "refresh"
  | "recovery-request"
  | "recovery-verify"
  | "food-photo";
export interface AuthBudget {
  consume(route: AuthRoute, identifier: string): Promise<{
    allowed: boolean;
    retryAfter: number;
  }>;
}

// A missing or unreachable guard closes pre-login routes; it never silently allows them.
export const unavailableAuthBudget: AuthBudget = {
  consume: () => Promise.reject(new Error("auth_guard_unavailable")),
};

export class DatabaseAuthBudget implements AuthBudget {
  private readonly key: Promise<CryptoKey>;
  private readonly endpoint: URL;
  constructor(
    private readonly config: {
      supabaseURL: string;
      publishableKey: string;
      guardSecret: string;
    },
    private readonly http: typeof fetch = fetch,
  ) {
    const base = new URL(config.supabaseURL);
    if (
      base.protocol !== "https:" || base.username || base.password ||
      !/^[a-f0-9]{64}$/.test(config.guardSecret)
    ) throw new Error("invalid_auth_guard_configuration");
    this.endpoint = new URL("/rest/v1/rpc/caliber_auth_budget", base);
    const bytes = Uint8Array.from(
      config.guardSecret.match(/../g)!,
      (pair) => parseInt(pair, 16),
    );
    this.key = crypto.subtle.importKey(
      "raw",
      bytes,
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
  }

  async consume(route: AuthRoute, identifier: string) {
    // Keyed hashing prevents someone with a database dump from guessing raw emails.
    // Neither email, password, refresh token nor caller-supplied IP is stored in a bucket.
    const signature = await crypto.subtle.sign(
      "HMAC",
      await this.key,
      new TextEncoder().encode("caliber-auth-v1\0" + route + "\0" + identifier),
    );
    const identityHash = Array.from(
      new Uint8Array(signature),
      (value) => value.toString(16).padStart(2, "0"),
    ).join("");
    const response = await this.http(this.endpoint, {
      method: "POST",
      headers: {
        apikey: this.config.publishableKey,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        p_route: route,
        p_identity_hash: identityHash,
        p_guard: this.config.guardSecret,
      }),
      redirect: "error",
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error("auth_guard_unavailable");
    const data = await response.json();
    if (
      !data || typeof data.allowed !== "boolean" ||
      !Number.isSafeInteger(data.retryAfter) ||
      (data.allowed
        ? data.retryAfter !== 0
        : data.retryAfter < 1 || data.retryAfter > 300)
    ) throw new Error("auth_guard_unavailable");
    return {
      allowed: data.allowed as boolean,
      retryAfter: data.retryAfter as number,
    };
  }
}
