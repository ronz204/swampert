import type { PageLoad } from "./$types";
import {
  getTopByCost,
  getSuccessRate,
  getActivity,
  getTimeline,
  getTopByErrors,
} from "@common/apis/services";
import { daterange, DATERANGE_DEP } from "@common/stores/daterange.svelte";

export const load: PageLoad = async ({ depends }) => {
  depends(DATERANGE_DEP);

  const dateParams = { from_date: daterange.from, to_date: daterange.to };

  const [topCost, successRate, agentActivity, timeline, topErrors] = await Promise.all([
    getTopByCost({ limit: 50, ...dateParams }),
    getSuccessRate(),
    getActivity(),
    getTimeline(dateParams),
    getTopByErrors({ limit: 50 }),
  ]);

  return { topCost, successRate, agentActivity, timeline, topErrors };
};
