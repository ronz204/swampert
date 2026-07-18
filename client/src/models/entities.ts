export type ExecutionStatus = "pending" | "running" | "completed" | "failed";
export type ErrorSeverity   = "low" | "medium" | "high" | "critical";

export interface DashboardKPIs {
  executions_count: number;
  total_cost:       number;
  error_rate:       number | null;
  active_agents:    number;
}

export interface TopByCostRow {
  tarea:        string;
  execution_id: string;
  status:       ExecutionStatus;
  started_at:   string;
  total_tokens: number;
  costo_total:  number;
}

export interface ExecutionsByMonthRow {
  mes:         string;
  swarm:       string;
  completadas: number;
  fallidas:    number;
  en_curso:    number;
  total:       number;
}

export interface SwarmSuccessRateRow {
  swarm_id:     string;
  swarm:        string;
  total_tareas: number;
  completadas:  number;
  fallidas:     number;
  tasa_exito:   number | null;
}

export interface SwarmCostRow {
  swarm_id:    string;
  swarm:       string;
  costo_total: number;
}

export interface AgentActivityRow {
  agent_id:         string;
  agente:           string;
  role:             string;
  total_steps:      number;
  tokens_promedio:  number | null;
  ultima_actividad: string | null;
}

export interface TopByErrorsRow {
  tarea:                 string;
  severity:              ErrorSeverity;
  error_type:            string;
  total_errores:         number;
  execuciones_afectadas: number;
}
