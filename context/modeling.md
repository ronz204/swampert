# Swampert — Modelado de dominio

> Nota de alcance: este documento describe el **núcleo del sistema** — las entidades, sus reglas y cómo se relacionan entre sí — usando ideas de Domain-Driven Design (DDD). No es un documento de arquitectura ni de persistencia: acá no vas a encontrar tablas SQL, tipos de columna ni decisiones de framework (eso vive en `database.md` y en los documentos de arquitectura). La pregunta que responde este documento es: **¿cuáles son los conceptos del negocio y cómo se comportan entre sí?**
>
> Convención: la prosa está en español, pero toda entidad, agregado, objeto de valor o concepto que eventualmente se traduzca en código va nombrado en inglés, tal cual va a aparecer en el proyecto.

## El lenguaje ubicuo (ubiquitous language)

Antes de modelar nada, hay que ponerse de acuerdo en el vocabulario. Estos son los términos que todos (humanos y copiloto) deberían usar siempre con el mismo significado dentro de Swampert:

| Término (código) | Significado |
|---|---|
| **Company** | El cliente que usa Swampert. Es el "inquilino" (tenant) del sistema; todo lo demás pertenece a una company. |
| **User** | Una persona humana que trabaja en una company y opera Swampert (configura agentes, revisa el dashboard, etc.). |
| **Agent** | Una unidad individual de IA con un rol y unas herramientas asignadas. Es la "pieza" que puede formar parte de un swarm. |
| **Swarm** | Un grupo de agents que colaboran para resolver tasks. |
| **Task** | El trabajo concreto que se le encarga a un swarm resolver. |
| **Execution** | Un intento de resolver una task. Una task puede tener varias executions (por ejemplo, si la primera falla y se reintenta). |
| **ExecutionStep** | Una acción o decisión puntual que un agent tomó dentro de una execution. Es la unidad más chica de trazabilidad. |
| **TokenCost** | El gasto (en tokens, y por lo tanto en dinero) que insumió una execution. |
| **ExecutionError** | Un fallo puntual ocurrido durante una execution o un step. |
| **AuditLog** | Un registro de una acción realizada por un usuario humano sobre la configuración del sistema. |

Si en algún momento del proyecto (código, documentación, conversación con el copiloto) alguien usa una palabra distinta para referirse a lo mismo, es una señal de alerta: hay que volver a este glosario y unificar.

## Los agregados (aggregates) del sistema

En DDD, un **agregado** es un grupo de objetos que se tratan como una unidad a la hora de garantizar que las reglas del negocio se cumplan. Cada agregado tiene una **raíz** (aggregate root): el único punto de entrada permitido para modificar cualquier cosa dentro del agregado.

Swampert tiene cinco agregados principales:

### 1. Company (raíz: `Company`)

Es el agregado de más alto nivel: representa al cliente. Es dueño, indirectamente, de todo lo demás en el sistema — ningún otro agregado puede existir sin estar asociado a una `Company`.

**Invariante clave**: ninguna entidad de ningún otro agregado puede "cruzarse" entre companies. Un `Agent`, un `Swarm`, una `Task`, todo pertenece a exactamente una `Company`, y esa pertenencia nunca cambia.

### 2. Swarm (raíz: `Swarm`)

Un `Swarm` agrupa a los agents que lo componen. El swarm en sí es la raíz; los `Agent` son entidades que pueden pertenecer a uno o más swarms, pero la *composición* de un swarm (qué agents lo integran en un momento dado) es una decisión que se gestiona a través del swarm, no directamente sobre el agent.

**Invariante clave**: un `Swarm` debe tener al menos un `Agent` para poder recibir tasks. Un swarm sin agents está en un estado "incompleto" y no puede pasar a ejecutar nada.

### 3. Task (raíz: `Task`)

Una `Task` representa el encargo que se le hace a un swarm. Es un agregado relativamente simple, pero es el punto de partida de todo el resto del flujo: sin una task, no puede existir una execution.

**Invariante clave**: una `Task` siempre pertenece a un único `Swarm` (el que fue designado para resolverla), y ese swarm debe pertenecer a la misma `Company` que la task.

### 4. Execution (raíz: `Execution`)

