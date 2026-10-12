# Jota Parasite

Aplicación móvil personal de productividad gamificada, organizada por espacios de trabajo y acompañada por una mascota sarcástica. La interfaz usa Flutter y Material 3; la integración con Supabase se incorporará en una etapa posterior.

## Estado

Desarrollo por etapas. Actualmente está implementada la **Etapa 1**:

- Design system oscuro con gradiente ciruela, acentos verde lima y superficies claras.
- `MascotMood` con los estados `neutral`, `judging`, `angry`, `smirking` y `proud`.
- `RoastMascotCard`, con diálogo contextual e interacción para cambiar el roast.
- Pantalla de vista previa en `lib/main.dart`.

## Requisitos

- Flutter SDK compatible con Dart 3.3 o posterior.
- Para ejecutar en Android, iOS o web, las carpetas de plataforma correspondientes deben estar generadas.

Este repositorio contiene actualmente el código Dart base; todavía no incluye el scaffold de Android/iOS/web. Para generarlo desde la raíz del proyecto, ejecuta:

```sh
flutter create --platforms=android,ios,web .
```

Después:

```sh
flutter pub get
flutter run
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
  theme/app_theme.dart
  widgets/roast_mascot_card.dart
assets/mascot/
```

## Configuración y secretos

No incluyas claves privadas, credenciales de servicio ni archivos `.env` reales en el repositorio. El `.gitignore` excluye archivos locales de entorno y credenciales de firma. Cuando se añada Supabase, usa variables de entorno para los valores locales y publica únicamente una plantilla sin secretos (por ejemplo, `.env.example`). Las claves públicas destinadas al cliente no sustituyen las políticas RLS.

## Licencia

Pendiente de definir. Un repositorio público de GitHub sin archivo de licencia no concede permisos explícitos de reutilización; añade una licencia cuando decidas cómo quieres compartir el proyecto.
