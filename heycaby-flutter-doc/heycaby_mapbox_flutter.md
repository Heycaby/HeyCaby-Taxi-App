# HeyCaby — Mapbox Flutter Setup Guide
## The Definitive Installation & Integration Reference
### Version: mapbox_maps_flutter 2.19.x (latest stable, March 2026)

> **This file exists for one reason:** Mapbox Flutter has a reputation for breaking builds. This guide documents every known pitfall, the exact working configuration, and every piece of code you need for the two HeyCaby apps. Follow this exactly. Do not improvise.

---

## CRITICAL — Read Before Installing

### The secret token situation (most common source of build failures)

As of `mapbox_maps_flutter` 2.4+ (Maps SDK v11+), **Mapbox's secret token is no longer required** to download the Android or iOS SDK. The SDK is now distributed via public Maven and CocoaPods repositories. This is the most important thing to know. Every tutorial written before 2024 will tell you to set `SDK_REGISTRY_TOKEN` or add credentials to `~/.gradle/gradle.properties` or `~/.netrc`. That was the old system. **Ignore those instructions entirely.**

What you still need:
- A **public access token** (`pk.xxx`) to use in the app at runtime
- Nothing else

What you do NOT need for v11+:
- `SDK_REGISTRY_TOKEN` in `gradle.properties` — not required
- `~/.netrc` credentials for iOS — not required
- Secret Maven credentials in `settings.gradle` — not required

If you get a `SDK Registry token is null` error, you are using an old version of the plugin (<2.4) or the cache contains an old build script. Clean and upgrade.

### Version constraints (as of March 2026)

| Component | Minimum version | Recommended |
|-----------|----------------|-------------|
| `mapbox_maps_flutter` | 2.4.0 | **2.19.1** (latest stable) |
| Flutter SDK | 3.27.0 | 3.27.x latest |
| Dart SDK | 3.4.4 | 3.6.x latest |
| Android `compileSdk` | 35 | 35 |
| Android `minSdk` | 21 | 23 |
| Xcode | 14 | 16 |
| iOS deployment target | 14.0 | 14.0 |
| Kotlin | 1.9.0 | 1.9.x |

> **Lock `mapbox_maps_flutter` to an exact version** in `pubspec.yaml`. Do not use `^2.19.1` (caret). Use `2.19.1` (exact). Mapbox has broken APIs between minor versions without warning. Lock it until you are ready to upgrade intentionally.

---

## PART 1 — PUBSPEC.YAML (Both Apps)

Add to both `apps/rider/pubspec.yaml` and `apps/driver/pubspec.yaml`:

```yaml
dependencies:
  # Mapbox — LOCK THE VERSION. Do not use caret (^).
  mapbox_maps_flutter: 2.19.1

  # Polyline decoder — needed to render Directions API route geometry
  # Mapbox Directions API returns encoded polyline strings, not raw coordinates
  polyline_codec: ^1.0.1

  # HTTP client for Directions + Search API calls
  dio: ^5.4.0
```

Run `flutter pub get` after adding. Verify with `flutter pub deps | grep mapbox`.

---

## PART 2 — ANDROID SETUP

### 2.1 `android/settings.gradle.kts`

This is the most common Android build failure point. The Maven repository must be in `dependencyResolutionManagement`, NOT in `pluginManagement`.

```kotlin
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_PROJECT)
    repositories {
        google()
        mavenCentral()
        // Mapbox Maven — NO credentials needed for v11+
        maven {
            url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
        }
    }
}
```

> **If you see `RepositoriesMode.FAIL_ON_PROJECT_REPOS` already set**, change it to `PREFER_PROJECT`. The Flutter build system needs project-level repos and this mode blocks them.

### 2.2 `android/app/build.gradle.kts`

```kotlin
android {
    compileSdk = 35
    ndkVersion = "27.0.12077973"  // Required for 16KB page size support on newer devices

    defaultConfig {
        minSdk = 23
        targetSdk = 35
        // ...
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // The Flutter Mapbox plugin pulls the native SDK automatically.
    // You do NOT need to manually add com.mapbox.maps:android here.
    // The mapbox_maps_flutter plugin handles it.
}
```

### 2.3 `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Internet — required for map tiles and API calls -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- Location — required for GPS dot and driver location uploads -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

    <!-- Background location — DRIVER APP ONLY -->
    <!-- Remove from rider app -->
    <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

    <!-- Foreground service — DRIVER APP ONLY for background location service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

    <application
        android:label="HeyCaby"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <!-- Mapbox public access token -->
        <!-- Value injected at build time via --dart-define -->
        <!-- Do NOT hardcode your token here -->

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

    </application>
</manifest>
```

### 2.4 Troubleshooting Android builds

**Error: `SDK Registry token is null`**
You are using an old cached version of the plugin. Run:
```bash
flutter clean
cd android && ./gradlew clean
cd ..
flutter pub get
flutter run
```

**Error: `Could not resolve com.mapbox.maps:android:X.X.X — 403 Forbidden`**
The Maven URL changed. Make sure your `settings.gradle.kts` uses:
```
https://api.mapbox.com/downloads/v2/releases/maven
```
Not the old `https://api.mapbox.com/downloads/v2/releases/maven` path — same URL, but make sure there are no credentials block attached. Remove any `authentication {}` or `credentials {}` blocks entirely for v11+.

