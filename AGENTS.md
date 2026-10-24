# Jota Parasite — checkpoint de continuidad

## Reglas del proyecto

- Flutter/Material 3, interfaz y mensajes en español; conservar el tema ciruela/neón y el tono sarcástico.
- El usuario trabaja por etapas. Etapas 1–4 están aprobadas; Etapa 5 (calendario) está en desarrollo. No iniciar una etapa posterior sin aprobación expresa de la etapa actual.
- Tras cambios Dart, ejecutar `flutter analyze` y `flutter test`; formatear los archivos Dart modificados.
- No desplegar cambios en Supabase remoto ni ejecutar migraciones en producción sin autorización explícita.
- En Flutter solo usar una publishable/anon key. Nunca incluir una `service_role` key en el cliente, Git o este archivo.
- Mantener ignorados artefactos locales (`.dart_tool/`, `build/`, `android/local.properties`).

## Estado actual

**Etapa 4 (Rachas & Comodines) está aprobada por el usuario.** Sus migraciones están aplicadas y verificadas en Supabase. **Etapa 5 (Calendario) está implementada y publicada**; falta completar su prueba manual en el navegador con la sesión autenticada.

### Implementado

- Supabase inicializado en `lib/main.dart` con `publishableKey`, desde `lib/core/config/supabase_config.dart`.
- Autenticación email/contraseña (registro, login, sesión persistente, confirmación de correo y logout) en `lib/features/auth/`.
- Repositorios CRUD concretos: `SupabaseProfileRepository` y `SupabaseTaskRepository`.
- Dashboard en `lib/features/home/home_dashboard_page.dart`: selector de workspace/Todos, tareas vencidas y de hoy, alta/completar/postergar/eliminar tareas, XP, comodines, racha y mascota reactiva.
- XP persistente por workspace: +100 por tarea completada una sola vez, acreditada por trigger SQL.
- Módulo Rachas & Comodines en `lib/features/streaks/streaks_page.dart`, accesible desde el botón de fuego del Dashboard.
- `StreakCalculator` en `lib/domain/streak/streak_calculator.dart`: cálculo de racha efectiva, días congelados y elegibilidad de un comodín.
- Historial semanal en `workspace_streak_days`; el selector de días libres congela/descongela sábado y domingo.
- La finalización de tareas pasa por RPC para actualizar tarea, XP y racha de forma transaccional.
- Calendario mensual en `lib/features/calendar/calendar_page.dart`: navegación de meses, indicadores por día, filtro de workspace, agenda del día y alta/finalización de tareas.
- Barra inferior persistente con navegación entre Inicio, Calendario y Rachas en `lib/widgets/app_navigation_bar.dart`.
- Flutter platforms (Android, iOS, web, además de escritorio) ya fueron generadas con `flutter create .`.

### Decisiones confirmadas por el usuario

- Autenticación mínima: email y contraseña.
- XP por workspace: +100 XP por tarea, solo una vez aunque se desmarque y se complete otra vez.
- Comodines por workspace, recarga mensual a 3; un comodín cubre como máximo un día laborable perdido.
- El usuario confirmó que las tablas base `profiles_workspaces` y `tasks` existen y tienen RLS activo; Developer Mode de Windows está habilitado.

## Migraciones Supabase

Archivos locales, en orden:

1. `supabase/migrations/20261012000000_create_profiles_workspaces_and_tasks.sql` — tablas base/RLS. El usuario ya confirmó que el esquema base está en Supabase.
2. `supabase/migrations/20261012020000_persist_workspace_xp.sql` — `xp_total`, trigger de XP, RPC `postpone_task` y permisos de columnas.
3. `supabase/migrations/20261012030000_streaks_freeze_and_wildcards.sql` — tabla de historial, recarga mensual y RPCs de racha.

Las migraciones 2 y 3 ya están aplicadas en el proyecto Supabase `jota-parasite` (`fcuvumxncftociyeqjgf`):

- `20261012020000_persist_workspace_xp` — versión registrada remotamente `20261023225218`.
- `20261012030000_streaks_freeze_and_wildcards` — versión registrada remotamente `20261023225336`.

La migración base 1 no figura en el historial remoto, aunque las tablas base ya existían antes de estos cambios. **No ejecutar `supabase db push` sin reconciliar primero esa línea base:** podría aplicar la migración 1 después y volver a conceder permisos de tabla amplios. La API de gestión de Supabase asignó versiones remotas distintas a los prefijos locales; sincronizar ese historial antes de usar la CLI. Supabase CLI no está instalado en este entorno.

La inspección inicial encontró permisos directos amplios para `anon` y `authenticated`; la migración 2 los revocó y concedió a `authenticated` solo los permisos de columnas necesarios. La migración 3 añadió el índice único compuesto requerido y la FK workspace/usuario que faltaban en el esquema remoto. Ahora RLS está activa en las tres tablas; `anon` no tiene permisos de tabla y XP/racha no son actualizables directamente por `authenticated`.

El backfill del historial de tareas existentes usa la fecha UTC como aproximación; los eventos nuevos usan la fecha local enviada por el cliente. Al aplicar las migraciones, el proyecto tenía 0 workspaces, 0 tareas y 0 días de racha; no había datos que backfillear. La verificación de operaciones con una cuenta autenticada sigue pendiente.

## Verificaciones conocidas

- `flutter analyze`: **sin issues** en la última verificación.
- `flutter test`: **15 pruebas pasan** (modelos, utilidades y widgets del calendario con repositorios falsos, navegación, cálculo de rachas y mascota).
- `dart format`: aplicado a los archivos Dart modificados; verificar con `dart format --output=none --set-exit-if-changed ...` antes de continuar.
- `flutter build web`: **completado correctamente** en 78 s tras añadir pruebas del calendario; solo avisos no bloqueantes de CupertinoIcons/WASM.
- `flutter build apk --debug` no se pudo completar: este entorno no tiene Android SDK. El scaffold Android sí existe.
- Migraciones 2 y 3: aplicadas y verificadas en Supabase; funciones RPC, trigger, FK, RLS y grants confirmados.
- El build web anterior emitió un aviso no bloqueante de fuentes CupertinoIcons/WASM.

## Siguiente trabajo

1. Probar el calendario y la navegación inferior con sesión real: seleccionar las tres secciones, navegar meses, seleccionar día, filtrar workspaces, crear tarea y completar tarea.
2. Reconciliar el historial remoto con los prefijos de migración locales antes de usar `supabase db push`; la migración base 1 no está registrada remotamente y las versiones de 2/3 fueron generadas por la API.
3. Para validar Android, instalar/configurar Android SDK y ejecutar `flutter build apk --debug`.

## Continuar desde otro dispositivo

Antes de compartir cambios, revisar `git status --short`; incluir el código, las migraciones, `AGENTS.md`, README, `pubspec.yaml`/`pubspec.lock` y el scaffold de plataformas que se quiera conservar. No incluir `android/local.properties`, archivos IDE `*.iml`, claves privadas ni `service_role`. En otro dispositivo, clonar/pull, leer primero este archivo y ejecutar `flutter pub get`, `flutter analyze` y `flutter test`.
