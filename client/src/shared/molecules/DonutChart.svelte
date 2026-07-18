<script lang="ts">
  import { Chart, ArcElement, Tooltip, Legend, DoughnutController } from "chart.js";

  Chart.register(ArcElement, Tooltip, Legend, DoughnutController);

  export interface StatusCounts {
    pending:   number;
    running:   number;
    completed: number;
    failed:    number;
  }

  let { data }: { data: StatusCounts } = $props();

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  const total = $derived(data.pending + data.running + data.completed + data.failed);

  $effect(() => {
    chart?.destroy();
    chart = new Chart(canvas, {
      type: "doughnut",
      data: {
        labels: ["Completadas", "En curso", "Pendientes", "Fallidas"],
        datasets: [{
          data: [data.completed, data.running, data.pending, data.failed],
          backgroundColor: ["#4CAF7D", "#3FB8AF", "#8B94A3", "#E5484D"],
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
              padding: 16,
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
  <p class="mb-0.5 text-sm font-medium text-ink">Ejecuciones por status</p>
  <p class="mb-4 font-mono text-xs text-subtext">
    {total.toLocaleString("en-US")} ejecuciones en el rango
  </p>
  <div class="relative h-52 flex-1">
    <canvas bind:this={canvas}></canvas>
    <div class="pointer-events-none absolute inset-0 flex flex-col items-center justify-center pb-8">
      {#if total > 0}
        <span class="font-mono text-3xl font-semibold text-ink">{total.toLocaleString("en-US")}</span>
        <span class="mt-0.5 text-xs text-subtext">total</span>
      {:else}
        <span class="font-mono text-2xl text-subtext">—</span>
      {/if}
    </div>
  </div>
</div>