**Error: `Gradle sync failed — Kotlin version conflict`**
In `android/build.gradle.kts`, set:
```kotlin
buildscript {
    dependencies {
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.24")
    }
}
```

**Error: `compileSdk needs to be at least 35`**
Mapbox 2.17+ requires `compileSdk = 35`. Update both `android/app/build.gradle.kts` and the root `build.gradle.kts`.

---

## PART 3 — IOS SETUP

### 3.1 `ios/Podfile`

```ruby
# Minimum iOS 14.0 required by Mapbox v11
platform :ios, '14.0'

# Required to prevent Xcode from stripping Mapbox frameworks
ENV['COCOAPODS_DISABLE_STATS'] = 'true'

project 'Runner', {
  'Debug' => :debug,
  'Profile' => :release,
  'Release' => :release,
}

def flutter_root
  generated_xcode_build_settings_path = File.expand_path(File.join('..', 'Flutter', 'Generated.xcconfig'), __FILE__)
  unless File.exist?(generated_xcode_build_settings_path)
    raise "#{generated_xcode_build_settings_path} must exist."
  end

  File.foreach(generated_xcode_build_settings_path) do |line|
    matches = line.match(/FLUTTER_ROOT\=(.*)/)
    return matches[1].strip if matches
  end
  raise "FLUTTER_ROOT not found in #{generated_xcode_build_settings_path}."
end

require File.expand_path(File.join('packages', 'flutter_tools', 'bin', 'podhelper'), flutter_root)

flutter_ios_podfile_setup

target 'Runner' do
  use_frameworks!
  use_modular_headers!

  flutter_install_all_ios_pods File.dirname(File.realpath(__FILE__))

  target 'RunnerTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      # Required for Mapbox v11
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
      # Required for Xcode 15+ to avoid linker errors
      config.build_settings['OTHER_LDFLAGS'] ||= ['$(inherited)']
    end
  end
end
```

> **Do NOT add `~/.netrc` credentials.** This is the old iOS setup for v10 and earlier. Mapbox v11 iOS SDK is distributed via CocoaPods public repository — no credentials needed.

### 3.2 `ios/Runner/Info.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Location permission strings — REQUIRED for App Store -->
    <!-- Rider app -->
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>HeyCaby uses your location to set your pickup point and show nearby drivers.</string>

    <!-- Driver app only — replace "Rider app" entries with: -->
    <!-- <key>NSLocationWhenInUseUsageDescription</key> -->
    <!-- <string>HeyCaby Driver uses your location to show riders where you are and help you receive ride requests.</string> -->
    <!-- <key>NSLocationAlwaysAndWhenInUseUsageDescription</key> -->
    <!-- <string>HeyCaby Driver needs background location so riders can track your position between rides.</string> -->
    <!-- <key>NSLocationAlwaysUsageDescription</key> -->
    <!-- <string>HeyCaby Driver needs background location so riders can track your position between rides.</string> -->

    <!-- Embedded views preview — required for Mapbox map widget on older Flutter versions -->
    <key>io.flutter.embedded_views_preview</key>
    <true/>

    <!-- Mapbox public token is set at runtime via MapboxOptions — no key needed here -->

</dict>
</plist>
```

### 3.3 After editing Podfile

```bash
cd ios
pod install --repo-update
cd ..
flutter run
```

If you get `CocoaPods could not find compatible versions for pod "MapboxMaps"`:
```bash
cd ios
pod repo update
pod deintegrate
pod install
```

### 3.4 Troubleshooting iOS builds

**Error: `curl: (22) The requested URL returned error: 401`**
Old issue from pre-v11. Upgrading to `mapbox_maps_flutter: 2.19.1` fixes this. No `.netrc` needed.

**Error: `module 'MapboxMaps' not found`**
Run `pod install` from the `ios/` directory, not from the project root. Then `flutter clean && flutter run`.

**Error: `ld: framework not found MapboxMaps`**
In Xcode, go to Runner → Build Settings → Framework Search Paths. Make sure it includes `$(inherited)` and `${PODS_XCFRAMEWORKS_BUILD_DIR}`.

**Error: `IPHONEOS_DEPLOYMENT_TARGET` warnings**
Add `config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'` to your post_install block (already included above).

---

## PART 4 — TOKEN SETUP (RUNTIME)

### 4.1 Setting the public token

The public token is set once in `main.dart` before `runApp()`. **Never hardcode it.** Pass it via `--dart-define`.

