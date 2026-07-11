import { instance } from "@common/apis/axios";
import type {
  DashboardKPIs,
  TopByCostRow,
  ExecutionsByMonthRow,
  ExecutionStatus,
  SwarmSuccessRateRow,
  AgentActivityRow,
  TopByErrorsRow,
  ErrorSeverity,
} from "@models/entities";

// ---- Dashboard ---------------------------------------------------------------

export interface KPIsParams {
  from_date?: string;
  to_date?:   string;
}

export async function getKPIs(params?: KPIsParams): Promise<DashboardKPIs> {
  const { data } = await instance.get<DashboardKPIs>("/dashboard/kpis", { params });
  return data;
}

// ---- Executions --------------------------------------------------------------

export interface TopByCostParams {
  limit?:  number;
  status?: ExecutionStatus;
}

export interface TimelineParams {
  swarm?:     string;
  status?:    ExecutionStatus;
  from_date?: string;
  to_date?:   string;
}

export async function getTopByCost(params?: TopByCostParams): Promise<TopByCostRow[]> {
  const { data } = await instance.get<TopByCostRow[]>("/executions/cost", { params });
  return data;
}

export async function getTimeline(params?: TimelineParams): Promise<ExecutionsByMonthRow[]> {
  const { data } = await instance.get<ExecutionsByMonthRow[]>("/executions/timeline", { params });
  return data;
}

// ---- Swarms ------------------------------------------------------------------

export interface SuccessRateParams {
  name?: string;
}

export async function getSuccessRate(params?: SuccessRateParams): Promise<SwarmSuccessRateRow[]> {
  const { data } = await instance.get<SwarmSuccessRateRow[]>("/swarms/success-rate", { params });
  return data;
}

// ---- Agents ------------------------------------------------------------------

export interface ActivityParams {
  role?: string;
}

export async function getActivity(params?: ActivityParams): Promise<AgentActivityRow[]> {
  const { data } = await instance.get<AgentActivityRow[]>("/agents/activity", { params });
  return data;
}

// ---- Failures ----------------------------------------------------------------

export interface TopByErrorsParams {
  severity?:   ErrorSeverity[];
  error_type?: string;
  task?:       string;
  limit?:      number;
}

export async function getTopByErrors(params?: TopByErrorsParams): Promise<TopByErrorsRow[]> {
  const { data } = await instance.get<TopByErrorsRow[]>("/errors/top", { params });
  return data;
}
