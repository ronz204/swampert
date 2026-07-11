<script lang="ts">
  import type { AgentActivityRow } from "@models/entities";

  let { rows }: { rows: AgentActivityRow[] } = $props();

  function fmtDate(iso: string | null): string {
    if (!iso) return "—";
    return new Date(iso).toLocaleString("es", { dateStyle: "short", timeStyle: "short" });
  }
</script>

<div class="overflow-x-auto rounded-lg border border-border">
  <table class="w-full text-left">
    <thead>
      <tr class="border-b border-border bg-panel text-xs uppercase tracking-wide text-subtext">
        <th class="px-4 py-3 font-medium">Agente</th>
        <th class="px-4 py-3 font-medium">Rol</th>
        <th class="px-4 py-3 font-mono font-medium">Steps</th>
        <th class="px-4 py-3 font-mono font-medium">Tokens prom.</th>
        <th class="px-4 py-3 font-medium">Última actividad</th>
      </tr>
    </thead>
    <tbody>
      {#each rows as row}
        <tr class="border-b border-border transition-colors hover:bg-panel/60">
          <td class="px-4 py-3 text-sm font-medium text-ink">{row.agente}</td>
          <td class="px-4 py-3">
            <span class="rounded border border-border px-1.5 py-0.5 font-mono text-xs text-current">
              {row.role}
            </span>
          </td>
          <td class="px-4 py-3 font-mono text-xs text-ink">
            {row.total_steps.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-ledger">
            {row.tokens_promedio !== null ? Math.round(Number(row.tokens_promedio)).toLocaleString("en-US") : "—"}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-subtext">{fmtDate(row.ultima_actividad)}</td>
        </tr>
      {/each}
      {#if rows.length === 0}
        <tr>
          <td colspan="5" class="px-4 py-10 text-center text-sm text-subtext">
            No hay actividad de agentes para los filtros seleccionados.
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
