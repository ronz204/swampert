<script lang="ts">
  import { tenant } from "@common/stores/tenant.svelte";
</script>

<nav
  class="fixed left-0 top-0 z-20 flex h-full w-14 flex-col border-r border-border bg-panel"
  aria-label="Navegación principal"
>
  <div class="flex h-14 items-center justify-center border-b border-border">
    <span
      class="font-display text-sm font-semibold text-current"
      title={tenant.slug ?? ""}
    >
      {(tenant.slug ?? "–").slice(0, 2).toUpperCase()}
    </span>
  </div>

  <div class="flex flex-1 flex-col items-center gap-1 py-3">
    <div
      class="flex h-10 w-10 items-center justify-center rounded-lg text-subtext"
      title="Módulos futuros"
    >
      <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
        <rect x="1" y="1" width="6" height="6" rx="1" fill="currentColor" opacity="0.3"/>
        <rect x="9" y="1" width="6" height="6" rx="1" fill="currentColor" opacity="0.3"/>
        <rect x="1" y="9" width="6" height="6" rx="1" fill="currentColor" opacity="0.3"/>
        <rect x="9" y="9" width="6" height="6" rx="1" fill="currentColor" opacity="0.3"/>
      </svg>
    </div>
  </div>
</nav>
