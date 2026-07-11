<script lang="ts">
  import type { ExecutionsByMonthRow } from "@models/entities";

  let { rows }: { rows: ExecutionsByMonthRow[] } = $props();

  function fmtMonth(iso: string): string {
    return new Date(iso).toLocaleDateString("es", { month: "long", year: "numeric" });
  }
</script>

<div class="overflow-x-auto rounded-lg border border-border">
  <table class="w-full text-left">
    <thead>
      <tr class="border-b border-border bg-panel text-xs uppercase tracking-wide text-subtext">
        <th class="px-4 py-3 font-medium">Mes</th>
        <th class="px-4 py-3 font-medium">Swarm</th>
        <th class="px-4 py-3 font-mono font-medium">Total</th>
        <th class="px-4 py-3 font-mono font-medium">Completadas</th>
        <th class="px-4 py-3 font-mono font-medium">Fallidas</th>
        <th class="px-4 py-3 font-mono font-medium">En curso</th>
      </tr>
    </thead>
    <tbody>
      {#each rows as row}
        <tr class="border-b border-border transition-colors hover:bg-panel/60">
          <td class="px-4 py-3 font-mono text-xs text-subtext">{fmtMonth(row.mes)}</td>
          <td class="px-4 py-3 text-sm text-ink">{row.swarm}</td>
          <td class="px-4 py-3 font-mono text-xs text-ink">
            {row.total.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-success">
            {row.completadas.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-alarm">
            {row.fallidas.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-current">
            {row.en_curso.toLocaleString("en-US")}
          </td>
        </tr>
      {/each}
      {#if rows.length === 0}
        <tr>
          <td colspan="6" class="px-4 py-10 text-center text-sm text-subtext">
            No hay ejecuciones en el rango de fechas seleccionado.
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
