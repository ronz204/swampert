<script lang="ts">
  import type { TopByErrorsRow } from "@models/entities";
  import StatusBadge from "@shared/atoms/StatusBadge.svelte";
  import type { ErrorSeverity } from "@models/entities";

  let { rows }: { rows: TopByErrorsRow[] } = $props();
</script>

<div class="overflow-x-auto rounded-lg border border-border">
  <table class="w-full text-left">
    <thead>
      <tr class="border-b border-border bg-panel text-xs uppercase tracking-wide text-subtext">
        <th class="px-4 py-3 font-medium">Tarea</th>
        <th class="px-4 py-3 font-medium">Tipo de error</th>
        <th class="px-4 py-3 font-medium">Severidad</th>
        <th class="px-4 py-3 font-mono font-medium">Total errores</th>
        <th class="px-4 py-3 font-mono font-medium">Ejecuciones afectadas</th>
      </tr>
    </thead>
    <tbody>
      {#each rows as row}
        <tr class="border-b border-border transition-colors hover:bg-panel/60">
          <td class="px-4 py-3 text-sm text-ink">{row.tarea}</td>
          <td class="px-4 py-3 font-mono text-xs text-subtext">{row.error_type}</td>
          <td class="px-4 py-3">
            <StatusBadge status={row.severity as ErrorSeverity} />
          </td>
          <td class="px-4 py-3 font-mono text-xs text-alarm">
            {row.total_errores.toLocaleString("en-US")}
          </td>
          <td class="px-4 py-3 font-mono text-xs text-subtext">
            {row.execuciones_afectadas.toLocaleString("en-US")}
          </td>
        </tr>
      {/each}
      {#if rows.length === 0}
        <tr>
          <td colspan="5" class="px-4 py-10 text-center text-sm text-subtext">
            No se encontraron errores para los filtros seleccionados.
          </td>
        </tr>
      {/if}
    </tbody>
  </table>
</div>
