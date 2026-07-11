import type { PageLoad } from "./$types";
import { getKPIs, getTopByCost, getSuccessRate, getTimeline } from "@common/apis/services";
import { daterange } from "@common/stores/daterange.svelte";

export const load: PageLoad = async () => {
  const params = { from_date: daterange.from, to_date: daterange.to };

  const [kpis, topCost, successRate, timeline] = await Promise.all([
    getKPIs(params),
    getTopByCost({ limit: 10 }),
    getSuccessRate(),
    getTimeline(params),
  ]);

  return { kpis, topCost, successRate, timeline };
};
