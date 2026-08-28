# Sistema de zombies - Play Sector X

Documento vivo para construir una IA de zombies estilo Project Zomboid,
compatible con singleplayer y multiplayer.

Convencion de seguimiento:

- `[ ]` pendiente.
- `[~]` en progreso o parcialmente implementado.
- `[x]` completado y verificado.

> Estado actual: la primera vertical slice ya tiene `ZombieAi` en Rust,
> poblacion por sectores, materializacion limitada, percepcion, ruido,
> persecucion, ataque, persistencia basica y snapshots de red. Quedan
> pendientes navegacion, director de hordas avanzado y pruebas multiplayer
> con dos procesos reales.

## Prioridad actual

La prioridad es construir primero un `ZombiePopulationManager` en Rust. El
mundo no debe depender de cientos de nodos Godot activos para representar toda
la poblacion: los sectores lejanos se guardaran y simularan como datos, y solo
los sectores cercanos a los jugadores materializaran zombies individuales.

La implementacion mantiene el `DogSpawner` de prueba y agrega un gestor de
zombies que inicializa sectores de forma determinista. Los sectores lejanos
permanecen en Rust; solo los sectores cercanos crean nodos y respetan un
presupuesto visual fijo.

### Primer corte implementado

`rust_core/src/zombie_population.rs` ya contiene la clase `ZombiePopulation`.
Mantiene un registro en memoria por coordenadas de sector y expone a Godot:

- configuracion de tamano de sector y semilla del mundo;
- conversion determinista de posiciones del mundo a coordenadas de sector;
- establecer, agregar, retirar y consultar poblacion;
- conteo total y cantidad de sectores;
- semilla determinista por sector;
- snapshot compacto de un sector, revision global y estado agregado de horda;
- direccion de migracion y memoria de ruido con decaimiento;
- limpieza del registro.

Las pruebas `tests/zombie_population_verify.gd`,
`tests/zombie_population_manager_verify.tscn` y
`tests/zombie_attack_verify.tscn` validan el contrato desde Godot headless.
El gestor conserva mas de 600 zombies agregados en la prueba y materializa
solo el presupuesto configurado.

## Indice de tareas

### Fase 0 - Contrato y arquitectura

- [x] Confirmar que el zombie usa `CharacterBody3D`.
- [x] Confirmar que el modelo tiene animaciones de locomocion, ataque y muerte.
- [x] Confirmar que existe `take_damage()` y vida basica.
- [x] Sincronizar la clase `ZombieAi` del DLL con el codigo fuente Rust.
- [x] Definir Rust como dueño del estado y decisiones de la IA.
- [x] Definir GDScript como puente de percepcion, fisica, animacion y escena.
- [~] Definir al servidor como autoridad de zombies en multiplayer.
- [x] Evitar un nodo Godot y una llamada de red por cada zombie lejano.

### Fase 1 - Poblacion por sectores (prioridad actual)

- [x] Crear el registro Rust de poblacion por sectores sin nodos Godot por
      zombie lejano.
- [x] Definir tamano, coordenadas y clave estable de cada sector.
- [x] Guardar cantidad de zombies y estado agregado de cada sector.
- [x] Usar una semilla estable para reconstruir poblacion de forma determinista.
- [x] Exponer crear, consultar, agregar y retirar poblacion desde GDScript.
- [x] Exponer snapshots compactos de sectores para pruebas y multiplayer.
- [x] Crear prueba Rust/headless del registro y sus limites.
- [x] Conectar el registro con el mundo sin eliminar aun el spawner existente.
- [x] Activar zombies individuales al entrar un jugador en un sector.
- [~] Convertir zombies individuales en datos cuando todos los jugadores se
      alejen.
- [x] Mantener un presupuesto de zombies visuales por jugador.
- [~] Simular movimiento y ruido de sectores lejanos de forma agregada.

### Fase 2 - IA base en Rust

- [x] Crear `ZombieAi` en Rust con estados idle, wander, investigate, chase y
      attack.
- [x] Hacer que el estado idle sea el comportamiento predominante cuando no
      hay estimulo.
- [x] Crear pausas largas y direcciones de wander cortas e irregulares.
- [x] Agregar memoria temporal de la ultima posicion conocida del objetivo.
- [x] Agregar memoria temporal de la ultima fuente de ruido.
- [x] Exponer a GDScript una entrada de percepcion por tick o por intervalo.
- [x] Devolver desde Rust velocidad, animacion, estado y evento de ataque.
- [x] Hacer que `force_redirect()` regenere la decision de movimiento.
- [x] Hacer que los cambios de estado tengan cooldown para evitar oscilaciones.

### Fase 3 - Percepcion y objetivos

