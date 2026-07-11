function parseSlug(): string | null {
  if (typeof window === "undefined") return null;
  const parts = window.location.hostname.split(".");
  return parts.length >= 2 ? parts[0] : null;
}

export const tenant = $state({ slug: parseSlug() });
