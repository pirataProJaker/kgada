# Creador de mapas - Play Sector X

Documento vivo de diseño y seguimiento para el creador de mapas de Play Sector X.

La meta es construir un editor de mapas inspirado en la experiencia de Red Alert 1:
una vista superior clara, una paleta de elementos, colocacion rapida sobre una
rejilla, herramientas sencillas de terreno y la posibilidad de probar el mapa
inmediatamente dentro del juego.

Este archivo usa casillas Markdown para seguir el progreso:

- `[ ]` tarea pendiente.
- `[x]` tarea completada y verificada.
- `[~]` tarea en progreso o parcialmente resuelta.

> Estado actual: el editor ya usa el `ChunkManager` real del juego. Permite
> mapas de 80, 160, 240 y 320 m, compuestos por chunks reales de 40 m; el
> mismo generador Rust de Marching Cubes construye la malla, el material PSX
> y la colision. `Probar mapa` ya carga el heightfield en `WorldTest`; la
> colocacion de objetos sigue pendiente.

## Indice de trabajo

### Fase 0 - Decisiones y limites

- [ ] Confirmar si la primera version usara terreno de superficie editable o
      esculpido volumetrico completo.
- [ ] Confirmar el tamano inicial del mapa: pequeno, mediano o grande.
- [ ] Confirmar si la primera version sera solo para un jugador.
- [ ] Confirmar que el formato principal de modelos importados sera GLB/glTF.
- [ ] Definir si el mapa se guardara solo localmente o tambien se compartira
      con otros jugadores.
- [ ] Definir las categorias iniciales de objetos de la paleta.
- [ ] Escribir las reglas de rendimiento: cantidad maxima de objetos, tamano
      maximo de texturas y complejidad maxima de modelos.

### Fase 1 - Base del editor

- [x] Crear una escena propia para el editor de mapas.
- [x] Crear el modo de entrada al editor desde el menu principal.
- [x] Implementar camara 3D superior en perspectiva.
- [x] Mostrar el terreno real en 3D con perspectiva orbital.
- [x] Mostrar una rejilla ligera de muestras sobre la superficie real.
- [x] Navegar lateralmente con las flechas del teclado.
- [x] Orbitar la vista con el boton derecho del mouse.
- [x] Implementar desplazamiento del mapa con el boton central del mouse.
- [x] Implementar zoom con la rueda del mouse.
- [x] Permitir mapas de 80 a 320 m y redimensionarlos conservando alturas.
- [~] Hacer que el zoom se centre en la posicion bajo el cursor.
- [x] Agregar rejilla visual y coordenadas del mapa.
- [x] Mostrar un cursor de edicion sobre la celda o punto seleccionado.
- [~] Crear barra superior con Nuevo, Abrir, Guardar, Deshacer, Rehacer y
      Probar mapa.
- [~] Crear panel de herramientas y categorias.
- [ ] Crear panel de propiedades del elemento seleccionado.
- [ ] Implementar seleccion, borrar, mover, rotar, duplicar y copiar/pegar.
- [ ] Implementar seleccion multiple.

### Fase 2 - Terreno de superficie

- [x] Representar el terreno inicial mediante una cuadricula plana de alturas.
- [x] Mantener el mapa nuevo sin alturas aleatorias ni generacion por semilla.
- [x] Conservar Marching Cubes como generador/renderizador de la superficie.
- [x] Crear herramienta para subir terreno con falloff sobre vecinos.
- [x] Crear herramienta para bajar terreno con falloff sobre vecinos.
- [ ] Crear herramienta para suavizar terreno.
- [x] Crear herramienta para aplanar terreno.
- [ ] Crear herramienta para igualar una zona a una altura elegida.
- [ ] Crear herramienta para crear playas o zonas de transicion.
- [x] Regenerar solo los chunks afectados por una edicion.
- [x] Actualizar la colision del chunk regenerado.
- [ ] Evitar grietas visibles entre chunks editados.
- [ ] Crear previsualizacion de la modificacion antes de aplicarla.
- [x] Implementar radio, fuerza y falloff suave del pincel.
- [ ] Implementar Deshacer/Rehacer para cambios de terreno.

