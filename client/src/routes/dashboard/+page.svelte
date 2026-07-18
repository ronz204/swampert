<script lang="ts">
  import type { PageProps } from "./$types";
  import KpiCard     from "@shared/molecules/KpiCard.svelte";
  import DonutChart  from "@shared/molecules/DonutChart.svelte";
  import BarChart    from "@shared/molecules/BarChart.svelte";
  import LineChart   from "@shared/molecules/LineChart.svelte";
  import TraceRibbon from "@shared/atoms/TraceRibbon.svelte";
  import type { ExecutionStatus } from "@models/entities";

  let { data }: PageProps = $props();

  const ribbonSteps = $derived<ExecutionStatus[]>(
    [...data.timeline]
      .sort((a, b) => a.mes.localeCompare(b.mes))
      .slice(-16)
      .map(r =>
        r.fallidas > 0 && r.fallidas > r.completadas * 0.15
          ? "failed"
          : r.en_curso > 0
            ? "running"
            : "completed"
      )
  );

  // distribución de execution_status del rango activo, agregada a partir del
  // mismo timeline que alimenta la línea de tendencia — no hace falta un
  // endpoint aparte porque total/completadas/fallidas/en_curso ya vienen ahí
  const statusCounts = $derived.by(() => {
    const acc = data.timeline.reduce(
      (a, r) => {
        a.completed += r.completadas;
        a.failed    += r.fallidas;
        a.running   += r.en_curso;
        a.total     += r.total;
        return a;
      },
      { completed: 0, failed: 0, running: 0, total: 0 },
    );
    return {
      completed: acc.completed,
      failed:    acc.failed,
      running:   acc.running,
      pending:   Math.max(acc.total - acc.completed - acc.failed - acc.running, 0),
    };
  });

  const costBySwarm = $derived(
    data.costBySwarm.map(r => ({ label: r.swarm, value: r.costo_total })),
  );
</script>

<svelte:head>
  <title>Dashboard — Swampert</title>
</svelte:head>

<div class="space-y-5">

  <!-- KPI row -->
  <div class="grid grid-cols-4 gap-3">
    <KpiCard
      label="Ejecuciones"
      value={data.kpis.executions_count}
      color="current"
    />
    <KpiCard
      label="Costo total"
      value={data.kpis.total_cost}
      color="ledger"
      format="currency"
    />
    <KpiCard
      label="Tasa de error"
      value={data.kpis.error_rate}
      color="alarm"
      format="percent"
    />
    <KpiCard
      label="Agentes activos"
      value={data.kpis.active_agents}
      color="border"
    />
  </div>

  <!-- Trace ribbon -->
  {#if ribbonSteps.length > 0}
    <div class="flex items-center gap-3 rounded-lg border border-border bg-panel/50 px-4 py-2.5">
      <span class="font-mono text-xs text-subtext">traza reciente</span>
      <TraceRibbon steps={ribbonSteps} />
    </div>
  {/if}

  <!-- Charts: 2 columns -->
  <div class="grid grid-cols-2 gap-3">
    <DonutChart data={statusCounts} />
    <BarChart data={costBySwarm} title="Costo por swarm" subtitle="costo estimado en USD, por swarm" />
  </div>

  <LineChart data={data.timeline} />

</div>
