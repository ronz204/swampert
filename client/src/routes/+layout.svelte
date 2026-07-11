<script lang="ts">
  import "../app.css";
  import favicon      from "@common/assets/favicon.svg";
  import NavRail      from "@shared/layouts/NavRail.svelte";
  import TopBar       from "@shared/layouts/TopBar.svelte";

  let { children } = $props();
</script>

<svelte:head>
  <link rel="icon" href={favicon} />
</svelte:head>

<NavRail />
<TopBar />

<main class="ml-14 mt-14 min-h-[calc(100vh-3.5rem)] p-6">
  {@render children()}
</main>