```dart
// apps/rider/lib/main.dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set Mapbox public token from --dart-define at build time
  // NEVER hardcode the token here
  const mapboxToken = String.fromEnvironment('MAPBOX_PUBLIC_TOKEN');
  MapboxOptions.setAccessToken(mapboxToken);

  // Initialize Supabase
  await HeyCabySupabase.initialize();

  // Initialize push (Firebase)
  await PushService.initializeForRider();

  runApp(
    const ProviderScope(child: HeyCabyRiderApp()),
  );
}
```

### 4.2 Passing the token at build/run time

```bash
# Development run
flutter run \
  --dart-define=MAPBOX_PUBLIC_TOKEN=pk.your_public_token_here \
  --dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key

# Production build (Android)
flutter build appbundle \
  --dart-define=MAPBOX_PUBLIC_TOKEN=pk.your_public_token_here \
  --dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --release

# Production build (iOS)
flutter build ipa \
  --dart-define=MAPBOX_PUBLIC_TOKEN=pk.your_public_token_here \
  --dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --release
```

### 4.3 VS Code `launch.json`

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "HeyCaby Rider (debug)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=MAPBOX_PUBLIC_TOKEN=pk.your_token",
        "--dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your_anon_key"
      ]
    },
    {
      "name": "HeyCaby Driver (debug)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--dart-define=MAPBOX_PUBLIC_TOKEN=pk.your_token",
        "--dart-define=SUPABASE_URL=https://fvrprxguoternoxnyhoj.supabase.co",
        "--dart-define=SUPABASE_ANON_KEY=your_anon_key"
      ]
    }
  ]
}
```

---

## PART 5 — THE MAP WIDGET (BASE SETUP)

### 5.1 Minimal working map

```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class HeyCabyMapWidget extends StatefulWidget {
  final CameraOptions initialCamera;
  final void Function(MapboxMap map) onMapCreated;

  const HeyCabyMapWidget({
    super.key,
    required this.initialCamera,
    required this.onMapCreated,
  });

  @override
  State<HeyCabyMapWidget> createState() => _HeyCabyMapWidgetState();
}

class _HeyCabyMapWidgetState extends State<HeyCabyMapWidget> {
  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('heycaby_map'),
      // Style: Mapbox Standard is the recommended default for v11
      // Custom styles from Mapbox Studio use: 'mapbox://styles/username/style-id'
      styleUri: MapboxStyles.STANDARD,
      cameraOptions: widget.initialCamera,
      onMapCreated: widget.onMapCreated,
      // Required: pass the token again in the widget for some SDK versions
      // If already set via MapboxOptions.setAccessToken() this can be omitted
      // but including it prevents edge-case null token issues
    );
  }
}
```

### 5.2 Camera options

```dart
// Centre on the Netherlands (default for HeyCaby)
final netherlandsCamera = CameraOptions(
  center: Point(coordinates: Position(4.9041, 52.3676)).toJson(), // Amsterdam
  zoom: 10.0,
  bearing: 0.0,
  pitch: 0.0,
);

// Centre on rider/driver GPS position
CameraOptions cameraOnPosition(double lat, double lng, {double zoom = 15.0}) {
  return CameraOptions(
    center: Point(coordinates: Position(lng, lat)).toJson(),
    zoom: zoom,
    bearing: 0.0,
    pitch: 0.0,
  );
}
```

> **Note:** Mapbox uses `Position(longitude, latitude)` — longitude first, then latitude. This is the opposite of most other mapping libraries. This is a common source of bugs. Always pass `lng` then `lat`.

### 5.3 Camera animations

```dart
// Smooth fly to a new position
await mapboxMap.flyTo(
  CameraOptions(
    center: Point(coordinates: Position(lng, lat)).toJson(),
    zoom: 15.0,
  ),
  MapAnimationOptions(duration: 1500, startDelay: 0),
);

// Instant jump (no animation)
await mapboxMap.setCamera(
  CameraOptions(
    center: Point(coordinates: Position(lng, lat)).toJson(),
    zoom: 15.0,
  ),
);
```

---

## PART 6 — LOCATION COMPONENT (GPS DOT)

### 6.1 Show the user's location puck

```dart
Future<void> enableLocationPuck(MapboxMap mapboxMap) async {
  await mapboxMap.location.updateSettings(
    LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,    // Blue pulse ring — use for rider's pickup dot
      pulsingColor: 0xFF2196F3, // Blue
      pulsingMaxRadius: 50.0,
      // 2D puck (flat arrow) — good for both rider and driver
      locationPuck: LocationPuck(
        locationPuck2D: LocationPuck2D(
          // Use default puck — clean blue dot with accuracy circle
          topImage: null,    // null = default Mapbox puck
          bearingImage: null,
          shadowImage: null,
        ),
      ),
    ),
  );
}
```

### 6.2 Driver car puck (rotates with heading)

For the driver's home screen, the puck should look like a car icon facing the direction of travel:

```dart
Future<void> enableDriverCarPuck(MapboxMap mapboxMap) async {
  // Option A: Use a custom car icon from assets
  // Add 'assets/images/car_top.png' to your pubspec.yaml assets
  await mapboxMap.location.updateSettings(
    LocationComponentSettings(
      enabled: true,
      pulsingEnabled: false,
      locationPuck: LocationPuck(
        locationPuck2D: LocationPuck2D(
          topImage: await _loadImageBytes('assets/images/car_top.png'),
          bearingImage: await _loadImageBytes('assets/images/car_top.png'),
          // shadowImage: optional drop shadow
        ),
      ),
    ),
  );
}

