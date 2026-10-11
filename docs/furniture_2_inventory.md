# Inventario Oficial y Hoja de Ruta: Mobiliario y Props 2.0 (Interior Village)

**Origen:** `assets/textures/furniture 2.0/` ([objects-interiorvillage-alpha](https://elbolilloduro.itch.io/objects-interiorvillage-alpha) por *elbolilloduro*)  
**Arquitectura:** +0 Draw Calls en Hardware Instancing vía `ObjectEngine` (Play Sector X).

---

## Índice de Categorías
1. [Tanda 1: Sofás, Sillones y Sillas de Salón (Imagen 5)](#tanda-1-sofás-sillones-y-sillas-de-salón)
2. [Tanda 2: Camas y Ropa de Cama (Imagen 3)](#tanda-2-camas-y-ropa-de-cama)
3. [Tanda 3: Almacenamiento, Cómodas, Aparadores, Libreros y Armarios (Imagen 4)](#tanda-3-almacenamiento-cómodas-aparadores-libreros-y-armarios)
4. [Tanda 4: Cocina y Comedor (Imagen 2)](#tanda-4-cocina-y-comedor)
5. [Tanda 5: Decoración, Lámparas, Radios, Comida y Props (Imagen 1)](#tanda-5-decoración-lámparas-radios-comida-y-props)
6. [Catálogo de Texturas de Soporte y Arquitectónicas](#catálogo-de-texturas-de-soporte-y-arquitectónicas)

---

## Tanda 1: Sofás, Sillones y Sillas de Salón

Colección completa de asientos acolchados, sofás Chesterfield, sillones orejeros y sillas francesas correspondientes a la **Imagen 5**.

| ID Modelo | Descripción | Textura Principal | Estilo / Características |
| :--- | :--- | :--- | :--- |
| `sofa_damask_gold` | Sofá 3 plazas damasco dorado | `Armchair.png` | Tapizado brocado dorado brillante, remates y reposabrazos de madera noble curvada |
| `sofa_floral_cottage` | Sofá 2 plazas floral | `Armchair_01.png` | Tela estampada de rosas y flores silvestres pastel, faldón inferior recto |
| `sofa_wood_minimal` | Sofá 3 plazas estructura madera | `Armchair_02.png` | Marco de madera visto con brazos geométricos y cojines lisos de lino crema |
| `sofa_chesterfield_red` | Sofá Chesterfield 3 plazas granate | `Armchair_03.png` | Cuero capitoné con botones hundidos profundos, brazos en voluta enrollada |
| `armchair_chesterfield_red`| Sillón Chesterfield 1 plaza | `Armchair_04.png` | Butaca individual a juego con respaldo curvo y capitoné de cuero vino |
| `armchair_wingback_leather`| Sillón orejero marrón vintage | `Armchair_05.png` | Cuero desgastado café con remaches de latón y orejeras altas clásicas |
| `armchair_tufted_charcoal` | Sillón capitoné gris carbón | `Armchair_06.png` | Tela gris marengo con botones capitoné y brazos acolchados cuadrados |
| `armchair_tufted_sky_blue` | Sillón capitoné azul cielo | `Armchair_07.png` | Respaldo alto azul turquesa con tachuelas plateadas y botones capitoné |
| `armchair_velvet_mustard`  | Sillón terciopelo amarillo mostaza | `Armchair_08.png` | Terciopelo dorado/mostaza capitoné con silueta envolvente setentera |
| `chair_dining_cream`       | Silla de comedor tapizada recta | `Chair.png` / `Chair_03.png` | Respaldo vertical con marco de madera y asiento acolchado crema |
| `chair_baroque_oval`       | Silla clásica respaldo ovalado | `Chair_04.png` | Respaldo ovalado acolchado en tela adamascada clara y patas curvas doradas |
| `armchair_louis_xv_blue`   | Sillón Luis XV Toile de Jouy azul| `Chair_05.png` | Estructura de madera con brazos curvados y tapizado blanco/azul floral |

---

## Tanda 2: Camas y Ropa de Cama

Colección de camas individuales y matrimoniales correspondientes a la **Imagen 3**.

| ID Modelo | Descripción | Textura Principal | Dimensiones | Componentes |
| :--- | :--- | :--- | :--- | :--- |
| `bed_single_wood_plaid` | Cama individual madera rústica | `bed.png` | 1.10m x 2.05m | Cabecero alto de madera, piecero bajo, almohada y cobertor escocés a cuadros |
| `bed_double_wrought_iron` | Cama matrimonial hierro forjado | `bed_01.png` | 1.65m x 2.10m | Estructura tubular blanca con arabescos curvos, 2 almohadas y colcha geométrica |
| `bed_double_wood_grey` | Cama matrimonial madera clara | `bed_02.png` | 1.70m x 2.10m | Cabecero recto de roble, 2 almohadas y edredón gris/marrón liso |
| `bed_double_wood_rustic` | Cama matrimonial madera dorada | `bed_03.png` | 1.75m x 2.15m | Marco de madera gruesa natural, 2 almohadas y frazada con banda decorativa |
| `bed_double_wood_wrinkled`| Cama matrimonial madera oscura | `bed_04.png` | 1.70m x 2.10m | Cabecero rústico con postes salientes, 2 almohadas y sábanas blancas con pliegues |

---

## Tanda 3: Almacenamiento, Cómodas, Aparadores, Libreros y Armarios

Mobiliario de guardado correspondiente a la **Imagen 4**. Todas las cómodas, cajoneras y armarios soportan apertura y cierre interactivo (`drawer_slides`, `doors_open`) con bandejas interiores vacías.

| ID Modelo | Descripción | Textura Principal | Características Interactivas |
| :--- | :--- | :--- | :--- |
| `chest_drawers_tall_5` | Cómoda chifonier alta 5 cajones | `Chest_drawers.png` | 2 cajones superiores angostos + 3 anchos inferiores con tiradores metálicos |
| `chest_drawers_light_4` | Cómoda madera clara 4 cajones | `Chest_drawers_01.png` | 4 cajones deslizables horizontales con tiradores de perilla |
| `chest_drawers_white_3` | Cómoda moderna blanca/gris 3 cajones | `Chest_drawers_02.png` | 3 gavetas anchas con tiradores redondos plateados |
| `nightstand_tapered_legs_3`| Mesita de noche 3 cajones patas cónicas| `Chest_drawers_03.png` | 3 gavetas con tiradores oscuros y patas delgadas estilizadas |
| `nightstand_tapered_legs_2`| Mesita de noche 2 cajones patas cónicas| `Chest_drawers_04.png` | 2 gavetas compactas ideales para cabeceras de cama |
| `sideboard_buffet_3drawers` | Aparador buffet ancho (2 puertas + 3 cajones)| `Chest_drawers_05.png` | 2 puertas laterales batientes + 3 cajones centrales deslizables |
| `sideboard_low_2doors` | Mueble bajo 2 puertas con patas cónicas | `Chest_drawers_06.png` | 2 puertas frontales batientes con repisa interior |
| `cupboard_welsh_dresser` | Alacena alta rústica (*Welsh Dresser*) | `Cupboard.png` | Repisas escalonadas abiertas arriba, cajones medios y puertas abajo |
| `cupboard_vitrine_books` | Vitrina alta madera noble con libros | `Cupboard_01.png` / `02` | Puertas con cristales biselados y lomos de enciclopedias iluminadas |
| `cupboard_glass_tall` | Aparador vitrina con puertas acristaladas | `Cupboard_03.jpg` | Armazón clásico de caoba con paneles de vidrio |
| `bookcase_full_books_tall` | Librero alto saturado de libros | `Bookcase.png` / `01` | Múltiples repisas con cientos de lomos de libros variados |
| `bookcase_books_low` | Librero bajo alargado con libros | `Bookcase_02.png` | 2 niveles con hileras de libros ordenados |
| `wardrobe_open_clothes` | Ropero abierto con ropa colgada en perchas | `Wardrobe.png` | Barra con vestidos/camisas coloridas, repisas de zapatos y 2 cajones |
| `wardrobe_open_coats` | Ropero abierto con abrigos y chaquetas | `Wardrobe_01.png` | Barra superior con sacos y gabardinas, espejo interior y cajones inferiores |

---

## Tanda 4: Cocina y Comedor

Mobiliario modular de cocina, electrodomésticos y mesas de comedor correspondientes a la **Imagen 2**.

| ID Modelo | Descripción | Texturas | Componentes |
| :--- | :--- | :--- | :--- |
| `kitchen_corner_wall_cabinet`| Alacena superior esquinera blanca | `Fitment.png` / `02` | Módulos colgantes esquineros de 4 puertas blancas con tiradores verticales |
| `kitchen_base_counter_sink` | Encimera baja en L con fregadero | `Fitment.png`, `Marble.jpg` | Encimera de mármol negro, fregadero de acero inoxidable con grifo curvado |
| `kitchen_island` | Isla central de cocina | `Fitment.png`, `Marble.jpg` | Bloque independiente blanco con encimera de mármol negro pulido |
| `kitchen_stove_gas_white` | Estufa de gas blanca con horno | `Stove.jpg`, `Metal.jpg` | 4 quemadores superiores, perillas frontales, puerta de horno con cristal |
| `kitchen_refrigerator_beige`| Refrigerador retro color crema | `Refrigerator.png` | 2 puertas (congelador superior y refrigerador inferior) con manijas largas |
| `table_hex_gingham_rack` | Mesa hexagonal mantel vichy con vajilla | `Table.png`, `Plates.png` | Mantel rojo a cuadros drapeado con escurreplatos, vasos y cubiertos |
| `table_rect_gingham` | Mesa rectangular con mantel vichy rojo | `Table_01.png`, `Fabric.jpg` | Mantel a cuadros rojo con caídas laterales arrugadas y 4 patas de madera |
| `table_rect_lace_floral` | Mesa rectangular con mantel de encaje | `Table_02.png` | Mantel floreado con encaje transparente y patas oscuras inclinadas |
| `kitchen_hanging_utensils` | Riel de pared con utensilios de cocina | `Cutlery.png`, `Metal.jpg` | Barra metálica de pared con espátula, cucharón, espumadera y tenedor |
| `chair_kitchen_slat` | Silla de comedor respaldo de listones | `Chair.png` | Silla básica de pino natural con barrotes verticales |
| `chair_kitchen_spindle` | Silla de comedor barrotes torneados | `Chair_01.png` | Asiento ergonómico y respaldo en arco con barrotes torneados estilo Windsor |
| `chair_kitchen_upholstered` | Silla de comedor patas oscuras y tela | `Chair_02.png` | Respaldo y asiento tapizados en tela beige con patas de nogal oscuro |

---

## Tanda 5: Decoración, Lámparas, Radios, Comida y Props

Accesorios de sobremesa, piso, paredes y comida correspondientes a la **Imagen 1**.

### Iluminación y Ventilación
* `fan_pedestal_tall`: Ventilador de pie alto oscuro con reja octagonal y aspas (`Ventilator.png`).
* `fan_desk_table`: Ventilador de sobremesa bajo con base pesada (`Ventilator_01.png`).
* `fan_ceiling`: Ventilador de techo de aspas de madera (`Ceiling_Fan.png` / `01` / `02`).
* `lamp_table_shade`: Lámpara de noche con base de cerámica y pantalla de tela plisada (`Lamp.png` / `Lamp_Emissor.png`).
* `lamp_banker_green`: Lámpara de banquero clásica con pantalla de cristal verde esmeralda (`Lamp_02.png` / `02_Emissor.png`).
* `lamp_desk_gooseneck_black`: Flexo de mesa cuello de ganso negro (`Desk_lamp.png` / `Emissor`).
* `lamp_desk_gooseneck_white`: Flexo de mesa cuello de ganso blanco (`Desk_lamp_01.png` / `Emissor`).
* `socket_lightbulb_stand`: Portalámparas con bombilla enroscada desnuda (`Focus.png` a `Focus_02.png`).

### Tecnología y Comunicación Vintage
* `alarm_clock_digital_red`: Despertador digital con pantalla LED roja (`16:20`) (`Alarm_clock.png` / `Emissor`).
* `alarm_clock_digital_green`: Despertador digital con pantalla LED verde (`12:53`) (`Alarm_clock_01.png` / `Emissor`).
* `radio_vintage_dial`: Radio receptor analógico con dial horizontal y altavoz (`Radio.png`).
* `radio_portable`: Radio transistor portátil con antena (`Radio_01.png` / `Radio_02.png`).
* `walkie_talkie_military`: Radio transmisor militar verde oliva con antena y perillas (`Gadgets.png`).
* `phone_rotary_black`: Teléfono clásico de disco negro con auricular sobre horquilla (`Phone.png`).
* `phone_pushbutton_beige`: Teléfono de botones beige de oficina con teclado numérico (`Phone_01.png`).

### Decoración, Oficina y Desechos
* `paintings_wall_canvas`: Cuadros de pared (Virgen renacentista, caballero medieval, paisajes lacustres y rurales) (`Paintings.jpg`).
* `magazines_books_stack`: Pila de libros y revistas con portadas ilustradas (`Books.png`).
* `trash_can_liner`: Bote de basura con bolsa de plástico gris sobresaliendo (`Trash_can.png`).
* `garbage_bag_full`: Bolsa de basura negra llena y atada con arrugas volumétricas (`Garbage_bags.png`).
* `vase_flower_rose`: Florero negro facetado con rosa roja (`Flower_Table.png`).
* `vase_flower_lavender`: Florero cilíndrico alargado con vara de lavanda morada (`Flower_Table_01.png`).

### Alimentos y Bebidas
* `food_pizza_box_open`: Caja de pizza de cartón abierta con pizza de pepperoni humeante (`Box_Pizza.png`, `Pizza.png`).
* `food_pizza_slice`: Rebanada triangular de pizza servida (`Pizza.png`).
* `food_roast_chicken`: Pollo asado dorado entero sobre bandeja (`Chicken.png`).
* `food_fried_basket`: Bandeja con alitas y empanizados fritos (`Fried_Foods.png`).
* `food_meat_cuts`: Bandeja de bistecs y cortes de carne cruda (`Meat.png`).
* `food_soup_bowl`: Tazón hondo de ramen/caldo con fideos y verduras (`Plate_food.png`, `Cereal_bowl.png`).
* `food_dinner_plate`: Plato de comida con guisado servido (`Plate_food_01.png`).
* `food_pie_slice`: Rebanada de pastel/tarta de frutos rojos (`Cake.png`, `Cake_01.png`, `Cake_02.png`).
* `food_flan`: Porción de flan con caramelo brillante (`Flan.png`).
* `food_ice_cream_tub`: Bote de helado con cuchara (`Ice_cream.png`, `Ice_cream_01.png`).
* `food_popsicle_red`: Paleta de dulce/hielo roja con palito de madera (`Palette.png`).
* `drink_soda_bottle`: Botella de refresco de cola de vidrio clásica (`Bottle.png`).
* `drink_milk_jug`: Galón plástico de leche blanca (`Milk.png`).
* `drink_milk_strawberry`: Tetra pak de leche sabor fresa (`Box_strawberries.png`).
* `drink_can`: Lata de refresco de aluminio (`Can.png`).

---

## Catálogo de Texturas de Soporte y Arquitectónicas

Estas texturas no representan objetos independientes, sino materiales base y componentes ambientales:

1. **Acabados Arquitectónicos:**
   * `Concrete.jpg`, `Concrete_01.png`: Superficies de concreto liso y hormigón rústico.
   * `Tiles.jpg`, `Tiles_01.png`: Azulejos cerámicos para muros y pisos de baño o cocina.
   * `Door.jpg`: Puerta residencial con moldura y pomo metálico.
   * `Rooftiles.png`, `RooftilesSlate.jpg`: Tejas coloniales de barro y tejas planas de pizarra.
   * `WallpaperForties.jpg`: Empapelado floral de los años 40.
   * `Wood.jpg` a `Wood_06.jpg`: Variedad de maderas lisas y desgastadas para pisos o muebles secundarios.
2. **Materiales de Muebles:**
   * `Marble.jpg`: Mármol / granito negro para encimeras de cocina.
   * `Metal.jpg`: Superficie metálica cepillada para electrodomésticos y bisagras.
   * `Fabric.jpg`: Tejido de tela neutro.
3. **Máscaras de Emisión (`*_Emissor.png`):**
   * Canales de luz para displays LED (`Alarm_clock_*`), bombillas (`Focus_*`, `Lamp_*`) y flexos (`Desk_lamp_*`).