- [x] Encontrar el jugador valido mas cercano.
- [x] Considerar todos los jugadores conectados en multiplayer.
- [x] Comprobar distancia de audicion.
- [x] Comprobar distancia de vision.
- [x] Comprobar angulo de vision.
- [x] Comprobar linea de vision con raycast.
- [x] Ignorar al propio zombie y sus hijos en el raycast.
- [x] Recordar durante unos segundos la ultima posicion vista.
- [x] Permitir que un zombie investigue un ruido aunque no vea al jugador.
- [x] Perder el objetivo gradualmente, no de golpe.
- [x] Volver a idle despues de investigar sin encontrar nada.
- [x] Recalcular percepcion con menor frecuencia que la fisica visual.

### Fase 4 - Movimiento y agrupacion

- [x] Perseguir la ultima posicion conocida del jugador.
- [x] Evitar que todos los zombies elijan exactamente el mismo punto.
- [x] Agregar separacion local entre zombies.
- [x] Evitar paredes y redirigir cuando quedan bloqueados.
- [ ] Mantener el movimiento compatible con la navegacion actual por terreno.
- [ ] Hacer que el zombie pueda detenerse frente a una obstruccion.
- [x] Crear influencia de horda: zombies cercanos pueden compartir un ruido.
- [~] Crear estados de horda dispersa, horda reunida y horda en movimiento.
- [~] Preparar una simulacion simplificada para zombies lejanos.

### Fase 5 - Ataque y dano

- [x] Definir distancia de ataque.
- [x] Definir cooldown de ataque.
- [x] Hacer que Rust emita un evento de ataque una sola vez por cooldown.
- [x] Reproducir la animacion `attack` desde GDScript.
- [x] Aplicar daño al objetivo correcto al momento del golpe.
- [x] Verificar que el objetivo sigue dentro de alcance antes de hacer daño.
- [x] Evitar que varios frames de una animacion apliquen multiples golpes.
- [x] Hacer que el jugador reciba daño mediante `PlayerStats`.
- [ ] Añadir feedback minimo de dano para jugador y zombie.
- [ ] Definir que ocurre si varios zombies atacan al mismo jugador.
- [~] Replicar ataque, dano y muerte de forma autoritativa en multiplayer.

### Fase 6 - Animaciones y estados visuales

- [x] Reproducir idle, walk y run segun la velocidad actual.
- [x] Reproducir die al llegar la vida a cero.
- [x] Reproducir attack al recibir evento de ataque.
- [x] No reiniciar la misma animacion cada frame.
- [x] Mantener blend suave entre idle, persecucion y ataque.
- [x] Sincronizar la velocidad de animacion con la velocidad real.
- [x] Asegurar que attack y die no entren en loop.
- [x] Detener fisica y decisiones despues de morir.
- [x] Liberar o reciclar zombies muertos de forma segura.

### Fase 7 - Director de hordas y rendimiento

- [x] Dividir el mundo en sectores de simulacion.
- [x] Mantener zombies lejanos como datos, no como nodos completos.
- [x] Activar zombies individuales al acercarse un jugador.
- [~] Convertir zombies individuales en datos al alejarse todos los jugadores.
- [x] Mantener un presupuesto maximo de zombies con fisica completa.
- [ ] Mantener un presupuesto maximo de pathfinding por frame.
- [x] Procesar la percepcion por lotes o en intervalos.
- [x] Compartir eventos de ruido por sector.
- [~] Persistir cantidad y estado de hordas cuando se descarga un chunk.
- [x] Medir rendimiento con 50, 100, 250, 500 y 1000 zombies simulados.

### Fase 8 - Multiplayer

- [~] Hacer que el servidor controle objetivos, estados, ataques y muertes.
- [~] Enviar a cada cliente solo zombies dentro de su area de interes.
- [x] Enviar snapshots agrupados en vez de un RPC por decision interna.
- [x] Interpolar posiciones y rotaciones en el cliente.
- [x] Evitar que el cliente pueda decidir dano o muerte.
- [~] Sincronizar sonidos y eventos importantes de horda.
- [ ] Probar dos jugadores en sectores distintos.
- [ ] Probar dos jugadores atrayendo la misma horda.
- [ ] Probar reconexion y descarga de un sector.
- [x] Verificar que singleplayer use el mismo camino autoritativo local.

### Fase 9 - Pruebas y seguridad de regresion

- [x] Crear prueba Rust para transiciones de estado sin objetivo.
- [x] Crear prueba Rust para persecucion y perdida de objetivo.
- [x] Crear prueba Rust para cooldown de ataque.
- [x] Crear prueba headless para animacion de ataque.
- [x] Crear prueba headless de dano al jugador.
- [x] Crear prueba end-to-end usando el raycast real contra el collider.
- [~] Crear prueba de varios zombies atacando sin duplicar golpes por frame.
- [ ] Crear prueba de muerte y liberacion del zombie.
- [x] Crear prueba de carga con muchos zombies.
- [x] Ejecutar `cargo build` y pruebas headless despues de cada cambio Rust.
- [x] Revisar que no reaparezca el error de `Dictionary` contra `Vector3`.

## Estado base confirmado

Estas capacidades ya existen antes de esta fase:

