<script lang="ts">
  import {
    Chart, LineElement, LineController, PointElement,
    CategoryScale, LinearScale, Tooltip, Legend, Filler,
  } from "chart.js";
  import type { ExecutionsByMonthRow } from "@models/entities";

  Chart.register(
    LineElement, LineController, PointElement,
    CategoryScale, LinearScale, Tooltip, Legend, Filler,
  );

  let { data }: { data: ExecutionsByMonthRow[] } = $props();

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  function fmtMonth(iso: string): string {
    return new Date(iso).toLocaleDateString("es", { month: "short", year: "2-digit" });
  }

  $effect(() => {
    const rawMonths = [...new Set(data.map(r => r.mes))].sort();
    const labels    = rawMonths.map(fmtMonth);

    const completed = rawMonths.map(m =>
      data.filter(r => r.mes === m).reduce((s, r) => s + r.completadas, 0));
    const failed = rawMonths.map(m =>
      data.filter(r => r.mes === m).reduce((s, r) => s + r.fallidas, 0));

    chart?.destroy();
    chart = new Chart(canvas, {
      type: "line",
      data: {
        labels,
        datasets: [
          {
            label: "Completadas",
            data: completed,
            borderColor: "#3FB8AF",
            backgroundColor: "#3FB8AF14",
            tension: 0.35,
            fill: true,
            pointRadius: 4,
            pointHoverRadius: 7,
            pointBackgroundColor: "#3FB8AF",
            borderWidth: 2,
          },
          {
            label: "Fallidas",
            data: failed,
            borderColor: "#E5484D",
            backgroundColor: "#E5484D14",
            tension: 0.35,
            fill: true,
            pointRadius: 4,
            pointHoverRadius: 7,
            pointBackgroundColor: "#E5484D",
            borderWidth: 2,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: { mode: "index", intersect: false },
        plugins: {
          legend: {
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
              title: (items) => items[0]?.label ?? "",
              label: (ctx) => `  ${ctx.dataset.label}: ${(ctx.parsed.y as number).toLocaleString("en-US")}`,
            },
          },
        },
        scales: {
          x: {
            ticks: {
              color: "#8B94A3",
              font: { family: "IBM Plex Mono", size: 11 },
              maxRotation: 0,
            },
            grid: { color: "#2A313B" },
          },
          y: {
            ticks: {
              color: "#8B94A3",
              font: { family: "IBM Plex Mono", size: 11 },
            },
            grid: { color: "#2A313B" },
            beginAtZero: true,
          },
        },
      },
    });
    return () => { chart?.destroy(); chart = null; };
  });
</script>

<div class="flex flex-col rounded-lg border border-border bg-panel p-5">
  <p class="mb-0.5 text-sm font-medium text-ink">Tendencia de ejecuciones</p>
  <p class="mb-4 font-mono text-xs text-subtext">completadas vs fallidas por mes</p>
  <div class="relative h-44 flex-1">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>
