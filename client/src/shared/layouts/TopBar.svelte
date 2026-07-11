<script lang="ts">
  import { page } from "$app/stores";
  import { tenant } from "@common/stores/tenant.svelte";
  import { daterange } from "@common/stores/daterange.svelte";

  const tabs = [
    { href: "/dashboard", label: "Dashboard" },
    { href: "/queries",   label: "Consultas" },
  ];
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
      bind:value={daterange.from}
    />
    <span class="text-subtext">—</span>
    <label class="sr-only" for="to-date">Hasta</label>
    <input
      id="to-date"
      type="date"
      class="rounded border border-border bg-void px-2 py-1 font-mono text-xs text-ink
        focus:border-current focus:outline-none"
      bind:value={daterange.to}
    />
  </div>
</header>
