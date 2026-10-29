# Hiscores en MiSTer: Bagman y extensión genérica de JTFRAME

Estado consolidado el 29 de octubre de 2026. Este documento reúne el diagnóstico de Bagman, la arquitectura añadida a JTFRAME, los juegos validados, las decisiones tomadas y la atribución del trabajo. Es la referencia canónica del proyecto de hiscores.

## 1. Resultados obtenidos

Hay dos desarrollos relacionados, pero independientes:

1. **Bagman:** corrección del bus de lectura del AY-3-8910 que impedía introducir las iniciales correctamente.
2. **JTFRAME/JT1942:** sistema genérico y opcional de guardado de puntuaciones, validado con 1942, Vulgus y Pirate Ship Higemaru.

Artefactos de prueba actuales:

| Juego | MRA | RBF | Tamaño NVRAM |
|---|---|---|---:|
| Bagman | `Bagman-initials-fix/outputs/Bagman (Hiscore).mra` | `Bagman_Hiscore.rbf` | El definido por el núcleo Bagman. |
| 1942 | `JTFRAME-hiscore/1942 (Hiscore).mra` | `JT1942_Hiscore.rbf` | 410 bytes. |
| Vulgus | `JTFRAME-hiscore/Vulgus (Hiscore).mra` | `JT1942_Hiscore.rbf` | 68 bytes. |
| Pirate Ship Higemaru | `JTFRAME-hiscore/Pirate Ship Higemaru (Hiscore).mra` | `JT1942_Hiscore.rbf` | 140 bytes. |

Los tres juegos JTFRAME comparten el mismo RBF porque pertenecen a la familia JT1942, pero MiSTer crea un archivo NVRAM distinto para cada MRA. La nomenclatura local visible es siempre `Nombre (Hiscore)` y los RBF personalizados llevan el sufijo `_Hiscore`, para no confundirlos con versiones oficiales.

## 2. Diagnóstico y corrección de Bagman

### Síntoma comprobado

En dos MiSTer distintos, tanto con mando como con I-PAC, la pantalla de iniciales aparecía brevemente, permitía cambiar una letra durante un instante y terminaba grabando `AA`. En MAME la misma ROM permitía introducir las iniciales normalmente. Esto descartó como hipótesis principal los controles y la configuración del juego.

Se consideró retirar temporalmente del MRA el bloque de configuración de hiscores y su NVRAM para aislar el subsistema, pero esa prueba no llegó a ser necesaria para establecer la causa final. No debe presentarse como una validación realizada.

### Causa encontrada

El multiplexor de lectura de CPU entregaba siempre `ym_8910_data` durante cualquier ciclo de E/S, aunque el AY-3-8910 no estuviera conduciendo su salida. En la ruta inactiva ese valor podía ser cero. Bagman complementa el dato de entrada, por lo que cero se interpretaba como controles pulsados y aceleraba/confirmaba de forma espuria la introducción de iniciales.

### Parche

Commit local: `82b738f Fix high-score initials input`, rama `fix-high-score-initials` del repositorio `Bagman-initials-fix/work/Arcade-Bagman_MiSTer`.

El cambio en `rtl/bagman.vhd`:

- conecta `O_DA_OE_L` del AY a `ym_8910_data_oe_n`;
- usa `ym_8910_data` solo cuando el AY habilita realmente su salida;
- devuelve `X"FF"` en los demás ciclos de E/S.

`FF` es el valor inactivo correcto porque, después de la inversión realizada por el juego, significa que no hay ninguna entrada pulsada. El parche es pequeño y actúa sobre la emulación del bus, no sobre el sistema de hiscores.

### Verificación

El RBF compilado fue probado físicamente y la introducción de iniciales funcionó correctamente. Esta prueba demuestra la corrección del síntoma. No demuestra que cualquier incidencia futura de puntuaciones en Bagman tenga la misma causa.

## 3. Objetivo de la extensión JTFRAME

El sistema permite que un núcleo JTFRAME restaure y guarde tablas de récords sin incorporar el mapa de memoria de cada juego al motor común. Es opcional: los núcleos que no definen `JTFRAME_HISCORE` no deben cambiar de comportamiento ni consumir la lógica del subsistema.

No es un guardado de estado y no sustituye a una NVRAM real. Solo transfiere los rangos de memoria declarados para las puntuaciones.