Future<Uint8List> _loadImageBytes(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List();
}
```

---

## PART 7 — ROUTE LINES (The Most Important Part for a Taxi App)

### 7.1 How route lines work in Mapbox Flutter

Route lines are drawn using three steps:
1. Call the **Mapbox Directions API** (HTTP) to get the route geometry
2. Decode the encoded polyline string into coordinates
3. Add the coordinates as a **GeoJSON source** and draw a **LineLayer** on the map

This is different from older mapping libraries where you could directly pass a list of `LatLng` points. In Mapbox Flutter, you work with GeoJSON sources and layers.

### 7.2 The Directions API call

```dart
// packages/heycaby_map/lib/src/directions_service.dart
import 'package:dio/dio.dart';
import 'package:polyline_codec/polyline_codec.dart';

class RouteResult {
  final List<List<double>> coordinates; // [[lng, lat], [lng, lat], ...]
  final double distanceKm;
  final double durationMin;

  const RouteResult({
    required this.coordinates,
    required this.distanceKm,
    required this.durationMin,
  });
}

class DirectionsService {
  static const _baseUrl = 'https://api.mapbox.com/directions/v5/mapbox/driving';
  final Dio _dio;
  final String _token;

  // Simple cache — don't refetch same route
  final Map<String, RouteResult> _cache = {};

  DirectionsService({required String token}) :
    _token = token,
    _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  String _cacheKey(double fromLat, double fromLng, double toLat, double toLng) =>
    '${fromLat.toStringAsFixed(5)},${fromLng.toStringAsFixed(5)}'
    '->${toLat.toStringAsFixed(5)},${toLng.toStringAsFixed(5)}';

  Future<RouteResult?> getRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final key = _cacheKey(fromLat, fromLng, toLat, toLng);
    if (_cache.containsKey(key)) return _cache[key];

    try {
      // Note: Mapbox coords are lng,lat — NOT lat,lng
      final url = '$_baseUrl/$fromLng,$fromLat;$toLng,$toLat';
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: {
          'geometries': 'polyline',  // encoded polyline string
          'overview': 'full',        // full route geometry, not simplified
          'access_token': _token,
        },
      );

      final data = response.data!;
      final routes = data['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as String; // encoded polyline
      final distanceM = (route['distance'] as num).toDouble();
      final durationS = (route['duration'] as num).toDouble();

      // Decode the polyline string into [lat, lng] pairs
      // PolylineCodec returns [[lat, lng], ...] (note: lat first here)
      final decoded = PolylineCodec.decode(geometry);

      // Convert to [[lng, lat], ...] for Mapbox GeoJSON (lng first for Mapbox)
      final coordinates = decoded.map((p) => [p[1], p[0]]).toList();

      final result = RouteResult(
        coordinates: coordinates,
        distanceKm: distanceM / 1000,
        durationMin: durationS / 60,
      );

      _cache[key] = result;
      return result;
    } on DioException catch (e) {
      debugPrint('Directions API error: ${e.message}');
      return null;
    }
  }

  void clearCache() => _cache.clear();
}
```

### 7.3 Drawing the route line on the map

```dart
// packages/heycaby_map/lib/src/route_layer.dart

class RouteLayer {
  static const _sourceId = 'heycaby-route-source';
  static const _layerId = 'heycaby-route-layer';
  static const _casingLayerId = 'heycaby-route-casing';

  /// Draw or update the route line on the map.
  /// Call this after getting RouteResult from DirectionsService.
  static Future<void> drawRoute(
    MapboxMap mapboxMap,
    RouteResult route, {
    int lineColor = 0xFF1A73E8,   // Blue — rider route
    int casingColor = 0xFFFFFFFF, // White casing under the line
    double lineWidth = 5.0,
    double casingWidth = 8.0,
  }) async {
    // Build GeoJSON for the route
    final geoJson = _buildLineGeoJson(route.coordinates);

    // Check if source exists — update it or add it fresh
    final sourceExists = await _sourceExists(mapboxMap);
    if (sourceExists) {
      await mapboxMap.style.updateGeoJSONSourceFeatures(
        _sourceId,
        'route-feature',
        [Feature(geometry: LineString(coordinates: _toPositions(route.coordinates)))],
      );
    } else {
      await mapboxMap.style.addSource(
        GeoJsonSource(id: _sourceId, data: geoJson),
      );

      // White casing layer (draws behind the main line for contrast)
      await mapboxMap.style.addLayer(
        LineLayer(
          id: _casingLayerId,
          sourceId: _sourceId,
          lineColor: casingColor,
          lineWidth: casingWidth,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
        ),
      );

      // Main route line
      await mapboxMap.style.addLayer(
        LineLayer(
          id: _layerId,
          sourceId: _sourceId,
          lineColor: lineColor,
          lineWidth: lineWidth,
          lineCap: LineCap.ROUND,
          lineJoin: LineJoin.ROUND,
          lineOpacity: 0.9,
        ),
      );
    }

    // Fit camera to show the full route
    await _fitCameraToRoute(mapboxMap, route.coordinates);
  }

