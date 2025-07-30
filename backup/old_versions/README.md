# Versiones Antiguas de Process Manager

Este directorio contiene versiones anteriores de Process Manager que ya no se utilizan.

## Archivos movidos:

1. **ProcessManagerModular.ps1**
   - Versión original modular básica
   - Primera implementación con estructura modular

2. **ProcessManagerModular_Enhanced.ps1**
   - Primera versión mejorada
   - Agregó: búsqueda, exportar reportes, modo oscuro, atajos de teclado

3. **ProcessManagerModular_Enhanced_v2.ps1**
   - Segunda versión mejorada
   - Agregó: contadores en tiempo real, vista previa de impacto, sistema de favoritos, notificaciones

## Versión Actual:

La versión actualmente en uso es: **ProcessManagerModular_Enhanced_v2_Optimized.ps1**
- Incluye todas las características de v2
- Optimizada con sistema de debounce para prevenir cuelgues
- Mejor rendimiento durante scroll y actualizaciones

## Fecha de archivo:
$(Get-Date -Format "dd/MM/yyyy HH:mm:ss")