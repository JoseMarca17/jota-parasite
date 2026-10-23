# Jota Parasite

Aplicación móvil personal de productividad gamificada, organizada por espacios de trabajo y acompañada por una mascota sarcástica. La interfaz usa Flutter y Material 3, con Supabase como backend.

## Estado

Desarrollo por etapas. Actualmente están implementadas las **Etapas 1–5**:

- Design system oscuro con gradiente ciruela, acentos verde lima y superficies claras.
- `MascotMood` con los estados `neutral`, `judging`, `angry`, `smirking` y `proud`.
- `RoastMascotCard`, con diálogo contextual e interacción para cambiar el roast.
- Pantalla de vista previa en `lib/main.dart`.
- Inicialización de Supabase al arrancar, con posibilidad de sobrescribir la configuración mediante `--dart-define`.
- Migración SQL para `profiles_workspaces` y `tasks`, con RLS por usuario.
- Modelos Dart serializables y contratos de repositorio.
- Registro, inicio y cierre de sesión por email/contraseña.
- Repositorios Supabase concretos para workspaces y tareas.
- Dashboard con selector de espacios, métricas persistentes, mascota reactiva y tareas del día.
- +100 XP por tarea, persistida una sola vez por workspace mediante trigger de base de datos.
- Rachas por días de actividad, historial semanal, días libres configurables y comodines mensuales.
- Calendario mensual con navegación por fechas, filtro por workspace, tareas del día y alta/completado de tareas.

## Requisitos

- Flutter 3.44 o posterior (Dart 3.12 o posterior).
- El scaffold Android/iOS/web ya está generado en el repositorio.
- En Supabase Auth, habilita el proveedor Email para registro y contraseña.

Después:

```sh
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

La configuración de desarrollo está en `lib/core/config/supabase_config.dart`; puedes sustituirla en tiempo de compilación con `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`. Aplica en orden las migraciones de `supabase/migrations/`: `20261012020000_persist_workspace_xp.sql` incorpora XP por workspace y el RPC de postergación; `20261012030000_streaks_freeze_and_wildcards.sql` añade el historial, la reposición mensual de comodines y los RPC de rachas. Usa únicamente una clave pública/publishable del cliente; nunca incluyas la `service_role` key en Flutter.

Para verificar localmente:

```sh
flutter analyze
flutter test
```

## Assets de la mascota

Coloca las ilustraciones PNG en `assets/mascot/` con estos nombres exactos:

```text
neutral.png
judging.png
angry.png
smirking.png
proud.png
```

La tarjeta muestra una cara de respaldo mientras falten las imágenes. Antes de publicar assets, confirma que tienes derechos para redistribuirlos.

## Estructura actual

```text
lib/
  main.dart
  core/config/supabase_config.dart
  data/models/
  data/repositories/
  domain/streak/
  features/auth/
  features/calendar/
  features/home/
  features/streaks/
  theme/app_theme.dart
  widgets/roast_mascot_card.dart
assets/mascot/
supabase/migrations/
```

## Configuración y secretos

No incluyas claves privadas, credenciales de servicio ni archivos `.env` reales en el repositorio. El `.gitignore` excluye archivos locales de entorno y credenciales de firma. La URL y la clave publishable/anon son configuración de cliente; la seguridad de los datos depende de RLS. Nunca distribuyas la `service_role` key.

## Licencia

Pendiente de definir. Un repositorio público de GitHub sin archivo de licencia no concede permisos explícitos de reutilización; añade una licencia cuando decidas cómo quieres compartir el proyecto.
