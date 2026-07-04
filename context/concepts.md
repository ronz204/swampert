# Swampert — Conceptos para entender

Este documento reúne las ideas y la teoría que hacen falta para entender **por qué Swampert está modelado como está**. No es un manual de arquitectura ni de implementación — es la caja de herramientas conceptual que te permite leer el resto del proyecto y decir "ah, esto tiene sentido porque..." en vez de memorizar decisiones sueltas.

## 1. Multi-tenancy (multi-inquilino)

Un sistema **multi-tenant** es aquel en el que varios clientes (en este caso, empresas) comparten la misma plataforma e infraestructura, pero cada uno ve únicamente sus propios datos, como si tuviera el sistema solo para sí. Es el modelo detrás de la mayoría del software B2B moderno (Slack, Notion, Salesforce, etc.).

En Swampert, la empresa es el "inquilino": todo lo que existe en el sistema (enjambres, agentes, tareas, ejecuciones) pertenece a una empresa específica, y ninguna empresa debería poder ver ni tocar los datos de otra.

## 2. Row-Level Security (seguridad a nivel de fila)

Row-Level Security (RLS) es una capacidad de las bases de datos relacionales (como PostgreSQL) que permite definir reglas de acceso **a nivel de cada fila individual de una tabla**, en lugar de a nivel de tabla completa. En otras palabras: en vez de decir "el usuario puede leer la tabla `ejecuciones`", RLS permite decir "el usuario puede leer únicamente las filas de `ejecuciones` que pertenecen a su propia empresa".

Este concepto es clave en Swampert porque es el mecanismo natural para implementar el aislamiento multi-tenant: en vez de confiar en que cada consulta filtre "a mano" por empresa (lo cual es propenso a errores humanos), la propia base de datos se encarga de que sea imposible ver datos de otra empresa, incluso si alguien se olvida de poner el filtro correspondiente.

## 3. Tipos de datos avanzados y para qué se usan

Swampert usa varios tipos de datos que van más allá de los clásicos "texto, número, fecha", porque el dominio los pide de forma natural:

- **JSONB**: un formato que permite guardar datos semi-estructurados (como el razonamiento interno de un agente, que no siempre tiene la misma forma) sin perder la capacidad de consultarlos eficientemente.
- **ARRAY**: permite guardar listas de valores en una sola columna, útil por ejemplo para representar qué herramientas tiene disponibles un agente.
- **ENUM**: un tipo que restringe un campo a un conjunto fijo de valores posibles (por ejemplo, el estado de una ejecución: `pendiente`, `en_progreso`, `completada`, `fallida`). Esto evita que se cuelen valores inválidos o mal escritos.
- **UUID**: identificadores únicos universales, muy usados en sistemas donde varias partes pueden crear registros de forma independiente y concurrente, sin necesidad de coordinarse para no repetir un identificador.

La idea central es que cada tipo avanzado responde a una necesidad real del dominio, no se usa "porque queda bien" — y eso es justamente lo que hace que el modelo de datos sea honesto y fácil de justificar.

## 4. Normalización (1FN, 2FN, 3FN)

La normalización es un proceso para organizar los datos de una base de datos relacional de forma que se eviten redundancias y inconsistencias. Se suele explicar en "formas normales" progresivas:

- **1FN (Primera Forma Normal)**: cada columna debe contener un solo valor atómico (no listas, no datos repetidos dentro de una misma celda).
- **2FN (Segunda Forma Normal)**: además de cumplir 1FN, todos los atributos no clave deben depender de la clave completa (relevante en tablas con claves compuestas).
- **3FN (Tercera Forma Normal)**: además de cumplir 2FN, ningún atributo no clave debe depender de otro atributo no clave (es decir, se eliminan las dependencias "transitivas").

Un matiz importante para Swampert: los campos de tipo JSONB o ARRAY pueden parecer, a primera vista, una violación de la 1FN (porque "empaquetan" varios valores en una sola columna). Sin embargo, esto es una **decisión de diseño deliberada**, común en bases de datos modernas como PostgreSQL, y no un descuido: se usa cuando el dato es naturalmente semi-estructurado (como el razonamiento de un agente) y forzarlo a tablas separadas agregaría complejidad sin beneficio real.

## 5. Particionamiento

El particionamiento es una técnica que consiste en dividir una tabla muy grande en partes más pequeñas ("particiones"), manteniendo de cara al usuario la ilusión de que sigue siendo una sola tabla. Una forma común es el **particionamiento por rango de fecha**: por ejemplo, una partición por cada mes de datos.

Esto es útil en Swampert porque las tablas de ejecuciones y logs de auditoría crecen constantemente con el tiempo, y la mayoría de las consultas solo necesitan ver un rango de fechas reciente. Particionar por fecha permite que esas consultas sean mucho más rápidas, porque la base de datos puede "descartar" de entrada las particiones que no corresponden al rango pedido (esto se conoce como *partition pruning*).

## 6. Índices y planes de ejecución

Un **índice** es una estructura auxiliar que la base de datos mantiene para poder encontrar filas rápidamente sin tener que revisar la tabla entera. Es parecido al índice de un libro: en vez de leer todas las páginas para encontrar un tema, vas directo a la página indicada.

Un **plan de ejecución** es la estrategia que la base de datos elige para resolver una consulta (por ejemplo, si usa un índice o si recorre toda la tabla). Analizar el plan de ejecución de una consulta permite entender si esa consulta es eficiente o si se puede mejorar agregando un índice adecuado.

En Swampert, estos conceptos son centrales para las consultas del dashboard: filtrar ejecuciones por empresa, por fecha o por estado son operaciones frecuentes, y los índices bien elegidos son lo que hace que esas consultas respondan rápido incluso con grandes volúmenes de datos.

## 7. Auditoría y trazabilidad

**Auditoría** significa dejar un registro confiable de quién hizo qué y cuándo, de forma que después se pueda reconstruir la historia de lo ocurrido. **Trazabilidad** es la capacidad de seguir el "hilo" completo de un proceso, paso a paso, desde el principio hasta el final.

Swampert aplica estos dos conceptos en dos niveles distintos:
- **Trazabilidad de agentes**: poder reconstruir, paso a paso, qué hizo un agente dentro de una ejecución.
- **Auditoría de usuarios**: poder reconstruir qué cambios hizo un humano sobre la configuración del sistema (crear un agente, editar un enjambre, etc.).

## Cómo se conectan estos conceptos entre sí

Ninguno de estos conceptos vive aislado — se apoyan unos en otros para lograr el objetivo del proyecto (ver `problems.md`):

- La **multi-tenancy** define el problema de aislamiento, y **RLS** es la herramienta que lo resuelve a nivel de base de datos.
- Los **tipos de datos avanzados** permiten modelar fielmente el dominio de los agentes, sin forzar todo a texto plano.
- La **normalización** asegura que el modelo de datos sea consistente y no tenga redundancias innecesarias, sabiendo distinguir cuándo una "excepción" (como JSONB) es en realidad una decisión de diseño válida.
- El **particionamiento** y los **índices** son lo que hace que, a medida que el sistema acumula historial, siga siendo rápido de consultar.
- La **auditoría y trazabilidad** son, en el fondo, la razón de ser de todo el proyecto: sin ellas, Swampert no cumpliría su propósito.

Con estos conceptos claros, el resto del proyecto (cómo está modelado, cómo se implementa, cómo se consulta) debería leerse con mucha más naturalidad.