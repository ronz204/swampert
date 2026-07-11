<script lang="ts">
  import type { ExecutionStatus } from "@models/entities";

  let { steps }: { steps: ExecutionStatus[] } = $props();

  const colorMap: Record<ExecutionStatus, string> = {
    pending:   "#8B94A3",
    running:   "#3FB8AF",
    completed: "#4CAF7D",
    failed:    "#E5484D",
  };

  const shapeMap: Record<ExecutionStatus, string> = {
    pending:   "○",
    running:   "○",
    completed: "●",
    failed:    "▲",
  };
</script>

<span
  class="inline-flex items-center gap-0.5 font-mono text-xs"
  aria-label="trace ribbon: {steps.length} steps"
>
  {#each steps as step, i}
    {#if i > 0}
      <span style="color: {colorMap[step]}; opacity: 0.4">─</span>
    {/if}
    <span
      style="color: {colorMap[step]}"
      title={step}
    >{shapeMap[step]}</span>
  {/each}
</span>
