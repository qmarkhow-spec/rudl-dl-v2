const isAllowedOrigin = (origin: string | null): string | null => {
  if (!origin) return null;
  try {
    const url = new URL(origin);
    const host = url.hostname.toLowerCase();
    if (host === 'localhost' || host === '127.0.0.1') return origin;
    if (host === 'mycowbay.com' || host.endsWith('.mycowbay.com')) return origin;
  } catch {
    return null;
  }
  return null;
};

export const buildCorsHeaders = (
  origin: string | null,
  options: { allowCredentials?: boolean } = {}
): HeadersInit => {
  const allowed = isAllowedOrigin(origin);
  if (!allowed) return {};
  const headers: HeadersInit = {
    'Access-Control-Allow-Origin': allowed,
    'Access-Control-Allow-Methods': 'GET,POST,PATCH,DELETE',
    'Access-Control-Allow-Headers': 'content-type, authorization',
    'Access-Control-Max-Age': '600',
    Vary: 'Origin',
  };
  if (options.allowCredentials) {
    (headers as Record<string, string>)['Access-Control-Allow-Credentials'] = 'true';
  }
  return headers;
};
