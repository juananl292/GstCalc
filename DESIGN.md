---
version: alpha
name: Kakebo App Design System
---

## Overview

Sistema visual para una app Kakebo minimalista, serena y consciente. La interfaz debe sentirse como un ritual financiero mensual: clara, silenciosa y enfocada en decisiones pequeñas.

## colors

- `rice`: #F7F1E8 — fondo claro principal.
- `ink`: #26231F — texto principal cálido.
- `mutedInk`: #756E64 — texto secundario.
- `paper`: #FFFDF8 — superficies elevadas.
- `line`: #E4DACB — bordes suaves.
- `matcha`: #6E8B63 — Supervivencia.
- `kintsugi`: #C59B42 — Opcional.
- `indigo`: #5B6F95 — Cultura.
- `ume`: #B95B5B — Extras.
- `night`: #1E211D — fondo oscuro.
- `nightPaper`: #292B25 — superficie oscura.

## typography

- Usar tipografía del sistema Flutter: San Francisco / Roboto.
- Títulos: peso 600, tracking sutil negativo.
- Cuerpo: peso 400, altura de línea amplia.
- Números financieros: peso 600, tabular figures cuando sea posible.

## rounded

- Tarjetas: 24.
- Botones principales: 18.
- Chips y campos pequeños: 999.

## spacing

- Escala base: 4, 8, 12, 16, 20, 24, 32.
- Pantallas móviles: padding horizontal 20.
- Separación de secciones: 24–32.

## components

### CategoryCard

Tarjeta de cuadrante con acento lateral, total gastado, recomendación restante y botón rápido `+`.

### MonthBudgetHeader

Resumen del mes con presupuesto disponible, ahorro objetivo y progreso.

### ReflectionWizard

Flujo paso a paso con una pregunta por pantalla, controles grandes y lenguaje reflexivo.

### SyncStatus

Indicador discreto: offline, sincronizando, sincronizado o error recuperable.