La edicion de mapas grandes usa una cola de chunks sucios. Una pincelada solo
marca el rectangulo de chunks que toca su radio, incluyendo las fronteras
vecinas; el `ChunkManager` reemplaza esas mallas y colisiones sin reconstruir
el resto del mapa. La carga inicial y las regeneraciones se reparten entre
frames, y la rejilla visual usa el mismo particionado para no recorrer el
mapa completo durante cada movimiento del mouse.

### Fase 2.1 - Colocacion inteligente futura

La primera version no intentara resolver conexiones automaticas mientras se
construye la base del editor. Cuando llegue la colocacion de objetos, cada
asset podra declarar puntos de anclaje, categorias de conector y reglas de
orientacion. Una valla, por ejemplo, conservara dos extremos logicos; al
colocarla cerca de otra valla compatible, el editor podra ajustar posicion y
rotacion al anclaje mas cercano, elegir la variante visual correcta y guardar
la conexion como datos del mapa.

- [ ] Definir anclajes y conectores en la definicion de un objeto.
- [ ] Ajustar automaticamente posicion y rotacion al conector compatible.
- [ ] Resolver cadenas de vallas sin exigir que el usuario calcule el angulo.
- [ ] Elegir esquinas, finales y piezas rectas segun vecinos compatibles.
- [ ] Mostrar una previsualizacion valida antes de confirmar la colocacion.
- [ ] Permitir desactivar el ajuste automatico para objetos libres.

### Fase 3 - Capas, alturas y materiales

- [ ] Crear panel de capas de altura.
- [ ] Definir nivel del mar.
- [ ] Definir altura minima de tierra.
- [ ] Definir zona de playa.
- [ ] Definir inicio de pasto.
- [ ] Definir inicio de tierra seca o barro.
- [ ] Definir inicio de roca.
- [ ] Definir inicio de montana.
- [ ] Definir inicio de nieve.
- [ ] Definir altura maxima de vegetacion.
- [ ] Definir pendiente maxima para construir.
- [ ] Permitir editar los valores desde el editor.
- [ ] Permitir asignar textura o color a cada capa.
- [ ] Permitir configurar una zona de mezcla entre capas.
- [ ] Permitir usar la pendiente como criterio adicional a la altura.
- [ ] Permitir usar distancia al agua como criterio opcional.
- [ ] Crear una vista de depuracion de alturas por colores.
- [ ] Crear una vista de depuracion de pendientes.
- [ ] Hacer que el agua reaccione al nivel del mar.
- [ ] Guardar estas reglas dentro del archivo del mapa.

### Fase 4 - Objetos incluidos

- [ ] Crear biblioteca de modelos incluidos por defecto.
- [ ] Organizar la biblioteca por categorias.
- [ ] Agregar terrenos y decoracion.
- [ ] Agregar arboles, arbustos y rocas.
- [ ] Agregar edificios y puertas.
- [ ] Agregar puntos de aparicion.
- [ ] Agregar jugadores, enemigos o animales como entidades configurables.
- [ ] Agregar agua, puentes y elementos especiales.
- [ ] Mostrar miniatura o vista previa de cada modelo.
- [ ] Normalizar automaticamente escala y origen de los modelos.
- [ ] Generar o asignar colision de forma controlada.
- [ ] Permitir ajustar posicion, rotacion y escala desde el panel derecho.
- [ ] Permitir definir si un objeto es decorativo, solido, interactivo o
      generador de entidades.
- [ ] Validar que un objeto no quede flotando o enterrado sin que el usuario
      lo confirme.
- [ ] Aplicar restricciones de pendiente y altura cuando corresponda.

