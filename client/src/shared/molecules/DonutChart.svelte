<script lang="ts">
  import { Chart, ArcElement, Tooltip, Legend, DoughnutController } from "chart.js";
  import type { SwarmSuccessRateRow } from "@models/entities";

  Chart.register(ArcElement, Tooltip, Legend, DoughnutController);

  let { data }: { data: SwarmSuccessRateRow[] } = $props();

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  const completed  = $derived(data.reduce((s, r) => s + r.completadas, 0));
  const failed     = $derived(data.reduce((s, r) => s + r.fallidas, 0));
  const total      = $derived(completed + failed);
  const successPct = $derived(total > 0 ? ((completed / total) * 100).toFixed(1) : null);

  $effect(() => {
    chart?.destroy();
    chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels: ["Completadas", "Fallidas"],
        datasets: [{
          data: [completed, failed],
          backgroundColor: ["#4CAF7D", "#E5484D"],
          borderWidth: 0,
          hoverOffset: 6,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: "72%",
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              color: "#8B94A3",
              boxWidth: 8,
              boxHeight: 8,
              padding: 20,
              font: { family: "IBM Plex Sans", size: 12 },
            },
          },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const v = ctx.parsed as number;
                const pct = total > 0 ? ((v / total) * 100).toFixed(1) : "0";
                return `  ${ctx.label}: ${v.toLocaleString("en-US")} (${pct}%)`;
              },
            },
          },
        },
      },
    });
    return () => { chart?.destroy(); chart = null; };
  });
</script>

<div class="flex flex-col rounded-lg border border-border bg-panel p-5">
  <p class="mb-0.5 text-sm font-medium text-ink">Tasa de éxito por swarm</p>
  <p class="mb-4 font-mono text-xs text-subtext">
    {completed.toLocaleString("en-US")} / {total.toLocaleString("en-US")} ejecuciones completadas
  </p>
  <div class="relative h-52 flex-1">
    <canvas bind:this={canvas}></canvas>
    <div class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center pb-8">
      {#if successPct !== null}
        <span class="font-mono text-3xl font-semibold text-success">{successPct}%</span>
        <span class="mt-0.5 text-xs text-subtext">éxito global</span>
      {:else}
        <span class="font-mono text-2xl text-subtext">—</span>
      {/if}
    </div>
  </div>
</div>