- La escena principal del zombie es `world/mobs/zombie.tscn`.
- El zombie usa `CharacterBody3D` y aplica gravedad con GDScript.
- `ZombieModelUtils` carga y normaliza el modelo.
- Las animaciones fusionadas incluyen `idle`, `walk`, `run`, `attack` y `die`.
- `Zombie.gd` tiene `_health`, `take_damage()` y `die()`.
- `Zombie.gd` tiene `play_attack()`, pero nadie lo llama automaticamente.
- El movimiento actual consume un diccionario con `velocity` y `anim`.
- El zombie redirige cuando `is_on_wall()`.
- El spawner y el mundo ya pueden instanciar entidades con autoridad local.

## Arquitectura elegida

### Rust decide

Rust sera el dueño de los datos y las decisiones de cada zombie activo:

- estado actual;
- temporizadores;
- velocidad deseada;
- objetivo percibido;
- ultima posicion conocida;
- memoria de ruido;
- cooldown de ataque;
- transiciones de idle, wander, investigate, chase y attack.

No se creara una escena Godot por cada zombie lejano. La simulacion masiva
trabajara con datos compactos y solo los zombies cercanos tendran representacion
visual y fisica completa.

### GDScript conecta

GDScript seguira siendo responsable de las operaciones que pertenecen al arbol
de Godot:

- buscar jugadores y objetivos;
- hacer raycasts de vision;
- pasar percepcion a Rust;
- mover el `CharacterBody3D`;
- reproducir animaciones;
- consultar colisiones;
- aplicar dano a `PlayerStats`;
- crear, activar, desactivar o reciclar representaciones visuales.

Esto evita que Rust tenga que manipular directamente el arbol de escenas por
cada zombie y mantiene la integracion con Godot simple.

### Singleplayer y multiplayer

En singleplayer, el mismo sistema autoritativo corre localmente.

En multiplayer, el servidor ejecuta la IA y decide:

- a quien persigue cada zombie;
- cuando ataca;
- cuanto dano causa;
- cuando muere;
- que horda cambia de sector.

Los clientes reciben solo snapshots de los zombies relevantes para ellos. La
logica interna de la IA no se replica frame por frame.

## Primer comportamiento objetivo

El primer corte funcional debe producir este ciclo:

1. Zombie sin objetivo: permanece idle la mayor parte del tiempo.
2. Zombie sin objetivo durante demasiado tiempo: hace un wander corto.
3. Zombie ve al jugador: pasa a chase.
4. Zombie pierde la vision: va a la ultima posicion conocida.
5. Zombie llega a esa posicion y no encuentra nada: investiga un momento.
6. Zombie sigue sin estimulo: vuelve a idle.
7. Zombie entra en distancia de ataque: se detiene, reproduce attack y causa
   un solo golpe.
8. Zombie recibe suficiente dano: reproduce die y deja de actuar.

La primera version no necesita pathfinding perfecto ni hordas lejanas
completamente simuladas. Ya tiene agrupacion por ruido y escalabilidad de la IA;
lo siguiente es enriquecer la migracion agregada y validar dos peers reales.

## Reglas de comportamiento recomendadas

- Idle debe ser el estado mas comun cuando no hay estimulos.
- Wander debe durar poco y tener pausas largas entre intentos.
- Ver al jugador debe tener mas prioridad que cualquier wander.
- Oir un ruido debe generar investigacion, no conocimiento perfecto del jugador.
- La ultima posicion conocida debe caducar.
- El zombie debe tener un pequeno margen de memoria para no parecer estupido,
  pero no rastrear al jugador infinitamente.
- Ataques y dano deben tener cooldowns separados.
- El objetivo debe validarse en GDScript antes de aplicar dano.
- El estado debe poder reproducirse en una prueba con una semilla fija.
- Ningun zombie debe ejecutar una llamada de red por cada frame interno.

## Fuera del primer corte

- Pathfinding avanzado alrededor de toda la ciudad.
- Trepar ventanas o romper puertas.
- Diferentes tipos de zombies.
- Animaciones contextuales complejas.
- Hordas persistentes globales en miles de sectores.
- Simulacion completa de zombies desconectados del jugador.
- Servidor dedicado separado.

Estas funciones se pueden agregar despues de que el ciclo idle-persecucion-
ataque-muerte sea estable.

## Registro de decisiones

| Fecha | Decision | Estado |
|---|---|---|
| 2026-08-20 | IA de alto volumen en Rust y puente visual en GDScript | Implementado |
| 2026-08-20 | Poblacion por sectores antes de IA visual y spawner masivo | Implementado, falta simulacion avanzada |
| 2026-08-20 | Idle predominante sin objetivo | Implementado y probado con semilla fija |
| 2026-08-20 | Percepcion mediante distancia, angulo y linea de vision | Implementado |
| 2026-08-20 | Memoria temporal de ultima posicion y ruido | Implementado |
| 2026-08-20 | Servidor autoritativo para multiplayer | Parcial, falta prueba con dos peers |
| 2026-08-20 | Primer corte sin pathfinding global avanzado | Implementado |
