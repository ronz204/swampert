<script lang="ts">
  import type { SwarmSuccessRateRow } from "@models/entities";

  let { rows }: { rows: SwarmSuccessRateRow[] } = $props();
</script>

<div class="overflow-x-auto rounded-lg border border-border">
  <table class="w-full text-left">
    <thead>
      <tr class="border-b border-border bg-panel text-xs uppercase tracking-wide text-subtext">
        <th class="px-4 py-3 font-medium">Swarm</th>
        <th class="px-4 py-3 font-medium">Total tareas</th>
        <th class="px-4 py-3 font-mono font-medium">Completadas</th>
        <th class="px-4 py-3 font-mono font-medium">Fallidas</th>
        <th class="px-4 py-3 font-mono font-medium">Tasa éxito</th>
      </tr>
    </thead>
    <tbody>
      {#each rows as row}
        {@const rate = row.tasa_exito}
        <tr class="border-b border-border transition-colors hover:bg-panel/60">
          <td class="px-4 py-3 text-sm font-medium text-ink">{row.swarm}</td>
          <td class="px-4 py-3 font-mono text-xs text-subtext">
            {row.total_tareas.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-success">
            {row.completadas.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-alarm">
            {row.fallidas.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs">
            {#if rate === null}
              <span class="text-subtext">—</span>
            {:else}
              <span class="{rate >= 80 ? 'text-success' : rate >= 60 ? 'text-caution' : 'text-alarm'}">
                {Number(rate).toFixed(1)}%
              </span>
            {/if}
          </td>
        </tr>
      {/each}
      {#if rows.length === 0}
        <tr>
          <td colspan="5" class="px-4 py-10 text-center text-sm text-subtext">
            No hay datos para los filtros seleccionados.
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