## 4. Arquitectura

La solución se divide en tres capas:

1. **Motor genérico JTFRAME.** Interpreta descriptores compatibles con `hiscore.dat`, espera los bytes de validación, restaura datos y prepara una subida cuando cambian las puntuaciones.
2. **Interfaz de memoria petición/confirmación.** El núcleo expone de forma segura las RAM necesarias sin que JTFRAME conozca su implementación.
3. **Perfil por máquina.** `mame2mra.toml` describe rangos, validadores y excepciones; `mame2mra` genera el bloque ROM de índice 5 y la NVRAM de índice 6 del MRA.

### Contrato de memoria

La interfaz interna trabaja con direcciones de byte visibles para la CPU y datos de 8 bits. La adquisición segura de la memoria y cada transacción se confirman explícitamente; el motor no presupone RAM combinacional, una latencia fija ni un ancho físico concreto.

Esta separación se eligió para que un adaptador pueda resolver bancos, byte lanes, memorias distintas y cruces de reloj sin introducir esos detalles en el motor genérico. Higemaru confirmó la necesidad: sus rangos no se limitan a una única RAM de trabajo.

### Transporte MiSTer

Índices predeterminados:

| Índice | Contenido |
|---:|---|
| 5 | Configuración generada a partir del perfil. |
| 6 | Datos NVRAM de las puntuaciones. |

Los valores son parametrizables. La auditoría inicial del árbol JTFRAME mostró que estaban libres en la revisión estudiada, pero no se convirtieron en una dependencia rígida para futuras integraciones.

### Política de guardado

La opción del OSD controla el guardado automático. Abrir el OSD solicita una comprobación de los rangos configurados. Activar el guardado mientras el OSD ya está abierto también comprueba el estado, de modo que un récord conseguido antes de activar la opción no queda sin guardar.

`Saving` solo debe aparecer cuando el motor solicita realmente la subida. No se usa una periodicidad arbitraria. La detección se basa en cambios de los bytes relevantes respecto a la imagen conocida.

## 5. Perfiles validados

Los perfiles están en `cores/1942/cfg/mame2mra.toml` y sus rangos proceden de `plugins/hiscore/hiscore.dat` de MAME.

### 1942

```text
E800, longitud 0190
E9C0, longitud 0001
E040, longitud 0008
E028, longitud 0001
```

Tamaño total: 410 bytes. Probado físicamente: guarda, muestra `Saving` cuando corresponde y restaura los récords.

### Vulgus

```text
EE00, longitud 0041
EE47, longitud 0003
```

Tamaño total: 68 bytes. Probado físicamente con éxito.

### Pirate Ship Higemaru

```text
EE00, longitud 0082
EE97, longitud 0003
D04E, longitud 0007
```

Tamaño total: 140 bytes. Probado físicamente con éxito, incluidos guardado y restauración.

## 6. Prevención de guardados falsos

Un perfil puede declarar `ignore_changes` para offsets que deben seguir formando parte de la imagen NVRAM y de la restauración, pero no deben provocar por sí solos un guardado. `mame2mra` convierte esos offsets en la máscara compacta compatible con el motor, redondeada a filas completas de ocho bytes. Los bytes fuera de una máscara explícita siguen detectando cambios.

### Caso demostrado en 1942

Dos volcados consecutivos de 410 bytes, obtenidos sin jugar, diferían en un único punto:

- offset NVRAM `0x199`;
- dirección de RAM principal `0xE028`;
- valor anterior `0x01`, posterior `0x02`;
- los otros 409 bytes eran idénticos.

`E028` es una posición auxiliar de validación heredada de `hiscore.dat` y puede cambiar durante la ejecución sin que cambie la tabla visible. Por ello el perfil de 1942 declara `ignore_changes=[0x199]`. El byte continúa guardándose y restaurándose, pero una variación aislada ya no provoca `Saving`.

Esta excepción se añadió a 1942 porque existe evidencia binaria. No se trasladó a Vulgus ni Higemaru: no se observó el mismo problema en esos juegos. Nunca se deben ignorar offsets por semejanza o prevención; primero hay que capturar dos NVRAM alrededor de un guardado falso y comparar byte a byte.

## 7. Generación y compilación

La carpeta de trabajo `D:\Dropbox\dev\Mister\JTFRAME-hiscore` contiene:

