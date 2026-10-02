# Monitorización

App de macOS para vigilar la temperatura y el esfuerzo del Mac, pensada para
registrar esfuerzos del dispositivo en local.

Abrir `Monitorizacion/Monitorizacion.xcodeproj` y ejecutar.

## Secciones

- **Resumen** — temperatura del chip, CPU, GPU, memoria, consumo y disco; uso
  por cluster y por núcleo; tasas de red y disco.
- **Histórico** — gráficas de los últimos 1 a 30 minutos y máximos de la sesión,
  incluido el tiempo que el sistema ha pasado limitando el rendimiento.
  "Reiniciar sesión" pone los contadores a cero antes de empezar a jugar.
- **Sensores** — los sensores de temperatura agrupados por tipo.
- **Procesos** — qué está consumiendo CPU y memoria.
- **Equipo** — ficha del Mac, batería y umbral del aviso de temperatura.

La temperatura y el uso de CPU también se ven en la barra de menús con la
ventana cerrada.

## De dónde sale cada dato

| Dato | Origen |
|---|---|
| Temperatura (°C) | Sensores HID del SoC (`IOHIDEventSystemClient`) |
| CPU total, por núcleo y por cluster | `host_processor_info` |
| Nombres de los clusters | `hw.perflevelN.name` |
| GPU y memoria del GPU | `IOAccelerator` → `PerformanceStatistics`, Metal |
| Memoria y swap | `host_statistics64`, `vm.swapusage` |
| Presión de memoria | `kern.memorystatus_vm_pressure_level` |
| Consumo (W), batería, ciclos, salud | `AppleSmartBattery` |
| Presión térmica | `ProcessInfo.thermalState` |
| Disco | `IOBlockStorageDriver`, `URLResourceValues` |
| Red | `getifaddrs` |
| Procesos | `libproc` |

## Limitaciones

- **El sandbox está desactivado** (`ENABLE_APP_SANDBOX = NO`). Es obligatorio:
  el sandbox bloquea IOKit y sin él no hay temperatura, GPU ni batería. Por eso
  la app no es publicable en la Mac App Store.
- **No hay revoluciones de ventilador.** El SMC de los Mac con Apple Silicon
  recientes rechaza la lectura de las claves de ventilador, incluida `F_Num`.
  El modelo de datos deja el hueco preparado (`ThermalMetrics.fans`).
- **El consumo solo se mide con la batería en uso.** Se calcula como tensión por
  corriente de la batería; enchufado, la corriente refleja la carga y no el
  gasto del sistema, así que no se muestra ningún vatiaje.
- **No hay desglose de vatios por CPU, GPU y Neural Engine.** Esos canales
  (`Energy Model` de IOReport) devuelven ceros a los procesos sin privilegios de
  administrador, que es el motivo por el que `powermetrics` se ejecuta con sudo.
- Las temperaturas se leen con funciones de IOKit que no son públicas, así que
  se resuelven en caliente con `dlsym`: si Apple las retira, la app sigue
  funcionando sin temperaturas en lugar de dejar de compilar.
- Solo se listan los procesos del usuario; los del sistema requieren permisos.