### Fase 5 - Modelos propios del usuario

- [ ] Crear opcion Importar modelo en la biblioteca.
- [ ] Soportar primero archivos GLB/glTF.
- [ ] Evaluar soporte secundario para OBJ si aporta valor.
- [ ] Evitar depender de FBX para importacion durante la ejecucion.
- [ ] Copiar los archivos importados a una carpeta de contenido del usuario.
- [ ] Validar tamano del archivo.
- [ ] Validar cantidad de poligonos.
- [ ] Validar tamano y cantidad de texturas.
- [ ] Normalizar unidades, escala y orientacion.
- [ ] Permitir elegir o generar una colision simplificada.
- [ ] Generar una miniatura del modelo.
- [ ] Mostrar una vista previa antes de agregarlo a la biblioteca.
- [ ] Guardar un identificador estable para cada asset.
- [ ] Rechazar scripts o logica ejecutable dentro de los paquetes importados.
- [ ] Sanitizar nombres y rutas para evitar path traversal.
- [ ] Mostrar mensajes claros cuando un modelo no pueda cargarse.
- [ ] Definir como se empaquetan los modelos propios junto al mapa.
- [ ] Definir que ocurre si un mapa necesita un asset que falta.

### Fase 6 - Guardado, carga y prueba

- [ ] Definir el formato de archivo del mapa.
- [ ] Guardar semilla, tamano y configuracion del terreno.
- [ ] Guardar capas de altura y reglas de materiales.
- [ ] Guardar cambios de terreno por chunk, no mallas completas.
- [ ] Guardar objetos como identificador, posicion, rotacion y escala.
- [ ] Guardar entidades y puntos de aparicion.
- [ ] Guardar lista de paquetes o assets externos requeridos.
- [ ] Crear Nuevo mapa.
- [ ] Crear Abrir mapa.
- [ ] Crear Guardar mapa.
- [ ] Crear Guardar como.
- [ ] Mostrar confirmacion si se va a perder trabajo sin guardar.
- [ ] Implementar autosalvado opcional.
- [x] Crear modo Probar mapa.
- [x] Cargar el mismo archivo en el mundo jugable.
- [ ] Permitir volver del modo de prueba al editor.
- [ ] Verificar que los cambios no se pierdan al probar el mapa.
- [ ] Probar mapas vacios, pequenos, grandes y con assets externos.

### Fase 7 - Pulido de experiencia

- [ ] Agregar atajos de teclado configurables.
- [ ] Agregar leyenda de controles dentro de la interfaz.
- [ ] Agregar minimapa.
- [ ] Mostrar posicion, altura y pendiente bajo el cursor.
- [ ] Mostrar contador de objetos y advertencias de rendimiento.
- [ ] Agregar estados de carga al regenerar terreno.
- [ ] Evitar bloquear toda la interfaz durante operaciones largas.
- [ ] Agregar confirmaciones para borrar o limpiar grandes zonas.
- [ ] Agregar validacion del mapa antes de publicarlo o probarlo.
- [ ] Crear mensajes de error recuperables.
- [ ] Revisar el editor en resoluciones pequenas y moviles si aplica.
- [ ] Verificar que el estilo visual mantenga la identidad PSX del proyecto.

### Fase 8 - Compartir y multijugador

- [ ] Definir si los mapas se pueden exportar como paquetes.
- [ ] Crear un paquete con mapa, manifest y assets propios.
- [ ] Agregar version del formato del mapa.
- [ ] Agregar hash de los assets para detectar cambios.
- [ ] Validar los paquetes tambien en el servidor.
- [ ] Definir como un cliente descarga los assets que le faltan.
- [ ] Definir cache local de contenido.
- [ ] Impedir que un paquete pueda ejecutar codigo arbitrario.
- [ ] Probar que dos jugadores vean el mismo terreno y objetos.
- [ ] Resolver compatibilidad cuando el creador actualiza un asset.
- [ ] Evaluar un repositorio tipo Workshop solo si el proyecto lo necesita.

