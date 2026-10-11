export interface GatewayConfig {
  supabaseURL: string;
  publishableKey: string;
}
export type HTTP = typeof fetch;
const headers = {
  "content-type": "application/json",
  "cache-control": "no-store",
};
const reply = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });

// This checks only the shape needed to avoid Supabase's legacy no-session global fallback.
// Supabase Auth, not this decoded payload, authenticates the token and verifies its signature.
function hasSessionClaim(authorization: string): boolean {
  try {
    const pieces = authorization.slice(7).split(".");
    if (
      pieces.length !== 3 ||
      pieces.some((piece) => !/^[A-Za-z0-9_-]+$/.test(piece))
    ) return false;
    const encoded = pieces[1].replaceAll("-", "+").replaceAll("_", "/");
    const binary = atob(
      encoded.padEnd(encoded.length + (4 - encoded.length % 4) % 4, "="),
    );
    const payload = JSON.parse(
      new TextDecoder("utf-8", { fatal: true }).decode(
        Uint8Array.from(binary, (c) => c.charCodeAt(0)),
      ),
    );
    return typeof payload?.session_id === "string" &&
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        payload.session_id,
      );
  } catch {
    return false;
  }
}

// The app receives session tokens, never a Supabase API key or a service-role credential.
export function gateway(config: GatewayConfig, http: HTTP = fetch) {
  const base = new URL(config.supabaseURL);
  if (base.protocol !== "https:" || base.username || base.password) {
    throw new Error("invalid_configuration");
  }
  return async (request: Request): Promise<Response> => {
    try {
      if (request.method !== "POST") {
        return reply({ error: "method_not_allowed" }, 405);
      }
      const text = await request.text();
      if (new TextEncoder().encode(text).length > 9_000_000) {
        return reply({ error: "request_too_large" }, 413);
      }
      const body = JSON.parse(text);
      if (!body || typeof body !== "object" || Array.isArray(body)) {
        return reply({ error: "invalid_request" }, 400);
      }
      const route = new URL(request.url).pathname.split("/").slice(-2).join(
        "/",
      );
      const upstreamHeaders: Record<string, string> = {
        apikey: config.publishableKey,
        "content-type": "application/json",
      };
      let url: URL;
      let payload: unknown;
      if (route === "auth/sign-out") {
        const authorization = request.headers.get("authorization");
        if (
          !authorization?.startsWith("Bearer ") ||
          authorization.length > 16384 || !hasSessionClaim(authorization)
        ) {
          return reply({ error: "unauthorized" }, 401);
        }
        // Scope is fixed here. The client cannot request global logout or target another session.
        if (Object.keys(body).length !== 0) {
          return reply({ error: "invalid_request" }, 400);
        }
        upstreamHeaders.authorization = authorization;
        url = new URL("/auth/v1/logout?scope=local", base);
        payload = undefined;
      } else if (route === "auth/sign-in" || route === "auth/refresh") {
        const refresh = route === "auth/refresh";
        if (
          refresh
            ? typeof body.refreshToken !== "string"
            : typeof body.email !== "string" ||
              typeof body.password !== "string"
        ) return reply({ error: "invalid_request" }, 400);
        if (JSON.stringify(body).length > 8192) {
          return reply({ error: "invalid_request" }, 400);
        }
        url = new URL(
          "/auth/v1/token?grant_type=" +
            (refresh ? "refresh_token" : "password"),
          base,
        );
        payload = refresh
          ? { refresh_token: body.refreshToken }
          : { email: body.email, password: body.password };
      } else if (route === "sync/push" || route === "sync/pull") {
        const authorization = request.headers.get("authorization");
        if (
          !authorization?.startsWith("Bearer ") || authorization.length > 16384
        ) return reply({ error: "unauthorized" }, 401);
        upstreamHeaders.authorization = authorization;
        // RLS and auth.uid() validate the session and account binding on the database side.
        if (typeof body.ownerID !== "string") {
          return reply({ error: "invalid_request" }, 400);
        }
        const push = route === "sync/push";
        if (
          push
            ? !Array.isArray(body.operations) || body.operations.length < 1 ||
              body.operations.length > 100
            : !Number.isSafeInteger(body.after) || body.after < 0 ||
              !Number.isInteger(body.limit) || body.limit < 1 ||
              body.limit > 100
        ) return reply({ error: "invalid_request" }, 400);
        url = new URL(
          "/rest/v1/rpc/" + (push ? "caliber_push" : "caliber_pull"),
          base,
        );
        payload = push
          ? { p_owner: body.ownerID, p_operations: body.operations }
          : { p_owner: body.ownerID, p_after: body.after, p_limit: body.limit };
      } else return reply({ error: "not_found" }, 404);
      const response = await http(url, {
        method: "POST",
        headers: upstreamHeaders,
        body: JSON.stringify(payload),
        redirect: "error",
        signal: AbortSignal.timeout(15000),
      });
      if (!response.ok) {
        return reply({
          error: response.status === 401 || response.status === 403
            ? "unauthorized"
            : "request_rejected",
        }, response.status === 401 || response.status === 403 ? 401 : 409);
      }
      if (route === "auth/sign-out") {
        // Supabase Auth returns an empty 204. Never parse or return an upstream logout body.
        if (response.status !== 204) {
          return reply({ error: "invalid_response" }, 502);
        }
        return reply({ signedOut: true });
      }
      const data = await response.json();
      if (route.startsWith("auth/")) {
        if (
          typeof data.access_token !== "string" ||
          typeof data.refresh_token !== "string" ||
          typeof data.user?.id !== "string" ||
          !Number.isFinite(data.expires_in) || data.expires_in <= 0
        ) return reply({ error: "invalid_response" }, 502);
        // Swift's default Date Codable representation is seconds since 2001-01-01 UTC.
        return reply({
          accessToken: data.access_token,
          refreshToken: data.refresh_token,
          subject: data.user.id,
          expiresAt: Date.now() / 1000 + data.expires_in - 978307200,
        });
      }
      return reply(data);
    } catch {
      return reply({ error: "request_failed" }, 400);
    }
  };
}