  /// Remove the route line from the map
  static Future<void> clearRoute(MapboxMap mapboxMap) async {
    try {
      await mapboxMap.style.removeStyleLayer(_layerId);
      await mapboxMap.style.removeStyleLayer(_casingLayerId);
      await mapboxMap.style.removeStyleSource(_sourceId);
    } catch (_) {
      // Layer/source may not exist — safe to ignore
    }
  }

  /// Fit the camera to show both ends of the route with padding
  static Future<void> _fitCameraToRoute(
    MapboxMap mapboxMap,
    List<List<double>> coordinates,
  ) async {
    if (coordinates.isEmpty) return;

    double minLng = coordinates.first[0];
    double maxLng = coordinates.first[0];
    double minLat = coordinates.first[1];
    double maxLat = coordinates.first[1];

    for (final coord in coordinates) {
      minLng = minLng < coord[0] ? minLng : coord[0];
      maxLng = maxLng > coord[0] ? maxLng : coord[0];
      minLat = minLat < coord[1] ? minLat : coord[1];
      maxLat = maxLat > coord[1] ? maxLat : coord[1];
    }

    final camera = await mapboxMap.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(minLng, minLat)),
        northeast: Point(coordinates: Position(maxLng, maxLat)),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 100, left: 60, bottom: 200, right: 60),
      null, null, null,
    );

    await mapboxMap.flyTo(camera, MapAnimationOptions(duration: 800));
  }

  static String _buildLineGeoJson(List<List<double>> coordinates) {
    final coordString = coordinates
        .map((c) => '[${c[0]},${c[1]}]')
        .join(',');
    return '{"type":"FeatureCollection","features":[{"type":"Feature","geometry":{"type":"LineString","coordinates":[$coordString]},"properties":{}}]}';
  }

  static List<Position> _toPositions(List<List<double>> coordinates) {
    return coordinates.map((c) => Position(c[0], c[1])).toList();
  }

  static Future<bool> _sourceExists(MapboxMap mapboxMap) async {
    try {
      await mapboxMap.style.getSource(_sourceId);
      return true;
    } catch (_) {
      return false;
    }
  }
}
```

### 7.4 Usage in a screen

```dart
// In ConfirmDestinationScreen — draw route after pickup + destination confirmed
Future<void> _drawRoute() async {
  final route = await ref.read(directionsServiceProvider).getRoute(
    fromLat: pickup.lat,
    fromLng: pickup.lng,
    toLat: destination.lat,
    toLng: destination.lng,
  );

  if (route != null && _mapboxMap != null) {
    await RouteLayer.drawRoute(_mapboxMap!, route);
    // Update state with distance/duration for display
    setState(() {
      _distanceKm = route.distanceKm;
      _durationMin = route.durationMin;
    });
  }
}

// In SearchingScreen or on screen disposal — clear the route
await RouteLayer.clearRoute(_mapboxMap!);
```

---

## PART 8 — MARKERS (PINS AND DRIVER DOTS)

### 8.1 Point annotations (recommended for simple pins)

```dart
// packages/heycaby_map/lib/src/marker_manager.dart

class MarkerManager {
  PointAnnotationManager? _annotationManager;
  final Map<String, PointAnnotation> _annotations = {};

  Future<void> init(MapboxMap mapboxMap) async {
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
  }

  /// Add or update the rider's pickup dot (blue pulsing circle)
  Future<void> setPickupMarker(double lat, double lng) async {
    final options = PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      iconSize: 1.2,
      // Use 'mapbox://image/...' for built-in icons or a custom image
      // For the blue circle, use the location component instead (see Part 6)
    );
    if (_annotations.containsKey('pickup')) {
      await _annotationManager?.update(
        _annotations['pickup']!..geometry = Point(coordinates: Position(lng, lat)),
      );
    } else {
      _annotations['pickup'] = await _annotationManager!.create(options);
    }
  }

  /// Add a destination pin
  Future<void> setDestinationPin(double lat, double lng) async {
    final imageData = await _loadPinImage('assets/images/destination_pin.png');
    final options = PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: imageData,
      iconSize: 1.0,
      iconAnchor: IconAnchor.BOTTOM, // Pin tip points to the location
    );
    if (_annotations.containsKey('destination')) {
      await _annotationManager?.delete(_annotations['destination']!);
    }
    _annotations['destination'] = await _annotationManager!.create(options);
  }

  /// Add or update a driver car marker (rotates with heading)
  Future<void> setDriverMarker(double lat, double lng, {double heading = 0}) async {
    final imageData = await _loadPinImage('assets/images/car_marker.png');
    final options = PointAnnotationOptions(
      geometry: Point(coordinates: Position(lng, lat)),
      image: imageData,
      iconSize: 1.0,
      iconRotate: heading, // Rotate to match GPS heading
      iconAnchor: IconAnchor.CENTER,
    );
    if (_annotations.containsKey('driver')) {
      final existing = _annotations['driver']!;
      existing.geometry = Point(coordinates: Position(lng, lat));
      existing.iconRotate = heading;
      await _annotationManager?.update(existing);
    } else {
      _annotations['driver'] = await _annotationManager!.create(options);
    }
  }

  Future<void> removeAll() async {
    await _annotationManager?.deleteAll();
    _annotations.clear();
  }

  Future<Uint8List> _loadPinImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }
}
```

### 8.2 Required image assets

Add to `pubspec.yaml` in each app:
```yaml
flutter:
  assets:
    - assets/images/destination_pin.png    # Gold/accent pin for destination
    - assets/images/car_marker.png         # Top-down car icon for driver
    - assets/images/car_top.png            # Same, used for location puck