### Fase 9 - Esculpido volumetrico avanzado

- [ ] Definir si realmente se necesitan cuevas en la primera version.
- [ ] Agregar almacenamiento de densidad 3D para zonas especiales.
- [ ] Crear pincel para excavar.
- [ ] Crear pincel para rellenar.
- [ ] Crear formas para tuneles, cuevas y cavidades.
- [ ] Regenerar volumen y colision de los chunks afectados.
- [ ] Mantener continuidad entre fronteras de chunks.
- [ ] Guardar modificaciones volumetricas de forma compacta.
- [ ] Resolver objetos que queden dentro de una excavacion.
- [ ] Medir el coste de CPU, memoria y guardado.

## 1. Vision del producto

El creador de mapas sera un modo del juego, no necesariamente una aplicacion
separada. El usuario podra entrar desde el menu principal, crear un mapa,
editarlo desde arriba, colocar objetos y pulsar Probar para jugarlo.

La experiencia buscada es la de un editor de estrategia clasico:

- El mapa debe ser legible de un vistazo.
- Las herramientas deben estar siempre a mano.
- La colocacion debe sentirse rapida y precisa.
- El usuario debe poder experimentar sin conocer programacion.
- Los errores de colocacion deben ser visibles antes de confirmar.
- El mapa debe poder probarse sin salir del flujo de edicion.

La interfaz puede tener una identidad propia inspirada en Red Alert 1, sin
copiar sus recursos graficos: paneles compactos, paleta de iconos, vista
principal amplia, controles directos y mucha informacion util sin adornos
innecesarios.

## 2. Primera version recomendada

La primera version sera un editor 3D del mismo terreno del juego:

1. Un mapa nuevo se representa como una cuadricula plana de muestras de altura.
2. El `ChunkManager` convierte esas muestras en la malla Marching Cubes real.
3. La camara empieza cenital y puede orbitar alrededor del mapa con el mouse.
4. Las flechas desplazan el foco lateralmente por el mapa.
5. La colision se reconstruye junto con la malla despues de cada edicion.
6. Los objetos 3D se colocan sobre las posiciones reales del mundo.

La rejilla es solo una ayuda visual: no crea terreno paralelo ni cubos de
maqueta. La superficie que se ve y se puede seleccionar es la misma malla que
usa el jugador, con el mismo material PSX y la misma colision.

Las cuevas y los tuneles quedan como una extension volumetrica posterior. El
hecho de que ya usemos Marching Cubes ayuda, pero no elimina la complejidad de
editar densidad 3D, actualizar chunks, conservar colisiones y guardar los
cambios.

## 3. Arquitectura propuesta

### 3.1 Editor

Una escena de editor contiene:

- Camara 3D superior en perspectiva.
- Nodo raiz del documento del mapa.
- Terreno visible y rejilla.
- Objetos colocados.
- Sistema de seleccion.
- Paneles de interfaz.
- Historial de comandos para Deshacer/Rehacer.

El editor no deberia modificar directamente la escena jugable como fuente
principal. Debe trabajar sobre un documento de datos y generar la escena
visual a partir de ese documento.

### 3.2 Documento del mapa

El documento debe ser la fuente de verdad. Como minimo tendra:

- Version del formato.
- Nombre del mapa.
- Semilla.
- Tamano y escala de la cuadricula.
- Datos de altura.
- Nivel del mar.
- Capas de materiales.
- Objetos colocados.
- Entidades y puntos de aparicion.
- Assets externos requeridos.
- Configuracion de iluminacion o ambiente si se decide incluirla.

Los objetos deben guardar referencias y transformaciones, no copias completas
de sus modelos. Esto reduce el tamano del archivo y permite que un mismo asset
se use muchas veces.

### 3.3 Terreno y chunks

