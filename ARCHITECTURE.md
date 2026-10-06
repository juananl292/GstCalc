# Kakebo App — Arquitectura técnica

Aplicación móvil Flutter offline-first para gestión financiera personal con método Kakebo y sincronización local contra un servidor CasaOS.

## Objetivos

- Registrar planificación mensual, gastos fijos, transacciones y reflexión de cierre.
- Funcionar al 100% sin internet usando base de datos local en el dispositivo.
- Sincronizar automáticamente con un backend local CasaOS cuando el móvil detecta la red doméstica.
- Mantener contratos simples, auditables y preparados para resolución de conflictos.

## Stack recomendado

### Móvil

- Flutter 3.x / Dart.
- Persistencia local: SQLite mediante `sqflite` o Isar. Los modelos incluidos son agnósticos y serializan a JSON/mapas.
- Estado sugerido: Riverpod, Bloc o ValueNotifier por feature.
- Sincronización: servicio en background con reintentos exponenciales.

### Backend CasaOS

- Node.js 20+.
- Express.
- SQLite como almacenamiento local persistente.
- Servicio accesible en LAN: `http://192.168.50.72:8787`.
- Volumen Docker sugerido: `/DATA/AppData/kakebo/data:/app/data`.

## Modelo de datos

Todas las entidades sincronizables incluyen:

- `id`: UUID estable generado en cliente.
- `createdAt`: ISO-8601 UTC.
- `updatedAt`: ISO-8601 UTC.
- `deletedAt`: ISO-8601 UTC o `null` para soft delete.
- `syncVersion`: entero incremental asignado por servidor.
- `deviceId`: identificador anónimo del dispositivo que originó el cambio.

### MonthPlan

Representa el ritual de inicio de mes.

| Campo | Tipo | Descripción |
|---|---:|---|
| id | string | UUID |
| month | string | Mes en formato `YYYY-MM` |
| expectedIncome | number | Ingresos esperados |
| savingsGoal | number | Objetivo de ahorro |
| notes | string? | Intención del mes |
| createdAt / updatedAt / deletedAt | string? | Auditoría |
| syncVersion | number | Versión servidor |
| deviceId | string | Origen |

El presupuesto disponible se calcula como:

```text
expectedIncome - sum(fixedExpenses.amount) - savingsGoal
```

### FixedExpense

Gasto fijo recurrente configurado para deducción automática.

| Campo | Tipo | Descripción |
|---|---:|---|
| id | string | UUID |
| monthPlanId | string | Plan mensual relacionado |
| name | string | Ej. Alquiler, electricidad |
| amount | number | Importe |
| category | enum | Categoría Kakebo |
| dueDay | number? | Día de cargo estimado |
| isActive | boolean | Activo para el mes |
| timestamps / sync | varios | Campos comunes |

### Transaction

Registro de gasto diario.

| Campo | Tipo | Descripción |
|---|---:|---|
| id | string | UUID |
| monthPlanId | string | Plan mensual |
| category | enum | `survival`, `optional`, `culture`, `extra` |
| amount | number | Importe positivo |
| title | string | Descripción corta |
| note | string? | Detalle opcional |
| occurredAt | string | Fecha real del gasto |
| paymentMethod | string? | Efectivo, tarjeta, transferencia |
| timestamps / sync | varios | Campos comunes |

### MonthlyReflection

Ritual guiado de cierre mensual.

| Campo | Tipo | Descripción |
|---|---:|---|
| id | string | UUID |
| monthPlanId | string | Plan mensual |
| actualSavings | number | Ahorro conseguido |
| reachedGoal | boolean | Si alcanzó el objetivo |
| overspentCategories | string[] | Categorías excedidas |
| nextMonthActions | string | Acciones concretas |
| completedAt | string | Fecha de cierre |
| timestamps / sync | varios | Campos comunes |

## Categorías Kakebo

- `survival`: Supervivencia — comida, salud, transporte, vivienda.
- `optional`: Opcional — ocio, restaurantes, compras no esenciales.
- `culture`: Cultura — libros, cine, cursos, museos.
- `extra`: Extras / imprevistos — reparaciones, regalos, emergencias.

## Flujo offline-first

1. La app genera IDs localmente y escribe toda mutación en SQLite/Isar de forma inmediata.
2. Cada cambio marca la entidad como pendiente mediante `updatedAt` y/o tabla local de outbox.
3. `SyncService` detecta conectividad LAN hacia CasaOS.
4. El cliente envía cambios desde `lastPulledVersion` a `/api/sync/push` o `/api/sync`.
5. El servidor aplica upserts con soft delete y asigna `syncVersion` creciente.
6. El cliente solicita cambios remotos posteriores a su última versión.
7. La app actualiza entidades locales y persiste el nuevo cursor.

## Resolución de conflictos

Política inicial: last-write-wins por `updatedAt`, con protección de soft delete.

- Si una entidad remota tiene `syncVersion` mayor y `updatedAt` posterior, gana remoto.
- Si local tiene `updatedAt` posterior y no fue confirmado, se reintenta push.
- `deletedAt` nunca elimina físicamente durante sync; permite convergencia entre dispositivos.

## API REST

Base URL LAN: `http://192.168.50.72:8787`.

### Health

```http
GET /health
```

Respuesta:

```json
{ "ok": true, "service": "kakebo-casaos", "version": "1.0.0" }
```

### MonthPlan

```http
GET /api/kakebo/month?month=2026-01
POST /api/kakebo/month
PUT /api/kakebo/month/:id
DELETE /api/kakebo/month/:id
```

### Transactions

```http
GET /api/kakebo/transactions?monthPlanId=...
POST /api/kakebo/transactions
PUT /api/kakebo/transactions/:id
DELETE /api/kakebo/transactions/:id
```

### Fixed recurring expenses

```http
GET /api/kakebo/recurring?monthPlanId=...
POST /api/kakebo/recurring
PUT /api/kakebo/recurring/:id
DELETE /api/kakebo/recurring/:id
```

### Sync bidireccional

```http
POST /api/sync
Content-Type: application/json
```

Solicitud:

```json
{
  "deviceId": "ios-9f3c",
  "lastPulledVersion": 42,
  "changes": {
    "monthPlans": [],
    "transactions": [],
    "fixedExpenses": [],
    "monthlyReflections": []
  }
}
```

Respuesta:

```json
{
  "serverVersion": 49,
  "applied": {
    "monthPlans": 1,
    "transactions": 4,
    "fixedExpenses": 0,
    "monthlyReflections": 1
  },
  "changes": {
    "monthPlans": [],
    "transactions": [],
    "fixedExpenses": [],
    "monthlyReflections": []
  }
}
```

## Estructura del workspace

```text
ARCHITECTURE.md
DESIGN.md
backend/
  package.json
  server.js
lib/
  models/
    kakebo_category.dart
    month_plan.dart
    transaction.dart
  services/
    sync_service.dart
  views/
    home_grid_view.dart
    reflection_wizard_view.dart
```

## Próximos pasos recomendados

1. Añadir repositorios locales Flutter para SQLite/Isar.
2. Incorporar autenticación local opcional por PIN/biometría.
3. Crear Dockerfile y manifest CasaOS.
4. Añadir tests de sync para conflictos, deletes y reintentos.