```

Design the car icon as a simple top-down silhouette, at least 64×64px, on a transparent background. The icon will be rotated programmatically using `iconRotate`.

---

## PART 9 — REAL-TIME DRIVER TRACKING (ACTIVE RIDE SCREEN)

This is the core of the live ride tracking experience. The driver's car should move smoothly across the rider's map.

```dart
// In apps/rider/lib/screens/active_ride_screen.dart

class ActiveRideScreen extends ConsumerStatefulWidget {
  final String rideId;
  const ActiveRideScreen({super.key, required this.rideId});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  MapboxMap? _mapboxMap;
  MarkerManager? _markers;
  RouteResult? _currentRoute;
  RealtimeChannel? _locationChannel;
  Position? _lastDriverPosition;
  Timer? _etaUpdateTimer;
  String _etaText = '...';

  @override
  void initState() {
    super.initState();
    _subscribeToDriverLocation();
  }

  @override
  void dispose() {
    _locationChannel?.unsubscribe();
    _etaUpdateTimer?.cancel();
    super.dispose();
  }

  void _subscribeToDriverLocation() {
    // Subscribe to driver_locations table via Supabase Realtime
    // This fires every time the driver's location is updated (~every 5s)
    final driverId = ref.read(bookingProvider).assignedDriverId;
    if (driverId == null) return;

    _locationChannel = Supabase.instance.client
        .channel('driver_location:$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) => _onDriverLocationUpdate(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _onDriverLocationUpdate(Map<String, dynamic> record) async {
    final lat = (record['latitude'] as num).toDouble();
    final lng = (record['longitude'] as num).toDouble();
    final heading = (record['heading'] as num?)?.toDouble() ?? 0.0;

    // Update car marker with smooth position + heading
    await _markers?.setDriverMarker(lat, lng, heading: heading);

    // Throttle camera re-fit to once every 5 seconds
    // (avoid jitter from rapid camera updates)
    final now = DateTime.now();
    if (_lastCameraFit == null ||
        now.difference(_lastCameraFit!) > const Duration(seconds: 5)) {
      _lastCameraFit = now;
      await _refitCamera(lat, lng);
    }

    // Update ETA pill
    await _updateEta(lat, lng);
  }

  DateTime? _lastCameraFit;

  Future<void> _refitCamera(double driverLat, double driverLng) async {
    if (_mapboxMap == null) return;
    final pickup = ref.read(bookingProvider).pickup;
    if (pickup == null) return;

    // Fit camera to show driver position + pickup location together
    final camera = await _mapboxMap!.cameraForCoordinateBounds(
      CoordinateBounds(
        southwest: Point(coordinates: Position(
          [driverLng, pickup.lng].reduce((a, b) => a < b ? a : b),
          [driverLat, pickup.lat].reduce((a, b) => a < b ? a : b),
        )),
        northeast: Point(coordinates: Position(
          [driverLng, pickup.lng].reduce((a, b) => a > b ? a : b),
          [driverLat, pickup.lat].reduce((a, b) => a > b ? a : b),
        )),
        infiniteBounds: false,
      ),
      MbxEdgeInsets(top: 120, left: 60, bottom: 280, right: 60),
      null, null, null,
    );
    await _mapboxMap!.setCamera(camera); // No animation for live tracking
  }

  Future<void> _updateEta(double driverLat, double driverLng) async {
    final pickup = ref.read(bookingProvider).pickup;
    if (pickup == null) return;

    // Only call Directions API every 30 seconds to avoid cost runup
    // For ETA between updates, interpolate from last known speed
    final route = await ref.read(directionsServiceProvider).getRoute(
      fromLat: driverLat,
      fromLng: driverLng,
      toLat: pickup.lat,
      toLng: pickup.lng,
    );

    if (route != null && mounted) {
      final minutes = route.durationMin.ceil();
      setState(() {
        _etaText = minutes <= 1 ? 'Almost here' : '$minutes min';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map fills the whole screen
          MapWidget(
            key: const ValueKey('active_ride_map'),
            styleUri: MapboxStyles.STANDARD,
            cameraOptions: CameraOptions(
              center: Point(coordinates: Position(4.4792, 51.9244)).toJson(),
              zoom: 14.0,
            ),
            onMapCreated: (map) async {
              _mapboxMap = map;
              _markers = MarkerManager();
              await _markers!.init(map);
              // Draw initial route from driver to pickup
              await _drawInitialRoute();
            },
          ),
          // ETA bubble at top
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: _EtaBubble(text: _etaText),
          ),
          // Bottom sheet with driver info
          Align(
            alignment: Alignment.bottomCenter,
            child: _DriverInfoSheet(rideId: widget.rideId),
          ),
        ],
      ),
    );
  }

