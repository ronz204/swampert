<script lang="ts">
  interface Props {
    label:    string;
    onremove: () => void;
  }

  let { label, onremove }: Props = $props();
</script>

<span
  class="inline-flex items-center gap-1.5 rounded-full border border-border
    bg-panel px-3 py-1 text-xs text-ink"
>
  {label}
  <button
    type="button"
    class="flex h-4 w-4 items-center justify-center rounded-full
      text-subtext hover:text-alarm focus:outline-none
      focus-visible:ring-2 focus-visible:ring-current"
    aria-label="Quitar filtro {label}"
    onclick={onremove}
  >
    ×
  </button>
</span>
