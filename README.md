# Mobile · Torneos de fútbol

La aplicación existente conserva Firebase Authentication y el oso de Rive.
Después del login muestra datos de football-tournament-management en lugar de
productos de Market. No se creó un proyecto nuevo ni se agregaron dependencias.

## Funcionalidades y arquitectura

- Consultar, buscar por nombre, crear y eliminar torneos.
- Consultar, registrar y eliminar equipos de un torneo y jugadores de un equipo.
- Consultar, programar y eliminar partidos entre equipos del mismo torneo.
- Carga, listas vacías, actualización manual, errores, reintentos y cierre de sesión.

El backend no ofrece PUT/PATCH, edición, marcadores o clasificación. Todas las
operaciones implementadas corresponden a rutas existentes. Eliminar un torneo
elimina sus equipos, jugadores y partidos; la interfaz exige confirmación.
Para eliminar equipos con partidos hay que eliminar primero sus partidos.

Antes, ProductsScreen hacía http.get a localhost:8090/products y leía JSON
dinámico. Ahora se reutiliza el paquete http con estas responsabilidades:

```text
lib/config/api_config.dart       URL por plataforma o --dart-define
lib/models/                     Tournament, Team, Player, TournamentMatch
lib/services/football_api.dart   HTTP, JSON UTF-8, timeout y errores
lib/screens/login_screen.dart   Firebase Auth y Rive existentes
lib/screens/tournaments_screen.dart → tournament_screen.dart → team_screen.dart
lib/widgets/                    Listas asíncronas y formularios reutilizables
```

Spring Boot usa Controller → Service → repositorios de dominio → adaptadores
→ Spring Data JPA/PostgreSQL. MapStruct transforma entidades JPA a modelos de
dominio que también sirven como DTO HTTP. No hay un paquete DTO separado ni
Spring Security en este proyecto. No se envían tokens Firebase a la API ni se
cambió la autenticación del backend.

## Contrato utilizado

Spring Boot usa el puerto predeterminado 8080: no existe server.port en la
configuración original. Las rutas de torneos no llevan el prefijo /api.

| Método | Ruta | Uso |
|---|---|---|
| GET, POST | `/tournaments` | Listar / crear torneos |
| GET | `/tournaments/search?name=...` | Buscar torneos |
| DELETE | `/tournaments/{id}` | Eliminar torneo |
| GET, POST | `/api/teams/tournament/{tournamentId}` | Consultar / registrar equipos |
| DELETE | `/api/teams/{id}` | Eliminar equipo |
| GET, POST | `/api/players/team/{teamId}` | Consultar / registrar jugadores |
| DELETE | `/api/players/{id}` | Eliminar jugador |
| GET, POST | `/api/matches/tournament/{tournamentId}` | Consultar / programar partidos |
| DELETE | `/api/matches/{id}` | Eliminar partido |

También existen consultas individuales, listados globales de equipos/jugadores/
partidos, búsqueda de torneos por temporada y búsqueda de partidos por equipo.
Se documentan en el README del backend y no hacen falta para esta navegación.

| Modelo | Propiedades JSON reales |
|---|---|
| Tournament | `tournamentId`, `name`, `season`, `matches` |
| Team | `teamId`, `name`, `city` (nullable), `tournamentId`, `players` |
| Player | `playerId`, `name`, `number`, `position`, `teamId` |
| TournamentMatch | `matchId`, `homeTeamId`, `homeTeamName`, `awayTeamId`, `awayTeamName`, `scheduledAt` |

Los listados son arrays sin envoltorio. Los POST envían solo campos editables:
nombre/temporada, nombre/ciudad, nombre/dorsal/posición o IDs de equipos/fecha.
Devuelven el objeto con HTTP 201. DELETE responde HTTP 204 sin cuerpo.
`scheduledAt` es LocalDateTime (por ejemplo `2026-11-20T18:30:00`), sin zona
horaria; se conserva la hora suministrada y no se convierte a UTC.

Las consultas filtradas responden 404 sin cuerpo con X-Response-Message cuando
no hay registros. Solo ese caso se transforma en lista vacía. Otros errores
HTTP se muestran, junto con errores de JSON/contrato, conexión y timeout de 15
segundos. No se reintentan automáticamente las escrituras para evitar duplicados.