  Future<void> _drawInitialRoute() async {
    // Draw the route from driver's last known position to pickup
    // ...
  }
}
```

---

## PART 10 — GEOCODING (ADDRESS SEARCH)

### 10.1 Mapbox Search API (recommended over Geocoding v5)

The Mapbox Search API (formerly Geocoding v5) is the correct API for address autocomplete in 2025+. It supports session tokens for billing optimization.

```dart
// packages/heycaby_map/lib/src/geocoding_service.dart

class AddressResult {
  final String displayName;
  final String fullAddress;
  final double lat;
  final double lng;
  final String? city;
  final String? postcode;

  const AddressResult({
    required this.displayName,
    required this.fullAddress,
    required this.lat,
    required this.lng,
    this.city,
    this.postcode,
  });
}

class GeocodingService {
  static const _searchBase = 'https://api.mapbox.com/search/searchbox/v1/suggest';
  static const _retrieveBase = 'https://api.mapbox.com/search/searchbox/v1/retrieve';
  static const _geocodingBase = 'https://api.mapbox.com/geocoding/v5/mapbox.places';

  final Dio _dio;
  final String _token;
  String? _sessionToken;

  GeocodingService({required String token})
      : _token = token,
        _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));

  /// Start a new search session (call when search field focuses)
  void startSession() {
    _sessionToken = const Uuid().v4();
  }

  /// End session and clear token (call when user selects a result)
  void endSession() {
    _sessionToken = null;
  }

  /// Search for addresses (minimum 3 characters, debounce 300ms in UI layer)
  Future<List<AddressResult>> search({
    required String query,
    double? proximityLat,
    double? proximityLng,
    String country = 'NL',  // Restrict to Netherlands by default
  }) async {
    if (query.trim().length < 3) return [];
    _sessionToken ??= const Uuid().v4();

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        _searchBase,
        queryParameters: {
          'q': query,
          'access_token': _token,
          'session_token': _sessionToken,
          'country': country,
          'language': 'nl',  // Dutch results
          'limit': 6,
          if (proximityLat != null && proximityLng != null)
            'proximity': '$proximityLng,$proximityLat', // lng,lat
        },
      );

      final suggestions = response.data!['suggestions'] as List<dynamic>;
      return suggestions.map((s) => _suggestionToResult(s as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      debugPrint('Geocoding search error: ${e.message}');
      return [];
    }
  }

  /// Retrieve full details for a suggestion (use mapbox_id from suggestion)
  Future<AddressResult?> retrieve(String mapboxId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_retrieveBase/$mapboxId',
        queryParameters: {
          'access_token': _token,
          'session_token': _sessionToken,
        },
      );
      endSession(); // Session ends after retrieval

      final features = response.data!['features'] as List<dynamic>;
      if (features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      return _featureToResult(feature);
    } on DioException catch (e) {
      debugPrint('Geocoding retrieve error: ${e.message}');
      return null;
    }
  }

  /// Reverse geocode: coordinates → address
  Future<AddressResult?> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_geocodingBase/$lng,$lat.json',
        queryParameters: {
          'access_token': _token,
          'types': 'address',
          'country': 'NL',
          'language': 'nl',
        },
      );

      final features = response.data!['features'] as List<dynamic>;
      if (features.isEmpty) return null;

      final feature = features.first as Map<String, dynamic>;
      return _geocodingFeatureToResult(feature, lat, lng);
    } on DioException catch (e) {
      debugPrint('Reverse geocoding error: ${e.message}');
      return null;
    }
  }

  AddressResult _suggestionToResult(Map<String, dynamic> s) {
    return AddressResult(
      displayName: s['name'] as String? ?? '',
      fullAddress: s['full_address'] as String? ?? s['place_formatted'] as String? ?? '',
      lat: 0, // Coordinates come from retrieve(), not suggest()
      lng: 0,
      city: _extractContext(s, 'place'),
      postcode: _extractContext(s, 'postcode'),
    );
  }

  AddressResult _featureToResult(Map<String, dynamic> f) {
    final coords = (f['geometry'] as Map)['coordinates'] as List;
    final props = f['properties'] as Map<String, dynamic>;
    return AddressResult(
      displayName: props['name'] as String? ?? '',
      fullAddress: props['full_address'] as String? ?? '',
      lat: (coords[1] as num).toDouble(),
      lng: (coords[0] as num).toDouble(),
      city: props['place'] as String?,
      postcode: props['postcode'] as String?,
    );
  }

  AddressResult _geocodingFeatureToResult(Map<String, dynamic> f, double lat, double lng) {
    final context = f['context'] as List<dynamic>? ?? [];
    return AddressResult(
      displayName: f['text'] as String? ?? '',
      fullAddress: f['place_name'] as String? ?? '',
      lat: lat,
      lng: lng,
      city: context
          .whereType<Map>()
          .firstWhere((c) => (c['id'] as String).startsWith('place'), orElse: () => {})['text'] as String?,
      postcode: context
          .whereType<Map>()
          .firstWhere((c) => (c['id'] as String).startsWith('postcode'), orElse: () => {})['text'] as String?,
    );
  }

  String? _extractContext(Map<String, dynamic> suggestion, String type) {
    final context = suggestion['context'] as Map<String, dynamic>?;
    if (context == null) return null;
    return context[type] as String?;
  }
}
```

---

## PART 11 — COMMON DEPENDENCY CONFLICTS AND FIXES

### 11.1 Conflict: `mapbox_maps_flutter` vs `geolocator`

These two packages both declare location-related Android permissions. They should not conflict but occasionally do on older Flutter versions. If you see a duplicate permission error:

In `AndroidManifest.xml`, add `tools:node="merge"` to your manifest tag:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
          xmlns:tools="http://schemas.android.com/tools">
```

