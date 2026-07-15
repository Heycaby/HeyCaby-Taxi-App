export const money = (cents: number, currency = "EUR") => new Intl.NumberFormat("nl-NL", {
  style: "currency", currency
}).format((Number(cents) || 0) / 100);

export const euros = (value: number, currency = "EUR") => new Intl.NumberFormat("nl-NL", {
  style: "currency", currency
}).format(Number(value) || 0);

export const integer = (value: number) => new Intl.NumberFormat("nl-NL").format(Number(value) || 0);

export const dateTime = (value?: string | null) => value
  ? new Intl.DateTimeFormat("nl-NL", { dateStyle: "medium", timeStyle: "short", timeZone: "Europe/Amsterdam" }).format(new Date(value))
  : "—";

export const relative = (value?: string | null) => {
  if (!value) return "Never";
  const minutes = Math.round((new Date(value).getTime() - Date.now()) / 60_000);
  const formatter = new Intl.RelativeTimeFormat("en", { numeric: "auto" });
  if (Math.abs(minutes) < 60) return formatter.format(minutes, "minute");
  const hours = Math.round(minutes / 60);
  if (Math.abs(hours) < 24) return formatter.format(hours, "hour");
  return formatter.format(Math.round(hours / 24), "day");
};

export const shortId = (value?: string | null) => value ? value.slice(0, 8) : "—";