## Ejecutar ambos proyectos en PowerShell

Requisitos: Flutter compatible con pubspec.yaml, Java 21, PostgreSQL y el archivo
local existente `lib/firebase_options.dart` (ignorado por Git). Se conserva la
variable firebaseOptions que ya utiliza main.dart. Firebase necesita el proveedor
Email/Password habilitado y un usuario válido. No publiques credenciales ni
sustituyas ese archivo por valores inventados.

### Terminal 1: Spring Boot

PostgreSQL debe escuchar en localhost:5432. Si la base aún no existe, créala
con tu usuario PostgreSQL:

```sql
CREATE DATABASE football_tournament_db;
```

```powershell
Set-Location C:\Users\marce\Repos\Front-end\football-tournament-management
$env:DB_USERNAME = 'postgres'
$env:DB_PASSWORD = 'TU_PASSWORD_REAL'
$env:SPRING_PROFILES_ACTIVE = 'dev'
.\mvnw.cmd spring-boot:run
```

La configuración existente usa
`jdbc:postgresql://localhost:5432/football_tournament_db` y las variables
DB_USERNAME/DB_PASSWORD, con fallback postgres/postgres. Hibernate usa
`ddl-auto=update`. Puedes definir SPRING_DATASOURCE_URL para otra base y
SERVER_PORT para otro puerto, ajustando también API_BASE_URL en Flutter.

### Terminal 2: Flutter Web

```powershell
Set-Location C:\Users\marce\Repos\Front-end\Mobile\login_rive_animation
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8080
```

El perfil dev permite exclusivamente http://localhost:3000 y
http://127.0.0.1:3000. Si usas otro origen, define en la terminal del backend:

```powershell
$env:CORS_ALLOWED_ORIGINS = 'http://localhost:4200,http://192.168.1.50:3000'
```

Reinicia Spring Boot. Se permiten GET/POST/DELETE/OPTIONS con JSON y se expone
X-Response-Message. No se habilitan credenciales ni comodines. Fuera de dev,
esta configuración CORS está inactiva.

### Android Emulator

```powershell
flutter devices
flutter run -d ID_DEL_EMULADOR --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

10.0.2.2:8080 también es el valor automático para Android. Se conserva INTERNET
y se habilita HTTP local en debug/profile. En release utiliza un backend HTTPS.
Se corrigió el atributo HTTP mal colocado del manifiesto main.

### Windows y teléfono físico

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:8080
flutter run -d ID_DEL_DISPOSITIVO --dart-define=API_BASE_URL=http://192.168.1.50:8080
```

Sustituye 192.168.1.50 por la IP LAN del equipo con Spring Boot. Teléfono y equipo
deben compartir red y el firewall debe permitir el puerto 8080. CORS aplica al
navegador, no al cliente nativo. La URL automática Web/Windows es localhost.
Cambiar --dart-define requiere volver a ejecutar Flutter.
La compatibilidad Firebase de cada plataforma depende de tu configuración local
existente; esta integración no cambia los registros de aplicaciones Firebase.

### Comprobación manual

```powershell
Invoke-RestMethod http://localhost:8080/tournaments
```

Inicia sesión con tu usuario Firebase. Crea o abre un torneo, registra dos
equipos, abre uno para registrar jugadores y programa un encuentro desde
Partidos. Una base vacía debe mostrar el mensaje correspondiente.

## Pruebas

```powershell
flutter analyze
flutter test
flutter build web
```

Las pruebas normales usan MockClient para contratos, payloads, rutas, UTF-8,
timeout, errores, carga, listas vacías, reintentos, navegación, creación y
confirmación de eliminaciones. Sustituyen el test obsoleto del contador.

Con Spring Boot y una base de pruebas disponibles:

```powershell
flutter test test/live_api_test.dart --dart-define=RUN_LIVE_API_TESTS=true --dart-define=API_BASE_URL=http://localhost:8080
```

La prueba real crea registros con un identificador único y elimina exclusivamente
esos registros al terminar. Comprueba los cuatro recursos, relaciones anidadas,
ciudades nulas, búsquedas vacías y fechas locales con los modelos Dart reales.
Se omite en flutter test normal. No autentica usuarios en Firebase.

