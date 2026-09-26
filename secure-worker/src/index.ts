/**
 * FDE Demo — /secure identity Worker (assignment step 7).
 *
 * Served on tunnel.<zone>/secure* behind Cloudflare Access. Access
 * authenticates the request first and injects the authenticated user's email,
 * so this Worker only has to read it, add the timestamp + country, and (for the
 * flag route) stream the asset from the private R2 bucket.
 *
 *   GET /secure            -> HTML: "${EMAIL} authenticated at ${TIMESTAMP} from ${COUNTRY}"
 *                             where ${COUNTRY} is a link to /secure/${COUNTRY}.
 *   GET /secure/${COUNTRY}  -> the country flag SVG from private R2 (image/svg+xml).
 *
 * Docs:
 *   Access identity headers: https://developers.cloudflare.com/cloudflare-one/identity/authorization-cookie/application-token/
 *   request.cf properties:   https://developers.cloudflare.com/workers/runtime-apis/request/#incomingrequestcfproperties
 *   R2 Workers API:          https://developers.cloudflare.com/r2/api/workers/workers-api-reference/
 */

interface Env {
  FLAGS: R2Bucket;
}

const SECURE_PREFIX = "/secure";

function escapeHtml(input: string): string {
  return input.replace(/[&<>"']/g, (c) => {
    switch (c) {
      case "&":
        return "&amp;";
      case "<":
        return "&lt;";
      case ">":
        return "&gt;";
      case '"':
        return "&quot;";
      default:
        return "&#39;";
    }
  });
}

function identityPage(email: string, timestamp: string, country: string): Response {
  const safeEmail = escapeHtml(email);
  const safeCountry = escapeHtml(country);
  // ${COUNTRY} is rendered as a link to /secure/${COUNTRY} (assignment 7c).
  const body = `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>FDE Demo — authenticated identity</title>
    <style>
      :root { color-scheme: light dark; }
      body { font-family: ui-sans-serif, system-ui, -apple-system, sans-serif; margin: 0; min-height: 100vh; display: grid; place-items: center; background: #f6821f; color: #1d1d1d; }
      main { background: #fff; padding: 2.5rem 3rem; border-radius: 16px; box-shadow: 0 18px 48px rgba(0,0,0,.18); max-width: 40rem; }
      p.identity { font-size: 1.25rem; line-height: 1.6; margin: 0; }
      code { background: #f3f3f3; padding: .1rem .35rem; border-radius: 4px; }
      a { color: #f6821f; font-weight: 600; }
      .eyebrow { color: #ff6633; text-transform: uppercase; letter-spacing: .08em; font-size: .75rem; font-weight: 600; margin: 0 0 1rem; }
    </style>
  </head>
  <body>
    <main>
      <p class="eyebrow">Cloudflare Access · authenticated</p>
      <p class="identity">
        <strong>${safeEmail}</strong> authenticated at <code>${timestamp}</code>
        from <a href="${SECURE_PREFIX}/${encodeURIComponent(country)}">${safeCountry}</a>
      </p>
    </main>
  </body>
</html>`;
  return new Response(body, {
    headers: { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" },
  });
}

async function flagResponse(env: Env, countryRaw: string): Promise<Response> {
  const country = countryRaw.toLowerCase();
  // Basic guard: ISO 3166-1 alpha-2 style codes only.
  if (!/^[a-z]{2}$/.test(country)) {
    return new Response("Unknown country code", { status: 404 });
  }
  const object = await env.FLAGS.get(`${country}.svg`);
  if (!object) {
    return new Response(`No flag stored for '${country}'`, { status: 404 });
  }
  return new Response(object.body, {
    headers: {
      // Assignment 7iii: appropriate content type for the flag asset.
      "content-type": "image/svg+xml; charset=utf-8",
      "cache-control": "public, max-age=3600",
    },
  });
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";

    // /secure -> identity page
    if (path === SECURE_PREFIX) {
      // Access injects the authenticated user's email. Fall back gracefully if
      // the header is missing (e.g. local dev without Access in front).
      const email =
        request.headers.get("Cf-Access-Authenticated-User-Email") ?? "unknown@local.dev";
      const timestamp = new Date().toISOString();
      const country = (request.cf?.country as string | undefined) ?? "XX";
      return identityPage(email, timestamp, country);
    }

    // /secure/${COUNTRY} -> flag asset from private R2
    if (path.startsWith(`${SECURE_PREFIX}/`)) {
      const country = path.slice(`${SECURE_PREFIX}/`.length).split("/")[0];
      return flagResponse(env, country);
    }

    return new Response("Not found", { status: 404 });
  },
} satisfies ExportedHandler<Env>;
