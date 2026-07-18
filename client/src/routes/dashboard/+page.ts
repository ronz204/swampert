import type { PageLoad } from "./$types";
import { getKPIs, getCostBySwarm, getTimeline } from "@common/apis/services";
import { daterange, DATERANGE_DEP } from "@common/stores/daterange.svelte";

export const load: PageLoad = async ({ depends }) => {
  depends(DATERANGE_DEP);

  const params = { from_date: daterange.from, to_date: daterange.to };

  const [kpis, costBySwarm, timeline] = await Promise.all([
    getKPIs(params),
    getCostBySwarm(params),
    getTimeline(params),
  ]);

  return { kpis, costBySwarm, timeline };
};