El terreno actual esta basado en Marching Cubes. La propuesta es mantenerlo
como la etapa que transforma los datos editables en una malla:

`datos de altura + reglas de terreno -> densidad -> Marching Cubes -> malla + colision`

Cuando se edite una zona, solo deben regenerarse los chunks que intersecten el
radio de la modificacion. Los vecinos pueden necesitar una pequena actualizacion
si la edicion alcanza su frontera.

No conviene guardar la malla generada como formato principal porque:

- ocupa mas espacio;
- es dificil de editar;
- complica Deshacer/Rehacer;
- ata el mapa a una version concreta del generador.

## 4. Interfaz tipo Red Alert

### Barra superior

- Nuevo mapa.
- Abrir.
- Guardar.
- Guardar como.
- Deshacer.
- Rehacer.
- Configuracion del mapa.
- Probar mapa.
- Salir al menu.

### Panel izquierdo

Categorias de colocacion:

- Terreno.
- Agua.
- Texturas y biomas.
- Arboles y vegetacion.
- Rocas y decoracion.
- Edificios.
- Puertas y objetos interactivos.
- Unidades y enemigos.
- Puntos de aparicion.
- Assets importados.

### Vista central

- Vista superior del mapa.
- Rejilla opcional.
- Cursor de pincel.
- Indicador de seleccion.
- Vista de pendientes.
- Vista de alturas.
- Lineas o limites de zonas importantes.

### Panel derecho

Cuando no hay seleccion:

- Nombre del mapa.
- Tamano.
- Semilla.
- Nivel del mar.
- Reglas de capas.
- Estadisticas de rendimiento.

Cuando hay un elemento seleccionado:

- Nombre o identificador.
- Posicion.
- Altura sobre el terreno.
- Rotacion.
- Escala.
- Tipo de colision.
- Propiedades especificas del objeto.

### Controles previstos

- Rueda del mouse: acercar o alejar.
- Boton central: desplazar el mapa.
- Click izquierdo: aplicar herramienta o seleccionar.
- Click derecho: cancelar, borrar o volver.
- Shift: seleccion multiple.
- Ctrl: duplicar o copiar.
- Escape: cancelar la operacion actual.

El zoom debe centrarse en el punto que esta bajo el cursor. Ese detalle hace
que la navegacion se sienta como Google Maps y evita que el usuario pierda la
zona que estaba editando.

## 5. Sistema de terreno

### Herramientas iniciales

- **Subir:** incrementa la altura dentro del radio del pincel.
- **Bajar:** reduce la altura.
- **Suavizar:** aproxima cada celda a sus vecinas.
- **Aplanar:** lleva la zona hacia una altura de referencia.
- **Nivelar:** aplica exactamente una altura elegida.
- **Playa:** crea una transicion controlada alrededor del agua.
- **Pintar bioma:** cambia la regla de material sin cambiar necesariamente la
  altura.
- **Agua:** cambia el nivel o crea una masa de agua seleccionada.

Cada pincel deberia tener, como minimo:

- Radio.
- Intensidad.
- Forma circular o cuadrada.
- Atenuacion en los bordes.
- Vista previa antes de confirmar.

### Altura contra pendiente

La textura no deberia depender unicamente de la altura. Una regla mas natural
combina varios factores:

- Altura absoluta.
- Pendiente de la superficie.
- Distancia al agua.
- Bioma pintado por el usuario.
- Opcionalmente humedad o temperatura.

Ejemplo: una zona puede ser verde por altura, pero convertirse en roca si su
pendiente es demasiado pronunciada. Una zona alta y plana puede ser una meseta
con pasto o nieve, segun las reglas elegidas.

## 6. Menu de capas

El menu de capas sera editable y funcionara como una tabla de reglas. Cada fila
puede tener:

- Nombre de la capa.
- Altura minima.
- Altura maxima.
- Textura o material.
- Color de respaldo.
- Suavidad de la transicion.
- Pendiente maxima o minima.
- Prioridad.
- Visibilidad.