- `jtcores`: fuentes modificadas;
- los tres MRA generados;
- `JT1942_Hiscore.rbf`;
- scripts de validación, generación y compilación;
- utilidades para localizar MRA, copiar pruebas y respaldar NVRAM.

Quartus 19.1 está disponible dentro del árbol general de herramientas. La compilación completa de JT1942 tarda aproximadamente 16 minutos en esta máquina; debe lanzarse en una terminal visible y el usuario la monitoriza. No se debe sondear continuamente el proceso. Si una prueba requiere reiniciar MiSTer, 30 segundos bastan en esta instalación.

El proyecto autónomo de elaboración del motor y el transporte IOCTL está en `modules/jtframe/ver/hiscore`. Sirve para detectar errores estructurales antes de pagar el coste de una compilación completa. No sustituye la prueba física de cada juego.

## 8. Incorporación de otro juego

1. Confirmar que el juego usa una familia/núcleo con adaptador de memoria para hiscores.
2. Obtener los rangos y validadores de una fuente trazable, preferentemente `hiscore.dat` de MAME.
3. Comprobar que todas las direcciones son accesibles por el adaptador; si pertenecen a otra RAM, ampliar el adaptador sin introducir nombres de juegos en el motor.
4. Añadir el perfil de máquina a `mame2mra.toml`.
5. Generar un MRA con sufijo `(Hiscore)`, ROM índice 5 y NVRAM índice 6.
6. Ejecutar la prueba pequeña de elaboración.
7. Compilar el RBF solo cuando la prueba pequeña pase.
8. Probar en hardware: inicialización, récord, `Saving`, reinicio/cambio de núcleo y restauración.
9. Investigar `ignore_changes` únicamente si se observa un guardado falso reproducible.

Que un juego use JTFRAME no significa automáticamente que ya pueda guardar récords. JTFRAME es común a muchos núcleos, pero cada familia necesita exponer las memorias correctas y cada máquina necesita un perfil validado.

## 9. Atribución

La máquina de estados de hiscores fue adaptada de `rtl/hiscore.v` de [Arcade-Bagman_MiSTer](https://github.com/MiSTer-devel/Arcade-Bagman_MiSTer). Ese archivo procede de [Hiscores_MiSTer](https://github.com/JimmyStones/Hiscores_MiSTer), con copyright original de Alan Steremberg y Jim Gregory. Sus avisos y condiciones GPL se conservan en `jtframe_hiscore.v`.

Los rangos de 1942, Vulgus y Higemaru se transcribieron de `plugins/hiscore/hiscore.dat` de [MAME](https://github.com/mamedev/mame/blob/master/plugins/hiscore/hiscore.dat). Esa base acredita a Leezer en las entradas sin autor específico y declara su origen en el proyecto Unofficial Hiscore.dat alojado históricamente por MAMEWorld.

La integración del transporte JTFRAME, la interfaz de transacciones, el adaptador JT1942, el generador MRA, los perfiles y las pruebas fue realizada en 2026 por **J. M. Artés**, con asistencia de desarrollo de OpenAI Codex.

JTCORES y JTFRAME siguen siendo obra de Jotego y de sus colaboradores. Este fork es independiente y no constituye una versión oficial de Jotego. La corrección de Bagman parte igualmente del repositorio y de los autores existentes del núcleo; el parche local solo modifica el comportamiento descrito.

## 10. Licencia y distribución

El fork se distribuye bajo GPLv3, de acuerdo con JTCORES y Hiscores_MiSTer. Los archivos modificados deben conservar avisos y atribuciones. Todo RBF distribuido debe enlazarse con la revisión exacta de sus fuentes correspondientes.

No se incluyen ni deben distribuirse ROM de arcade. Los MRA describen cómo construir la imagen a partir de ROM que el usuario obtiene legítimamente.

## 11. Estado de los árboles de trabajo

No se han realizado `commit`, `push`, merge ni cambio de rama durante esta consolidación.

- JTFRAME: rama `feature/jtframe-hiscore`, con cambios y archivos nuevos aún sin confirmar.
- Bagman: rama `fix-high-score-initials`; existe además un `sys/pll_q19.qip` no versionado que debe revisarse antes de preparar una contribución.

Antes de publicar, se debe separar código fuente, pruebas reproducibles y binarios generados; revisar el diff completo; conservar las atribuciones; y evitar presentar los RBF como oficiales.
