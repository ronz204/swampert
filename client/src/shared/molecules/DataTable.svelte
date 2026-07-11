<script lang="ts">
  import type { TopByCostRow } from "@models/entities";
  import StatusBadge from "@shared/atoms/StatusBadge.svelte";

  let { rows }: { rows: TopByCostRow[] } = $props();

  function fmtDate(iso: string): string {
    return new Date(iso).toLocaleString("es", { dateStyle: "short", timeStyle: "short" });
  }
</script>

<div class="overflow-x-auto rounded-lg border border-border">
  <table class="w-full text-left">
    <thead>
      <tr class="border-b border-border bg-panel/80 text-xs uppercase tracking-widest text-subtext">
        <th class="px-4 py-3 font-medium">Tarea</th>
        <th class="px-4 py-3 font-medium">Execution ID</th>
        <th class="px-4 py-3 font-medium">Status</th>
        <th class="px-4 py-3 font-medium">Inicio</th>
        <th class="px-4 py-3 font-mono font-medium text-right">Tokens</th>
        <th class="px-4 py-3 font-mono font-medium text-right">Costo</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-border">
      {#each rows as row}
        <tr class="transition-colors hover:bg-border/20">
          <td class="px-4 py-3 text-sm text-ink">{row.tarea}</td>
          <td class="px-4 py-3 font-mono text-xs text-subtext">
            {row.execution_id.slice(0, 8)}<span class="opacity-40">…</span>
          </td>
          <td class="px-4 py-3">
            <StatusBadge status={row.status} />
          </td>
          <td class="px-4 py-3 font-mono text-xs text-subtext">{fmtDate(row.started_at)}</td>
          <td class="px-4 py-3 text-right font-mono text-xs text-ink">
            {row.total_tokens.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 text-right font-mono text-xs text-ledger">
            ${Number(row.costo_total).toFixed(4)}
          </td>
        </tr>
      {/each}

      {#if rows.length === 0}
        <tr>
          <td colspan="6" class="px-4 py-12 text-center text-sm text-subtext">
            No hay ejecuciones para los filtros seleccionados.
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
