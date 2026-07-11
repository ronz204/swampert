<script lang="ts">
  import type { ExecutionStatus } from "@models/entities";

  interface Props {
    status: ExecutionStatus[];
    onchange: (status: ExecutionStatus[]) => void;
    onreset: () => void;
  }

  let { status, onchange, onreset }: Props = $props();

  const ALL_STATUSES: ExecutionStatus[] = [
    "pending",
    "running",
    "completed",
    "failed",
  ];

  let statusOpen = $state(true);

  function toggle(s: ExecutionStatus) {
    const next = status.includes(s)
      ? status.filter((x) => x !== s)
      : [...status, s];
    onchange(next);
  }
</script>

<aside
  class="flex w-56 shrink-0 flex-col gap-4 rounded-lg border border-border
    bg-panel p-4 text-sm"
>
  <div>
    <button
      type="button"
      class="flex w-full items-center justify-between font-medium text-ink
        hover:text-current focus:outline-none"
      onclick={() => (statusOpen = !statusOpen)}
    >
      Status
      <span class="text-subtext">{statusOpen ? "▾" : "▸"}</span>
    </button>

    {#if statusOpen}
      <ul class="mt-2 space-y-1">
        {#each ALL_STATUSES as s}
          <li>
            <label
              class="flex cursor-pointer items-center gap-2 rounded px-1 py-0.5
              hover:bg-border/40"
            >
              <input
                type="checkbox"
                class="accent-current"
                checked={status.includes(s)}
                onchange={() => toggle(s)}
              />
              <span class="font-mono text-xs text-ink capitalize">{s}</span>
            </label>
          </li>
        {/each}
      </ul>
    {/if}
  </div>

  <div class="mt-auto flex gap-2 border-t border-border pt-4">
    <button
      type="button"
      class="flex-1 rounded px-3 py-1.5 text-xs text-subtext
        hover:text-ink focus:outline-none focus-visible:ring-2 focus-visible:ring-current"
      onclick={onreset}
    >
      Reiniciar
    </button>
    <button
      type="button"
      class="flex-1 rounded bg-current px-3 py-1.5 text-xs
        font-medium text-void transition-opacity hover:opacity-90
        focus:outline-none focus-visible:ring-2 focus-visible:ring-current"
    >
      Aplicar
    </button>
  </div>
</aside>