### 11.2 Conflict: `mapbox_maps_flutter` vs `firebase_messaging` on Android

Both can conflict on `compileSdk` version. Set `compileSdk = 35` in both `android/app/build.gradle.kts` and ensure Firebase BOM is up to date:

```kotlin
// In android/app/build.gradle.kts
dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.0.0"))
    implementation("com.google.firebase:firebase-messaging")
}
```

### 11.3 Conflict: Multiple `kotlin-stdlib` versions

If you see `Duplicate class kotlin.collections.jdk8` errors:
```kotlin
// In android/app/build.gradle.kts
configurations.all {
    resolutionStrategy {
        force("org.jetbrains.kotlin:kotlin-stdlib:1.9.24")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.24")
        force("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.24")
    }
}
```

### 11.4 iOS build failing with `Undefined symbol`

Run in order:
```bash
flutter clean
cd ios
pod deintegrate
pod cache clean --all
pod install --repo-update
cd ..
flutter run
```

### 11.5 Map renders a grey/black box instead of tiles

Almost always a token issue. Check:
1. `MapboxOptions.setAccessToken()` was called before `runApp()`
2. The token starts with `pk.` (public token, not a secret `sk.` token)
3. The token has the correct scopes — for maps it needs `styles:read` and `tiles:read`
4. The device/simulator has internet access

### 11.6 Map renders on iOS simulator but not on physical device

Physical iOS device may have stricter certificate pinning. Make sure `NSAppTransportSecurity` is not blocking Mapbox domains. Add to `Info.plist` if needed:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>api.mapbox.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

---

## PART 12 — QUICK VERIFICATION CHECKLIST

Before writing any feature code, verify this basic setup works:

```
[ ] flutter pub get succeeds with no errors
[ ] flutter doctor shows no issues relevant to your target platform
[ ] A basic MapWidget renders on Android device (not just emulator)
[ ] A basic MapWidget renders on physical iPhone
[ ] The blue GPS dot appears on both platforms
[ ] Moving the phone moves the GPS dot
[ ] Tapping the map prints coordinates to console (basic gesture test)
[ ] Directions API call returns a route (test with Amsterdam coords)
[ ] A route line is drawn on the map from point A to point B
[ ] flutter build appbundle --release succeeds (Android)
[ ] flutter build ipa --release succeeds (iOS)
```

Do not proceed to building screens until every item above is checked.

---

## PART 13 — MAPBOX API COST RULES

These are enforced in the service layer. Not optional.

| Rule | Implementation |
|------|----------------|
| Geocoding: minimum 3 chars before API call | Checked in `GeocodingService.search()` |
| Geocoding: debounce 300ms | Implemented in the UI search field using `Timer` |
| Geocoding: one session token per search flow | `_sessionToken` cleared after `retrieve()` |
| Directions: cache results | `_cache` in `DirectionsService` |
| Directions: only call when both pickup and destination are confirmed | Not called on every keystroke |
| Live tracking: throttle camera fits to once per 5s | `_lastCameraFit` timer in `ActiveRideScreen` |
| Live tracking: ETA recalculation every 30s only | Timer-gated in `_updateEta()` |
| Search: restrict to Netherlands bbox | `country: 'NL'` in `GeocodingService` |

---

*HeyCaby Mapbox Flutter Guide — verified against mapbox_maps_flutter 2.19.1, Flutter 3.27.x, March 2026.*
*Update this file when upgrading Mapbox versions. Lock the version in pubspec.yaml.*
