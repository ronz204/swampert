-- 0016-clustering.sql
--
-- Propósito: reorganizar físicamente las tablas de mayor volumen usando CLUSTER,
-- de modo que las filas relacionadas queden contiguas en disco y los index scans
-- accedan a menos páginas de heap.
--
-- Tablas elegidas y justificación:
--
--   1. core.tasks → índice (tenant_id, status)
--      La consulta central del dashboard filtra siempre por tenant y estado.
--      Clustering agrupa físicamente las tareas de cada tenant, reduciendo I/O
--      en los filtros de estado que alimentan los KPI.
--
--   2. tracer.execution_steps → índice (execution_id, step_number)
--      Tabla de mayor volumen del sistema. La reconstrucción de una traza de
--      ejecución lee todos los steps en orden: con clustering, son un bloque
--      contiguo en disco en lugar de heap fetches dispersos.
--
--   3. tracer.token_costs → índice (execution_id)
--      Las agregaciones de costo (SUM por ejecución) acceden a múltiples filas
--      del mismo execution_id. Clustering convierte esa operación en I/O
--      secuencial sobre un bloque compacto.
--
-- Nota: CLUSTER adquiere ACCESS EXCLUSIVE sobre la tabla durante la operación.
-- En producción debe ejecutarse en una ventana de mantenimiento.
-- Para verificar los nombres de índice generados: SELECT indexname FROM pg_indexes WHERE tablename = '<tabla>';

CLUSTER core.tasks USING tasks_tenant_id_status_idx;
ANALYZE core.tasks;

CLUSTER tracer.execution_steps USING execution_steps_execution_id_step_number_idx;
ANALYZE tracer.execution_steps;

CLUSTER tracer.token_costs USING token_costs_execution_id_idx;
ANALYZE tracer.token_costs;