Capas iniciales recomendadas:

1. Agua.
2. Fondo marino o terreno bajo.
3. Playa.
4. Pasto.
5. Tierra o barro.
6. Roca.
7. Montana.
8. Nieve.

El usuario podria cambiar, por ejemplo, el inicio de la roca de 18 metros a
12 metros sin tener que modificar el terreno. Tambien podria hacer que la
nieve aparezca a partir de cierta altura, pero solo en zonas con pendiente
suave o con una transicion mas amplia.

La interfaz deberia mostrar una previsualizacion de la regla. Una opcion util
seria seleccionar una capa y ver el mapa coloreado exclusivamente por esa
capa, para comprender donde se aplicara antes de guardar.

## 7. Biblioteca de modelos

La biblioteca tendra dos origenes:

### Modelos incluidos

Son los assets que ya forman parte del proyecto. Deben aparecer organizados y
listos para colocar:

- Vegetacion actual.
- Rocas.
- Decoracion.
- Casas y puertas.
- Props urbanos.
- Entidades disponibles.
- Elementos de agua o infraestructura.

### Modelos propios

El usuario podra importar modelos desde su computadora y convertirlos en
assets disponibles para el mapa. El formato recomendado para la primera version
es GLB/glTF porque puede cargarse en runtime con un flujo mas controlado que FBX.

Cada modelo importado deberia pasar por este flujo:

1. Elegir archivo.
2. Validar extension, tamano y estructura.
3. Cargar una vista previa.
4. Normalizar escala y orientacion.
5. Elegir o generar colision.
6. Crear miniatura.
7. Asignar identificador.
8. Guardarlo en la biblioteca del usuario.
9. Permitir colocarlo como cualquier modelo incluido.

Los modelos propios deben ser datos, no programas. No deberian poder traer
GDScript, Rust u otra logica ejecutable. El servidor debe volver a validar los
paquetes aunque el editor local ya los haya aceptado.

## 8. Formato de paquete para compartir

Un paquete futuro podria tener una estructura conceptual como esta:

```text
mi_mapa/
  manifest.json
  map_data.json
  terrain/
  assets/
    roca.glb
    roca.png
  icons/
    roca.png
```

El `manifest` deberia declarar:

- Nombre y version del mapa.
- Autor.
- Version del formato.
- Lista de assets requeridos.
- Hashes de archivos.
- Reglas de compatibilidad.

El mapa deberia poder abrirse aunque falte un asset, mostrando un marcador o
modelo de reemplazo y un mensaje claro. Nunca deberia fallar silenciosamente.

## 9. Deshacer y rendimiento

Deshacer/Rehacer sera importante porque el terreno se modifica con pinceles.
La mejor unidad de historial no es la malla completa, sino una operacion de
datos:

- chunk afectado;
- celdas modificadas;
- valores anteriores;
- valores nuevos;
- regla o herramienta usada.

Para mantener el editor fluido:

- regenerar solo los chunks afectados;
- mostrar una previsualizacion barata mientras se mueve el pincel;
- aplicar la malla final al soltar el mouse;
- evitar regenerar todo el mapa por cada movimiento;
- limitar la cantidad de objetos y poligonos;
- usar cargas diferidas para modelos pesados;
- avisar antes de operaciones grandes.

La generacion en segundo plano debe tratarse con cuidado porque el proyecto ya
usa Rust mediante GDExtension. Primero conviene conseguir una version correcta
y estable en el hilo principal; despues se puede estudiar procesamiento en
segundo plano con una frontera de datos segura y pruebas especificas.

## 10. Riesgos principales

### Terreno Marching Cubes

Es excelente para superficies organicas y futuras cuevas, pero editarlo de
forma interactiva exige regeneracion, colisiones, continuidad de chunks y
persistencia. Por eso la primera version debe usar una capa de alturas.

