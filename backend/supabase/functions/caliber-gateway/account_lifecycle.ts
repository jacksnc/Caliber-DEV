import type { AuthBudget } from "./auth_budget.ts";

export const accountConsentVersion = "account-access-v1";
type LifecycleConfig = {
  supabaseURL: string;
  publishableKey: string;
  // Read only from the function environment. Used only for self-deletion.
  serviceRoleKey?: string;
};
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const emailIsValid = (value: unknown): value is string =>
  typeof value === "string" && value.length <= 254 &&
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
const exactKeys = (body: Record<string, unknown>, keys: string[]) =>
  Object.keys(body).length === keys.length &&
  keys.every((key) => Object.hasOwn(body, key));
const response = (body: unknown, status = 200, retry?: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json",
      "cache-control": "no-store",
      ...(retry ? { "retry-after": String(retry) } : {}),
    },
  });
const invalid = () => response({ error: "invalid_request" }, 400);
const denied = () => response({ error: "unauthorized" }, 401);
const unavailable = () => response({ error: "temporarily_unavailable" }, 503);

export async function recordAccountConsent(
  config: LifecycleConfig,
  authorization: string,
  http: typeof fetch,
): Promise<boolean> {
  const result = await http(
    new URL("/rest/v1/rpc/caliber_accept_account_access", config.supabaseURL),
    {
      method: "POST",
      headers: {
        apikey: config.publishableKey,
        authorization,
        "content-type": "application/json",
      },
      body: JSON.stringify({ p_version: accountConsentVersion }),
      redirect: "error",
      signal: AbortSignal.timeout(5000),
    },
  );
  if (!result.ok) return false;
  const data = await result.json();
  return data?.accepted === true && data?.version === accountConsentVersion;
}

// Ephemeral recovery/reauthentication sessions never leave this function.
export async function revokeEphemeralSession(
  config: LifecycleConfig,
  token: string,
  http: typeof fetch,
  scope: "local" | "global" = "local",
): Promise<boolean> {
  try {
    const result = await http(
      new URL(`/auth/v1/logout?scope=${scope}`, config.supabaseURL),
      {
        method: "POST",
        headers: {
          apikey: config.publishableKey,
          authorization: `Bearer ${token}`,
        },
        redirect: "error",
        signal: AbortSignal.timeout(5000),
      },
    );
    return result.status === 204;
  } catch {
    return false;
  }
}

export async function accountLifecycle(
  route: string,
  body: Record<string, unknown>,
  authorization: string | null,
  config: LifecycleConfig,
  http: typeof fetch,
  budget: AuthBudget,
): Promise<Response> {
  const call = (
    path: string,
    payload: unknown,
    token?: string,
    method = "POST",
  ) =>
    http(new URL(path, config.supabaseURL), {
      method,
      headers: {
        apikey: config.publishableKey,
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: method === "GET" ? undefined : JSON.stringify(payload),
      redirect: "error",
      signal: AbortSignal.timeout(15000),
    });
  const consume = async (
    kind: "recovery-request" | "recovery-verify" | "sign-in",
    identity: string,
  ) => {
    try {
      const result = await budget.consume(kind, identity.trim().toLowerCase());
      return result.allowed
        ? null
        : response({ error: "rate_limited" }, 429, result.retryAfter);
    } catch {
      return unavailable();
    }
  };
  if (route === "auth/recover") {
    if (!exactKeys(body, ["email"]) || !emailIsValid(body.email)) {
      return invalid();
    }
    const limited = await consume("recovery-request", body.email);
    if (limited) return limited;
    const result = await call("/auth/v1/recover", { email: body.email });
    if (result.status === 429) {
      return response({ error: "rate_limited" }, 429, 60);
    }
    if (result.status >= 500) return unavailable();
    // The response must not disclose whether an email belongs to an account.
    return response({ recoveryRequested: true }, 202);
  }
  if (route === "auth/reset-password") {
    if (
      !exactKeys(body, ["email", "code", "newPassword"]) ||
      !emailIsValid(body.email) || typeof body.code !== "string" ||
      !/^[0-9]{6,10}$/.test(body.code) ||
      typeof body.newPassword !== "string" ||
      body.newPassword.length < 8 || body.newPassword.length > 1024
    ) return invalid();
    const limited = await consume("recovery-verify", body.email);
    if (limited) return limited;
    const verified = await call("/auth/v1/verify", {
      type: "recovery",
      email: body.email,
      token: body.code,
    });
    if (verified.status === 429) {
      return response({ error: "rate_limited" }, 429, 60);
    }
    if (!verified.ok) return denied();
    const session = await verified.json();
    if (
      typeof session?.access_token !== "string" ||
      !uuid.test(session?.user?.id ?? "")
    ) {
      return response({ error: "invalid_response" }, 502);
    }
    let globallyRevoked = false;
    try {
      const changed = await call(
        "/auth/v1/user",
        { password: body.newPassword },
        session.access_token,
        "PUT",
      );
      if (!changed.ok) return response({ error: "password_not_accepted" }, 409);
      globallyRevoked = await revokeEphemeralSession(
        config,
        session.access_token,
        http,
        "global",
      );
      return response({
        passwordUpdated: true,
        sessionsRevoked: globallyRevoked,
      });
    } finally {
      if (!globallyRevoked) {
        await revokeEphemeralSession(config, session.access_token, http);
      }
    }
  }
  if (!authorization?.startsWith("Bearer ") || authorization.length > 16384) {
    return denied();
  }
  if (route === "account/consent") {
    if (
      !exactKeys(body, ["version"]) || body.version !== accountConsentVersion
    ) return invalid();
    return await recordAccountConsent(config, authorization, http)
      ? response({ accepted: true, version: accountConsentVersion })
      : denied();
  }
  if (route !== "account/delete") return response({ error: "not_found" }, 404);
  if (
    !exactKeys(body, ["password", "confirmation"]) ||
    body.confirmation !== "DELETE" ||
    typeof body.password !== "string" || body.password.length < 1 ||
    body.password.length > 1024
  ) return invalid();
  if (!config.serviceRoleKey) return unavailable();
  // Never trust a client-supplied subject, email, owner ID, or decoded unsigned JWT.
  const userResponse = await call(
    "/auth/v1/user",
    undefined,
    authorization.slice(7),
    "GET",
  );
  if (!userResponse.ok) return denied();
  const user = await userResponse.json();
  if (!uuid.test(user?.id ?? "") || !emailIsValid(user?.email)) return denied();
  const limited = await consume("sign-in", user.email);
  if (limited) return limited;
  const reauthenticated = await call("/auth/v1/token?grant_type=password", {
    email: user.email,
    password: body.password,
  });
  if (reauthenticated.status === 429) {
    return response({ error: "rate_limited" }, 429, 60);
  }
  if (!reauthenticated.ok) return denied();
  const session = await reauthenticated.json();
  if (typeof session?.access_token !== "string") return denied();
  let deleted = false;
  try {
    if (session?.user?.id !== user.id) return denied();
    const removed = await http(
      new URL(`/auth/v1/admin/users/${user.id}`, config.supabaseURL),
      {
        method: "DELETE",
        headers: {
          apikey: config.serviceRoleKey,
          authorization: `Bearer ${config.serviceRoleKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({ should_soft_delete: false }),
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      },
    );
    if (removed.status !== 200) {
      return response({ error: "deletion_not_confirmed" }, 409);
    }
    deleted = true;
    // Existing FKs cascade the journal and consent rows. No client-selected target.
    return response({ accountDeleted: true });
  } finally {
    if (!deleted) {
      await revokeEphemeralSession(config, session.access_token, http);
    }
  }
}
