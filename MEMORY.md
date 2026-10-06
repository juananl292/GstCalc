---
schemaVersion: 1
scope: workspace
updatedAt: "2026-10-05T19:09:25.064Z"
workspaceName: "GstCalc"
---

# Project Memory

## Project Overview
- Workspace para una app móvil Kakebo/Kakeibo de finanzas personales, multiplataforma Flutter, con enfoque minimalista, offline-first y sincronización con backend local en CasaOS.
- El producto combina ritual de planificación mensual, dashboard por 4 categorías Kakebo y cierre mensual reflexivo.

## Current State
- Se creó una base técnica funcional del proyecto.
- La verificación final reportó que no se detectaron errores sintácticos ni de runtime.
- Existe `DESIGN.md` como artefacto de diseño/sistema visual inicial y debe tratarse como fuente autorizada para decisiones de diseño.
- No había memoria previa ni archivos base antes de esta iteración.

## Artifacts
- `ARCHITECTURE.md`: arquitectura técnica, entidades principales, flujo offline-first y contratos REST.
- `DESIGN.md`: dirección visual y sistema de diseño inicial para la experiencia Kakebo.
- `backend/package.json`: dependencias y scripts del backend Node.js.
- `backend/server.js`: API REST Express/SQLite para meses, transacciones, recurrentes y sincronización.
- `pubspec.yaml`: configuración base del proyecto Flutter.
- `README.md`: guía inicial del proyecto.
- `lib/models/kakebo_category.dart`: enum/utilidades para Supervivencia, Opcional, Cultura y Extras.
- `lib/models/month_plan.dart`: modelo Dart para planificación mensual con serialización JSON.
- `lib/models/transaction.dart`: modelo Dart para transacciones con serialización JSON.
- `lib/views/home_grid_view.dart`: dashboard principal en cuadrante de 4 tarjetas.
- `lib/views/reflection_wizard_view.dart`: flujo guiado de cierre/reflexión mensual.
- `lib/services/sync_service.dart`: lógica de sincronización offline-first, reintentos y detección de CasaOS en LAN.

## Design Direction
- Estética minimalista, limpia y consciente, inspirada en un estilo zen/japonés.
- UI centrada en claridad financiera, baja fricción y rituales mensuales.
- Dashboard organizado en 4 tarjetas visuales correspondientes a categorías Kakebo.
- Soporte previsto para modo oscuro, animaciones suaves y feedback háptico al añadir gastos.

## User Feedback
- El usuario solicitó específicamente que se actuara como desarrollador senior full-stack Flutter/Dart y Node.js.
- Preferencia explícita por arquitectura offline-first con sincronización local contra CasaOS en `http://192.168.50.72`.
- Requiere entregables concretos en el workspace, no solo documentación.

## Decisions
- Frontend: Flutter/Dart.
- Backend: Node.js con Express y SQLite.
- Sincronización: bidireccional en segundo plano cuando el dispositivo esté en la red Wi‑Fi local.
- Entidades principales: `MonthPlan`, `Transaction`, `FixedExpense`, `MonthlyReflection`.
- Categorías Kakebo estables: Supervivencia, Opcional, Cultura, Extras/Imprevistos.
- CasaOS/local Debian actúa como respaldo centralizado, no como dependencia obligatoria para registrar datos.

## Open Questions
- Elegir definitivamente base local Flutter: Isar o SQLite/sqflite.
- Definir estrategia final de resolución de conflictos de sincronización para ediciones simultáneas.
- Definir autenticación/seguridad del backend local si se expone fuera de LAN.
- Completar implementación real de persistencia local en Flutter.
- Determinar si habrá múltiples usuarios/dispositivos o solo uso personal.

## Next Steps
- Crear o completar `App.jsx` no aplica; este workspace es document-first/código Flutter/Node.
- Instalar dependencias y ejecutar backend localmente.
- Integrar base de datos local real en Flutter.
- Conectar vistas Flutter con repositorios/servicios persistentes.
- Añadir tests unitarios para modelos, API y sincronización.
- Probar sincronización real contra CasaOS en `192.168.50.72`.

## Promotion Candidates For DESIGN.md
- Mantener como decisión estable el tono minimalista zen/japonés.
- Formalizar paleta por categoría Kakebo sin duplicar tablas aquí.
- Establecer patrones de componentes para tarjetas del dashboard, estados vacíos y wizard de reflexión.
- Definir guía de microinteracciones: animación suave y háptica al registrar transacciones.

## Recent History
- 2026-10-05: Se creó la estructura inicial completa del proyecto Kakebo.
- 2026-10-05: Se añadieron arquitectura, backend Express/SQLite, modelos Dart, vistas Flutter y servicio de sync.
- 2026-10-05: Se añadieron `README.md`, `pubspec.yaml` y `DESIGN.md`; verificación final sin errores detectados.