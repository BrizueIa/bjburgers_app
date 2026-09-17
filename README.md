# B&J Burgers · Operación Android

Aplicación para recibir pedidos copiados de WhatsApp, confirmarlos, avanzar sus
estados y emitir un código de ruleta al entregarlos.

No usa Supabase, almacenamiento local de comandas ni acceso directo a PostgreSQL.
La API B&J es la fuente de verdad.

## Desarrollo

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=https://bj-40-233-29-16.sslip.io/api/v1
```

En el primer arranque, crea un dispositivo en el panel B&J y captura su ID y
código temporal. La credencial resultante se almacena únicamente mediante
Android Keystore a través de `flutter_secure_storage`.

## Verificación

```powershell
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=https://bj-40-233-29-16.sslip.io/api/v1
```
