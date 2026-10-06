# Kakebo App

Base técnica para una app Flutter offline-first de finanzas personales basada en el método Kakebo, con sincronización local hacia CasaOS.

## Contenido

- `ARCHITECTURE.md`: modelo de datos, flujo offline-first y contratos REST.
- `backend/server.js`: API Express + SQLite para CasaOS.
- `lib/models`: modelos Dart serializables.
- `lib/views`: vistas principales de cuadrante y reflexión mensual.
- `lib/services/sync_service.dart`: sincronización bidireccional con reintentos.

## Backend CasaOS

```bash
cd backend
npm install
npm start
```

Servidor por defecto: `http://0.0.0.0:8787`.

## Flutter

```bash
flutter pub get
```

Integra las vistas en tu `MaterialApp` y conecta `SyncService` a tus repositorios locales `sqflite` o Isar.
