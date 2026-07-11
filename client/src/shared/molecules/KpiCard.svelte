<script lang="ts">
  type Color  = "current" | "ledger" | "alarm" | "success" | "border";
  type Format = "integer" | "currency" | "percent";

  interface Props {
    label:  string;
    value:  number | null;
    color:  Color;
    format?: Format;
  }

  let { label, value, color, format = "integer" }: Props = $props();

  const topBorder: Record<Color, string> = {
    current: "border-t-current",
    ledger:  "border-t-ledger",
    alarm:   "border-t-alarm",
    success: "border-t-success",
    border:  "border-t-border",
  };

  const accentText: Record<Color, string> = {
    current: "text-current",
    ledger:  "text-ledger",
    alarm:   "text-alarm",
    success: "text-success",
    border:  "text-subtext",
  };

  function fmt(v: number | null, f: Format): string {
    if (v === null) return "—";
    if (f === "currency") return `$${v.toFixed(2)}`;
    if (f === "percent")  return `${v.toFixed(1)}%`;
    return v.toLocaleString("en-US");
  }

  const isAlarm  = $derived(color === "alarm" && value !== null && value > 10);
  const valueStr = $derived(fmt(value, format));
  const isEmpty  = $derived(value === null || value === 0);
</script>

<article
  class="relative overflow-hidden rounded-lg border border-t-2 border-border bg-panel px-5 py-4
    {topBorder[color]}"
>
  <p class="mb-3 text-xs font-medium uppercase tracking-widest text-subtext">{label}</p>

  <p
    class="font-mono leading-none
      {isAlarm ? 'text-alarm' : isEmpty ? 'text-subtext/60' : 'text-ink'}"
    style="font-size: 2.25rem; font-weight: 600;"
  >
    {valueStr}
  </p>

  <!-- accent dot -->
  <span
    class="absolute right-4 top-4 h-1.5 w-1.5 rounded-full {accentText[color]}
      {isEmpty ? 'opacity-20' : 'opacity-100'}"
    style="background: currentColor"
    aria-hidden="true"
  ></span>
</article>
