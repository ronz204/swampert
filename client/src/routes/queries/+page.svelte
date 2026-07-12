<script lang="ts">
  import type { PageProps } from "./$types";
  import type { ExecutionStatus, ErrorSeverity } from "@models/entities";
  import FilterChip         from "@shared/molecules/FilterChip.svelte";
  import DataTable          from "@shared/molecules/DataTable.svelte";
  import SuccessRateTable   from "@shared/molecules/SuccessRateTable.svelte";
  import AgentActivityTable from "@shared/molecules/AgentActivityTable.svelte";
  import TimelineTable      from "@shared/molecules/TimelineTable.svelte";
  import ErrorsTable        from "@shared/molecules/ErrorsTable.svelte";

  let { data }: PageProps = $props();

  type QueryId = "q1" | "q2" | "q3" | "q4" | "q5";

  const QUERIES: { id: QueryId; label: string; subtitle: string }[] = [
    { id: "q1", label: "Top por costo",      subtitle: "Ejecuciones ordenadas por gasto en tokens" },
    { id: "q2", label: "Tasa de éxito",      subtitle: "Completadas vs fallidas por swarm" },
    { id: "q3", label: "Actividad agentes",  subtitle: "Steps y tokens promedio por agente" },
    { id: "q4", label: "Timeline",           subtitle: "Ejecuciones agrupadas por mes y swarm" },
    { id: "q5", label: "Top errores",        subtitle: "Tareas con mayor incidencia de fallas" },
  ];

  let activeQuery = $state<QueryId>("q1");

  // ── staged: lo que el usuario selecciona en el panel (no confirma hasta Aplicar)
  let staged = $state({
    status:              [] as ExecutionStatus[],
    swarmSearch:         "",
    roleFilter:          "",
    timelineSwarmSearch: "",
    severity:            ["critical", "high"] as ErrorSeverity[],
  });

  // ── applied: lo que realmente filtra la tabla
  let applied = $state({
    status:              [] as ExecutionStatus[],
    swarmSearch:         "",
    roleFilter:          "",
    timelineSwarmSearch: "",
    severity:            ["critical", "high"] as ErrorSeverity[],
  });

  const isDirty = $derived(
    staged.status.join()       !== applied.status.join()       ||
    staged.swarmSearch         !== applied.swarmSearch         ||
    staged.roleFilter          !== applied.roleFilter          ||
    staged.timelineSwarmSearch !== applied.timelineSwarmSearch ||
    staged.severity.join()     !== applied.severity.join()
  );

  function applyFilters() {
    applied.status              = [...staged.status];
    applied.swarmSearch         = staged.swarmSearch;
    applied.roleFilter          = staged.roleFilter;
    applied.timelineSwarmSearch = staged.timelineSwarmSearch;
    applied.severity            = [...staged.severity];
  }

  function resetFilters() {
    staged.status              = [];
    staged.swarmSearch         = "";
    staged.roleFilter          = "";
    staged.timelineSwarmSearch = "";
    staged.severity            = ["critical", "high"];
    applyFilters();
  }

  // ── tablas filtradas usan applied ───────────────────────────────────────────
  const filteredQ1 = $derived(
    applied.status.length === 0
      ? data.topCost
      : data.topCost.filter(r => applied.status.includes(r.status))
  );

  const filteredQ2 = $derived(
    applied.swarmSearch.trim() === ""
      ? data.successRate
      : data.successRate.filter(r =>
          r.swarm.toLowerCase().includes(applied.swarmSearch.toLowerCase())
        )
  );

  const filteredQ3 = $derived(
    applied.roleFilter === ""
      ? data.agentActivity
      : data.agentActivity.filter(r => r.role === applied.roleFilter)
  );

  const agentRoles = $derived([...new Set(data.agentActivity.map(r => r.role))].sort());

  const filteredQ4 = $derived(
    applied.timelineSwarmSearch.trim() === ""
      ? data.timeline
      : data.timeline.filter(r =>
          r.swarm.toLowerCase().includes(applied.timelineSwarmSearch.toLowerCase())
        )
  );

  const filteredQ5 = $derived(
    applied.severity.length === 0
      ? data.topErrors
      : data.topErrors.filter(r => applied.severity.includes(r.severity as ErrorSeverity))
  );

  // ── toggle helpers operan sobre staged ──────────────────────────────────────
  function toggleStatus(s: ExecutionStatus) {
    staged.status = staged.status.includes(s)
      ? staged.status.filter(x => x !== s)
      : [...staged.status, s];
  }

  function toggleSeverity(s: ErrorSeverity) {
    staged.severity = staged.severity.includes(s)
      ? staged.severity.filter(x => x !== s)
      : [...staged.severity, s];
  }

  // ── chips reflejan applied (lo que está activo en la tabla) ─────────────────
  const ALL_SEVERITIES: ErrorSeverity[] = ["critical", "high", "medium", "low"];

  const activeChips = $derived<{ label: string; remove: () => void }[]>([
    ...applied.status.map(s => ({
      label: `Status: ${s}`,
      remove: () => {
        applied.status = applied.status.filter(x => x !== s);
        staged.status  = staged.status.filter(x => x !== s);
      },
    })),
    ...(applied.swarmSearch && activeQuery === "q2"
      ? [{ label: `Swarm: ${applied.swarmSearch}`, remove: () => { applied.swarmSearch = ""; staged.swarmSearch = ""; } }]
      : []),
    ...(applied.roleFilter && activeQuery === "q3"
      ? [{ label: `Rol: ${applied.roleFilter}`, remove: () => { applied.roleFilter = ""; staged.roleFilter = ""; } }]
      : []),
    ...(applied.timelineSwarmSearch && activeQuery === "q4"
      ? [{ label: `Swarm: ${applied.timelineSwarmSearch}`, remove: () => { applied.timelineSwarmSearch = ""; staged.timelineSwarmSearch = ""; } }]
      : []),
    ...(activeQuery === "q5" ? applied.severity : []).map(s => ({
      label: `Severidad: ${s}`,
      remove: () => {
        applied.severity = applied.severity.filter(x => x !== s);
        staged.severity  = staged.severity.filter(x => x !== s);
      },
    })),
  ]);

  const rowCount = $derived({
    q1: filteredQ1.length,
    q2: filteredQ2.length,
    q3: filteredQ3.length,
    q4: filteredQ4.length,
    q5: filteredQ5.length,
  });
