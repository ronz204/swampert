<script lang="ts">
  import { page } from "$app/stores";
  import { invalidate } from "$app/navigation";
  import { tenant } from "@common/stores/tenant.svelte";
  import { daterange, DATERANGE_DEP } from "@common/stores/daterange.svelte";

  const tabs = [
    { href: "/dashboard", label: "Dashboard" },
    { href: "/queries",   label: "Consultas" },
  ];

  // ── staged: lo que el usuario edita en los inputs, no confirma hasta Aplicar
  let staged = $state({ from: daterange.from, to: daterange.to });

  const isDirty = $derived(staged.from !== daterange.from || staged.to !== daterange.to);

  function applyDateRange() {
    daterange.from = staged.from;
    daterange.to   = staged.to;
    invalidate(DATERANGE_DEP);
  }
</script>

<header
  class="fixed left-14 right-0 top-0 z-10 flex h-14 items-center justify-between
    border-b border-border bg-panel px-5"
>
  <!-- Left: tenant + tabs -->
  <div class="flex items-center gap-5">
    <span class="font-mono text-xs font-semibold text-current">
      {tenant.slug ?? "—"}
    </span>

    <div class="h-4 w-px bg-border"></div>

    <nav class="flex items-center gap-0.5" aria-label="Módulos">
      {#each tabs as tab}
        {@const active = $page.url.pathname.startsWith(tab.href)}
        <a
          href={tab.href}
          class="rounded-md px-3 py-1.5 text-sm font-medium transition-colors
            {active
              ? 'bg-current/10 text-current'
              : 'text-subtext hover:bg-border/60 hover:text-ink'}"
          aria-current={active ? "page" : undefined}
        >
          {tab.label}
        </a>
      {/each}
    </nav>
  </div>

  <!-- Right: date range -->
  <div class="flex items-center gap-2">
    <label class="sr-only" for="from-date">Desde</label>
    <input
      id="from-date"
      type="date"
      class="rounded border border-border bg-void px-2 py-1 font-mono text-xs text-ink
        focus:border-current focus:outline-none"
      bind:value={staged.from}
    />
    <span class="text-subtext">—</span>
    <label class="sr-only" for="to-date">Hasta</label>
    <input
      id="to-date"
      type="date"
      class="rounded border border-border bg-void px-2 py-1 font-mono text-xs text-ink
        focus:border-current focus:outline-none"
      bind:value={staged.to}
    />
    <button
      type="button"
      class="rounded px-3 py-1 text-xs font-medium transition-all
        focus:outline-none focus-visible:ring-2 focus-visible:ring-current
        {isDirty ? 'text-void hover:opacity-90 cursor-pointer' : 'text-subtext cursor-default'}"
      style:background-color={isDirty ? "var(--color-current)" : "transparent"}
      style:border={isDirty ? "none" : "1px solid var(--color-border)"}
      onclick={applyDateRange}
      disabled={!isDirty}
    >
      Aplicar
    </button>
  </div>
</header>
