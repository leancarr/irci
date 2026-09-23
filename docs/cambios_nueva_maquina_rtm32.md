# Actualización: Cambios en la Nueva Versión de RTM32

Con la reciente actualización de la máquina (que trajo modificaciones en los binarios y en el manual `rtm32.pdf`), detectamos cambios arquitectónicos críticos que afectan tanto al emulador como a nuestro script ensamblador. 

Aquí documentamos estos cambios para mantener el historial de la evolución de la arquitectura STX4:

## 1. Reorganización Total del Banco de Registros

La distribución y convención de los 32 registros de propósito general fue reasignada masivamente. Esto es vital, ya que si compilamos código con la asignación vieja, la máquina ejecutará operaciones sobre registros equivocados.

**Cambios principales:**
* **`$ra` (Return Address):** Pasó de ser el registro `$31` al registro **`$1`**.
* **`$at` (Assembler Temporary):** Pasó de ser el registro `$1` al registro **`$31`**.
* **Registros Temporales (`$t0` - `$t5`):** Ahora ocupan del **`$2` al `$7`** (antes estaban a partir del `$10`).
* **Registros de Kernel (`$k0`, `$k1`):** Pasaron del `$2, $3` al **`$8, $9`**.
* **Argumentos (`$a0` - `$a3`):** Pasaron al rango **`$10` al `$13`**.

Nuestro script `assembler.py` ya fue actualizado con este nuevo mapeo.

## 2. Cambio en el Direccionamiento: Código Relocable (Instrucciones J)

El profesor había adelantado: *"vamos a eliminar un modo de direccionamiento completo. Esto es porque el código va a ser totalmente relocable"*.

**¿Qué significa esto?**
Se eliminó el direccionamiento **Pseudo-Directo**. Las instrucciones de salto incondicional (`J` y `JAL`), que antes requerían una dirección de memoria "absoluta", ahora pasaron a utilizar un direccionamiento **PC-Relativo** (Program Counter Relative), de forma idéntica a las instrucciones de bifurcación condicional (`BEQ`, `BNE`).

* **Antes:** `J etiqueta` reemplazaba parte del Program Counter con la dirección exacta en memoria. Si el programa se movía a otro lado de la RAM, el salto se rompía porque seguía apuntando a la dirección original.
* **Ahora:** `J etiqueta` calcula la "distancia" (offset) entre la instrucción actual y el destino. Si mueves el programa completo a otro lado de la RAM, la distancia entre las instrucciones se mantiene constante, por lo que el salto sigue funcionando perfectamente (Código 100% relocable).

Nuestro ensamblador ya fue actualizado para calcular offsets relativos cuando ensambla instrucciones `J` y `JAL`.

*(Nota: Aunque la máquina ya soporta esto, en la última revisión del PDF la fórmula del formato J en el texto aún explicaba el método viejo, lo cual es un detalle a tener en cuenta por si genera confusión al leerlo).*