</script>

<svelte:head>
  <title>Consultas — Swampert</title>
</svelte:head>

<div class="flex gap-5">
  <!-- ── Filter panel ─────────────────────────────────────────────────── -->
  <aside class="flex w-52 shrink-0 flex-col gap-4 rounded-lg border border-border bg-panel p-4 text-sm">

    <!-- Q1: status -->
    {#if activeQuery === "q1"}
      <div>
        <p class="mb-2 text-xs font-medium uppercase tracking-wide text-subtext">Status</p>
        <ul class="space-y-1">
          {#each ["pending","running","completed","failed"] as s}
            <li>
              <label class="flex cursor-pointer items-center gap-2 rounded px-1 py-0.5 hover:bg-border/40">
                <input
                  type="checkbox"
                  class="accent-current"
                  checked={staged.status.includes(s as ExecutionStatus)}
                  onchange={() => toggleStatus(s as ExecutionStatus)}
                />
                <span class="font-mono text-xs text-ink capitalize">{s}</span>
                <span class="ml-auto font-mono text-xs text-subtext">
                  {data.topCost.filter(r => r.status === s).length}
                </span>
              </label>
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <!-- Q2: swarm search -->
    {#if activeQuery === "q2"}
      <div>
        <p class="mb-2 text-xs font-medium uppercase tracking-wide text-subtext">Swarm</p>
        <input
          type="search"
          placeholder="Buscar swarm…"
          class="w-full rounded border border-border bg-void px-2 py-1.5 font-mono text-xs
            text-ink placeholder:text-subtext focus:border-current focus:outline-none"
          bind:value={staged.swarmSearch}
        />
      </div>
    {/if}

    <!-- Q3: role -->
    {#if activeQuery === "q3"}
      <div>
        <p class="mb-2 text-xs font-medium uppercase tracking-wide text-subtext">Rol</p>
        <ul class="space-y-1">
          {#each agentRoles as role}
            <li>
              <label class="flex cursor-pointer items-center gap-2 rounded px-1 py-0.5 hover:bg-border/40">
                <input
                  type="radio"
                  name="role"
                  class="accent-current"
                  checked={staged.roleFilter === role}
                  onchange={() => { staged.roleFilter = staged.roleFilter === role ? "" : role; }}
                />
                <span class="font-mono text-xs text-ink">{role}</span>
                <span class="ml-auto font-mono text-xs text-subtext">
                  {data.agentActivity.filter(r => r.role === role).length}
                </span>
              </label>
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <!-- Q4: swarm search -->
    {#if activeQuery === "q4"}
      <div>
        <p class="mb-2 text-xs font-medium uppercase tracking-wide text-subtext">Swarm</p>
        <input
          type="search"
          placeholder="Buscar swarm…"
          class="w-full rounded border border-border bg-void px-2 py-1.5 font-mono text-xs
            text-ink placeholder:text-subtext focus:border-current focus:outline-none"
          bind:value={staged.timelineSwarmSearch}
        />
      </div>
    {/if}

    <!-- Q5: severity -->
    {#if activeQuery === "q5"}
      <div>
        <p class="mb-2 text-xs font-medium uppercase tracking-wide text-subtext">Severidad</p>
        <ul class="space-y-1">
          {#each ALL_SEVERITIES as sev}
            <li>
              <label class="flex cursor-pointer items-center gap-2 rounded px-1 py-0.5 hover:bg-border/40">
                <input
                  type="checkbox"
                  class="accent-current"
                  checked={staged.severity.includes(sev)}
                  onchange={() => toggleSeverity(sev)}
                />
                <span class="font-mono text-xs capitalize
                  {sev === 'critical' ? 'text-alarm' : sev === 'high' ? 'text-caution' : 'text-subtext'}">
                  {sev}
                </span>
                <span class="ml-auto font-mono text-xs text-subtext">
                  {data.topErrors.filter(r => r.severity === sev).length}
                </span>
              </label>
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <div class="mt-auto flex gap-2 border-t border-border pt-4">
      <button
        type="button"
        class="flex-1 rounded px-3 py-1.5 text-xs text-subtext hover:text-ink
          focus:outline-none focus-visible:ring-2 focus-visible:ring-current"
        onclick={resetFilters}
      >
        Reiniciar
      </button>
      <button
        type="button"
        class="flex-1 rounded px-3 py-1.5 text-xs font-medium transition-all
          focus:outline-none focus-visible:ring-2 focus-visible:ring-current
          {isDirty ? 'text-void hover:opacity-90 cursor-pointer' : 'text-subtext cursor-default'}"
        style:background-color={isDirty ? "var(--color-current)" : "transparent"}
        onclick={applyFilters}
        disabled={!isDirty}
      >
        Aplicar
      </button>
    </div>
  </aside>

  <!-- ── Main content ─────────────────────────────────────────────────── -->
  <div class="min-w-0 flex-1 space-y-4">

    <!-- Query tabs -->
    <div class="flex items-end gap-0 border-b border-border">
      {#each QUERIES as q}
        <button
          type="button"
          class="px-4 py-2 text-sm transition-colors
            {activeQuery === q.id
              ? 'border-b-2 border-current text-current font-medium -mb-px'
              : 'text-subtext hover:text-ink'}"
          onclick={() => { activeQuery = q.id; }}
        >
          {q.label}
        </button>
      {/each}
    </div>

    <!-- Active query info + row count -->
    {#each QUERIES.filter(q => q.id === activeQuery) as q}
      <div class="flex items-center justify-between">
        <p class="text-xs text-subtext">{q.subtitle}</p>
        <span class="font-mono text-xs text-subtext">
          {rowCount[activeQuery]} resultado{rowCount[activeQuery] !== 1 ? "s" : ""}
        </span>
      </div>
    {/each}

    <!-- Active filter chips -->
    {#if activeChips.length > 0}
      <div class="flex flex-wrap gap-2">
        {#each activeChips as chip}
          <FilterChip label={chip.label} onremove={chip.remove} />
        {/each}
      </div>
    {/if}

    <!-- Table -->
    {#if activeQuery === "q1"}
      <DataTable rows={filteredQ1} />
    {:else if activeQuery === "q2"}
      <SuccessRateTable rows={filteredQ2} />
    {:else if activeQuery === "q3"}
      <AgentActivityTable rows={filteredQ3} />
    {:else if activeQuery === "q4"}
      <TimelineTable rows={filteredQ4} />
    {:else if activeQuery === "q5"}
      <ErrorsTable rows={filteredQ5} />
    {/if}
  </div>
</div>