### Modelos externos

Los assets de terceros pueden tener escalas, ejes, materiales o colisiones
incorrectas. La importacion necesita vista previa, normalizacion y un modelo de
reemplazo cuando algo falle.

### Compartir contenido

Cargar archivos creados por otros jugadores tiene riesgos de seguridad y de
rendimiento. La primera version puede ser local. La distribucion por red debe
mantener los paquetes sin codigo ejecutable y validar todo en el servidor.

### Mapas grandes

Una cuadricula muy grande y muchos objetos pueden afectar memoria, tiempos de
carga y guardado. Debemos definir un tamano inicial razonable y medir antes de
prometer mapas enormes.

### Editor y mundo jugable

El editor no debe duplicar reglas distintas para terreno y materiales. El
mismo documento debe poder alimentar el editor y el modo de juego; de lo
contrario el mapa podria verse bien en el editor y cambiar al jugarlo.

## 11. Decisiones recomendadas

Estas son las decisiones iniciales recomendadas, pendientes de confirmacion:

- Editor dentro del juego, no launcher separado.
- Primera version para un jugador.
- Terreno de superficie editable con cuadricula de alturas.
- Marching Cubes como generador de la superficie.
- Cuevas y esculpido 3D completo como fase posterior.
- GLB/glTF como formato principal de modelos propios.
- Mapa guardado como datos, no como malla horneada.
- Capas basadas en altura, pendiente y distancia al agua.
- Modelos propios sin codigo ejecutable.
- Compartir mapas despues de estabilizar el editor local.

## 12. Criterio de primera version terminada

La primera version puede considerarse funcional cuando el usuario pueda:

1. Entrar al editor desde el menu.
2. Crear un mapa nuevo.
3. Moverse por una vista superior con zoom suave.
4. Subir, bajar, suavizar y aplanar el terreno.
5. Cambiar el nivel del mar.
6. Editar las capas de altura y sus materiales.
7. Colocar modelos incluidos.
8. Seleccionar, mover, rotar, duplicar y borrar objetos.
9. Guardar y abrir el mapa.
10. Deshacer y rehacer cambios importantes.
11. Importar al menos un modelo GLB propio.
12. Pulsar Probar mapa y jugar en el resultado guardado.

Las cuevas, los tuneles, el intercambio online y un catalogo tipo Workshop no
son requisitos para esta primera version. Son extensiones importantes, pero no
deben retrasar la experiencia central del editor.

## 13. Orden de implementacion sugerido

El orden recomendado es:

1. Documento de mapa y guardado basico.
2. Camara superior, zoom y desplazamiento.
3. Colocacion de modelos incluidos.
4. Seleccion, transformacion y borrado.
5. Capas y reglas de materiales.
6. Herramientas de altura.
7. Regeneracion parcial de terreno y colision.
8. Deshacer/Rehacer.
9. Probar mapa.
10. Importacion de GLB propio.
11. Validacion, limites y mensajes de error.
12. Empaquetado y compartir.
13. Esculpido volumetrico con cuevas.

Este orden permite tener algo visible y util pronto, mientras cada etapa
prueba una parte critica de la arquitectura antes de construir la siguiente.

## Registro de decisiones

| Fecha | Decision | Estado |
|---|---|---|
| 2026-08-20 | Crear un editor de mapas inspirado en Red Alert 1 | Propuesta |
| 2026-08-20 | Usar vista superior con zoom y desplazamiento tipo mapa | Propuesta |
| 2026-08-20 | Permitir modelos incluidos y modelos propios | Propuesta |
| 2026-08-20 | Hacer editables las capas de altura y materiales | Propuesta |
| 2026-08-20 | Empezar con terreno de superficie y dejar cuevas para despues | Recomendacion |
| 2026-08-20 | Priorizar GLB/glTF para modelos importados en runtime | Recomendacion |