Este es el agregado más rico del sistema. Una `Execution` representa un intento concreto de resolver una task, y "dentro" de ella viven:

- Los **ExecutionStep** (la secuencia de acciones que tomaron los agents).
- El **TokenCost** asociado a ese intento.
- Los **ExecutionError** que hayan ocurrido durante ese intento.

Todos estos elementos solo tienen sentido *en el contexto de* una execution particular — no existen por sí solos. Por eso viven dentro del mismo agregado que la execution, y solo se modifican a través de ella (por ejemplo, "agregar un step a esta execution", nunca "crear un step suelto").

**Invariantes clave**:
- Una `Execution` tiene un `status` (`pending`, `running`, `completed`, `failed`) y solo puede transicionar en un orden válido — no puede pasar de `completed` a `running`, por ejemplo.
- No pueden agregarse nuevos steps, costs o errors a una execution que ya se cerró (`completed` o `failed`).
- El costo total de una execution es la suma de los costos de sus steps individuales — nunca un número inventado aparte.

### 5. AuditLog (raíz: `AuditLog`)

A diferencia de los demás, este agregado no representa "algo que existe y cambia", sino un **hecho que ya ocurrió** — un registro de que un `User` hizo una acción determinada (crear un agent, editar un swarm, etc.). Una vez creado, un `AuditLog` **nunca se modifica ni se borra**: es información histórica, no un estado a gestionar.

Esto lo distingue claramente de los demás agregados: no tiene invariantes de transición de estado, solo la garantía de que, una vez escrito, es inmutable.

## Objetos de valor (value objects)

Además de los agregados, hay conceptos que no tienen identidad propia — no importa "cuál" es, sino **qué valor** representan. Estos son los principales en Swampert:

- **ExecutionStatus**: uno de un conjunto fijo de valores (`pending`, `running`, `completed`, `failed`). No tiene sentido preguntarse "cuál status es este" más allá de su propio valor.
- **TokenCost**: la combinación de `inputTokens`, `outputTokens` y `estimatedCost`. Tiene sentido como un paquete, no como números sueltos.
- **AgentConfig**: el conjunto de parámetros (modelo base, herramientas disponibles, instrucciones) que definen cómo se comporta un `Agent`. Dos agents con exactamente la misma configuración no son "el mismo objeto de configuración" en el sentido de identidad, pero sí representan el mismo valor.

## Cómo fluye una historia típica por el sistema

Para que todo esto no quede abstracto, así es como se recorren los agregados en un caso de uso típico:

1. Una `Company` tiene configurado un `Swarm` con varios `Agent`.
2. Un `User` de esa company crea una `Task` y se la asigna a ese swarm.
3. El swarm "resuelve" la task generando una `Execution`.
4. Durante la execution, se van registrando `ExecutionStep` — cada uno hecho por uno de los agents del swarm.
5. Cada step acumula su `TokenCost`, y si algo sale mal, se registra un `ExecutionError` asociado a ese step o a la execution completa.
6. La execution eventualmente se cierra (`completed` o `failed`), y a partir de ahí ya no se le puede agregar nada más.
7. En paralelo, si algún `User` modificó algo de la configuración (por ejemplo, agregó un agent al swarm), eso queda registrado como un `AuditLog`, de forma permanente e independiente del ciclo de vida de la execution.

## Por qué modelarlo así (y no de otra forma)

La razón de fondo para separar estos agregados es que cada uno protege un conjunto distinto de reglas, y cambian a ritmos distintos:

- `Company` cambia muy poco (alta/baja de una company cliente, cambios de plan).
- `Swarm` cambia con frecuencia moderada (se agregan o quitan agents, se ajusta su configuración).
- `Task` y `Execution` son el corazón operativo: se crean y cierran constantemente, y es donde vive la mayor parte de la actividad del sistema.
- `AuditLog` es un flujo de solo escritura, que crece indefinidamente y nunca se toca una vez creado.

Separar el modelo de esta forma permite razonar sobre cada parte del sistema de forma aislada: podés entender completamente cómo funciona una `Execution` sin necesidad de saber los detalles de cómo se gestiona una `Company`, y viceversa. Esa independencia conceptual es, en el fondo, el objetivo central de modelar el dominio con DDD.