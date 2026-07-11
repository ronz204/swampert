<script lang="ts">
  import type { ExecutionStatus, ErrorSeverity } from "@models/entities";

  type Status = ExecutionStatus | ErrorSeverity;

  let { status }: { status: Status } = $props();

  const map: Record<Status, { cls: string; shape: string }> = {
    pending:   { cls: "text-subtext",  shape: "○" },
    running:   { cls: "text-current",  shape: "○" },
    completed: { cls: "text-success",  shape: "●" },
    failed:    { cls: "text-alarm",    shape: "▲" },
    low:       { cls: "text-success",  shape: "●" },
    medium:    { cls: "text-caution",  shape: "○" },
    high:      { cls: "text-caution",  shape: "▲" },
    critical:  { cls: "text-alarm",    shape: "▲" },
  };

  const { cls, shape } = $derived(map[status] ?? { cls: "text-subtext", shape: "○" });
</script>

<span class="inline-flex items-center gap-1 font-mono text-xs {cls}">
  <span aria-hidden="true">{shape}</span>
  {status}
</span>