En el backend, configura las variables de la base de pruebas y ejecuta:

```powershell
.\mvnw.cmd -B -ntp test
.\mvnw.cmd -B -ntp -DskipTests package
```

Los tests originales cargan el contexto y necesitan PostgreSQL. Los nuevos tests
CORS verifican origen permitido, origen desconocido e inactividad sin perfil dev.

## Archivos

Rutas relativas a este proyecto Flutter:

| Estado | Archivos |
|---|---|
| Nuevos | `lib/config/api_config.dart`, `lib/services/football_api.dart` |
| Nuevos | `lib/models/tournament.dart`, `team.dart`, `player.dart`, `tournament_match.dart` |
| Nuevos | `lib/screens/tournaments_screen.dart`, `tournament_screen.dart`, `team_screen.dart` |
| Nuevos | `lib/widgets/resource_list.dart`, `action_form.dart` |
| Nuevos | `test/football_api_test.dart`, `football_screens_test.dart`, `live_api_test.dart` |
| Modificados | `lib/main.dart`, `lib/screens/login_screen.dart`, `README.md` |
| Modificados | `android/app/src/main/AndroidManifest.xml`, `android/app/src/debug/AndroidManifest.xml`, `android/app/src/profile/AndroidManifest.xml` |
| Eliminados | `lib/screens/products_screen.dart`, `test/widget_test.dart` |

En el backend se agregan:

- `src/main/java/com/footballtournament/management/web/config/DevelopmentCorsConfiguration.java`
- `src/main/resources/application-dev.properties`
- `src/test/java/com/footballtournament/management/web/config/DevelopmentCorsConfigurationTest.java`

También se modifica su README. No cambian controladores, servicios, entidades,
contratos ni repositorios. Se conservan las dependencias y versiones de ambos
proyectos, así como el archivo local Firebase y el recurso Rive.

## Resultado verificado · 18 de noviembre de 2026

- `flutter pub get`: correcto, sin cambios de dependencias.
- `flutter analyze`: sin incidencias.
- `flutter test`: 12 pruebas aprobadas; prueba HTTP real omitida por defecto.
- `flutter build web`: compilación JavaScript correcta. El dry run de WebAssembly
  informa incompatibilidades de la dependencia existente rive_common; no impide
  la compilación Web normal. No se actualizó Rive para conservar la animación.
- `mvnw.cmd -DskipTests package`: BUILD SUCCESS con Java 21.
- `mvnw.cmd -B -ntp test`: 4 pruebas Java aprobadas, incluidas las de CORS.
- Spring Boot arrancó en el puerto 8080. Su OpenAPI real confirmó las propiedades
  de los cuatro modelos. GET respondió 200, el preflight local 200 y el origen
  externo no configurado 403.
- `flutter test test/live_api_test.dart --dart-define=RUN_LIVE_API_TESTS=true --dart-define=API_BASE_URL=http://localhost:8080`:
  una prueba real aprobada, usando los modelos/servicio Dart contra Spring Boot
  y PostgreSQL. Se crearon, consultaron y eliminaron los cuatro tipos de recurso.
  Una consulta SQL final confirmó cero registros en las cuatro tablas de prueba.

La base local de localhost:5432 estaba activa, pero rechazó las credenciales
predeterminadas del proyecto. Las pruebas se ejecutaron con PostgreSQL 18 en una
instancia aislada, ligada a 127.0.0.1:55432, con datos bajo target (ignorado por
Git). Los procesos temporales Spring Boot/PostgreSQL se detuvieron al terminar.
No se modificó la base original. Debes configurar DB_PASSWORD con la
contraseña correcta para usar tu base habitual. No se ejecutó un login real de
Firebase ni una sesión en Android/Windows; se preservó su implementación y se
verificó la compilación Web junto con las nuevas pantallas.

## Propuestas de commit

```text
feat(mobile): integrate football tournaments teams players and matches
fix(android): correct manifest and allow local HTTP in development
test(mobile): cover football API contracts and resource navigation
feat(api): allow configured Flutter web origins in development
docs: document Flutter and Spring Boot integration setup
```
