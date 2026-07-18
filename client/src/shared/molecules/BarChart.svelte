<script lang="ts">
  import {
    Chart, BarElement, BarController, CategoryScale,
    LinearScale, Tooltip,
  } from "chart.js";

  Chart.register(BarElement, BarController, CategoryScale, LinearScale, Tooltip);

  export interface BarDatum {
    label: string;
    value: number;
  }

  interface Props {
    data:     BarDatum[];
    title:    string;
    subtitle?: string;
    color?:   string;
  }

  let { data, title, subtitle = "costo estimado en USD", color = "#E8A33D" }: Props = $props();

  let canvas: HTMLCanvasElement;
  let chart: Chart | null = null;

  $effect(() => {
    const sorted = [...data].sort((a, b) => b.value - a.value).slice(0, 10);
    const labels = sorted.map(r => r.label.slice(0, 26));
    const values = sorted.map(r => r.value);

    chart?.destroy();
    chart = new Chart(canvas, {
      type: "bar",
      data: {
        labels,
        datasets: [{
          data: values,
          backgroundColor: color + "BB",
          borderColor: color,
          borderWidth: 1,
          borderRadius: 3,
          borderSkipped: false,
        }],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              title: (items) => items[0]?.label ?? "",
              label: (ctx) => `  $${(ctx.parsed.x as number).toFixed(4)} USD`,
            },
          },
        },
        scales: {
          x: {
            ticks: {
              color: "#8B94A3",
              font: { family: "IBM Plex Mono", size: 10 },
              callback: (v) => `$${Number(v).toFixed(3)}`,
              maxTicksLimit: 5,
            },
            grid: { color: "#2A313B" },
          },
          y: {
            ticks: {
              color: "#8B94A3",
              font: { size: 11 },
            },
            grid: { display: false },
          },
        },
      },
    });
    return () => { chart?.destroy(); chart = null; };
  });
</script>

<div class="flex flex-col rounded-lg border border-border bg-panel p-5">
  <p class="mb-0.5 text-sm font-medium text-ink">{title}</p>
  <p class="mb-4 font-mono text-xs text-subtext">{subtitle}</p>
  <div class="relative h-52 flex-1">
    <canvas bind:this={canvas}></canvas>
  </div>
</div>
