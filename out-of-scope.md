# Kids Educational App — Brainstorm & Technical Plan

## Core Concept
A parent-controlled study app where children complete tasks to "unlock" their device. Phone remains locked until assigned puzzles (math, logic) are solved.

---

## Tech Stack

**Flutter** — single codebase, smooth UI, you're already familiar with it from HeyCaby.

---

## Backend Architecture (Supabase)

### Tables
```
users (parents & children, linked via family_id)
├── id, email, role (parent|child), family_id

tasks
├── id, family_id, assigned_by, assigned_to, type (math|logic|reading)
├── content (JSONB for flexible question format)
├── difficulty, due_date, status, created_at

progress
├── id, child_id, task_id, completed_at, attempts, score

families
├── id, name, settings (screen_lock_duration, reward_system, etc.)
```

### Key Features
- **RLS policies:** Parents see only their family's data
- **Real-time:** Live progress updates via Supabase subscriptions
- **Versioning field:** `content_version` in tasks table for API-driven updates

---

## App Architecture

### Core Principle: API-Driven Content
- App = static shell (minimal baked-in logic)
- All tasks, puzzles, pricing (if applicable), rules = pulled from API
- Versioning system allows content/logic updates without app store release

### Flow
1. **Parent Dashboard**
   - Create/select tasks from template library
   - Assign to child with deadline/difficulty
   - View progress analytics

2. **Child Experience**
   - Device locks on schedule or parent trigger
   - Lock screen displays current task
   - Solve puzzle → unlock device
   - Progress auto-syncs to Supabase

3. **Screen Lock Mechanism**
   - **Android:** `SYSTEM_ALERT_WINDOW` overlay + UsageStats API + foreground service
   - **iOS:** No true system lock possible; use Guided Access (manual setup) or in-app lock with parental controls
   - See implementation details below

---

## Development Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Supabase project setup + migrations
- [ ] Flutter app scaffold + auth (parent/child roles)
- [ ] Basic parent dashboard (CRUD tasks)

### Phase 2: Core Mechanics (Week 3-4)
- [ ] Task rendering engine (JSONB → Flutter widgets)
- [ ] Math/logic puzzle generators
- [ ] Screen lock service (Android first)

### Phase 3: Sync & Polish (Week 5-6)
- [ ] Real-time progress sync
- [ ] Offline mode + queue
- [ ] Reward system (points, badges)

### Phase 4: Scale (Future)
- [ ] Subject expansions (reading comprehension, language)
- [ ] AI-generated difficulty scaling
- [ ] Family leaderboards

---

## Screen Lock Implementation

### Android (Full System Lock Possible)

Required permissions in `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
```

**Architecture:**
1. **Foreground Service** (`LockService.kt`) — keeps process alive, shows persistent notification
2. **WindowManager overlay** — draws full-screen view blocking all touches
3. **UsageStats listener** — detects when child opens other apps, immediately triggers overlay
4. **Flutter method channels** — `lockScreen()`, `unlockScreen(taskCompleted: boolean)`

**Key code pieces:**
```kotlin
// LockOverlayManager.kt
val params = WindowManager.LayoutParams(
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.MATCH_PARENT,
    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
    PixelFormat.TRANSLUCENT
)
windowManager.addView(lockView, params)
```

**User flow:**
- Parent enables "Study Mode" from dashboard → sends FCM to child's device
- Child's app receives FCM → starts LockService → shows overlay
- Overlay displays current task from Supabase
- Child solves task → Flutter validates → calls `unlockScreen()` via method channel
- Service stops, overlay removed, device usable

### iOS (Severely Limited — No True System Lock)

Apple restricts apps from blocking the system. Several approaches with tradeoffs:

**Option A: Guided Access (Simplest)**
- Parent manually enables Settings → Accessibility → Guided Access
- Sets passcode (parent keeps secret)
- Triple-click home/power button to enter/exit
- **Limitation:** Manual setup, not programmatic from your app

**Option B: Screen Time API + ManagedSettings + Local VPN (Advanced)**
This is a more aggressive approach that gets closer to true locking:

1. **Screen Time API** (`FamilyActivitySelection`)
   - Request family pairing via `FamilyActivityPicker`
   - Parent selects apps to restrict from child's device
   - **Requires:** Child's device supervised by Family Sharing
   - **Limitation:** Child can still deny the permission prompt

2. **ManagedSettings** (`ManagedSettingsStore`)
   - Block specific apps by bundle ID
   - Set downtime schedules programmatically
   - **Requires:** Shield Configuration entitlement from Apple (hard to get for consumer apps)
   - **Docs:** [Apple ManagedSettings](https://developer.apple.com/documentation/managedsettings)

3. **Local VPN/DNS Filter (NEPacketTunnelProvider)**
   - Block all internet except your app's servers
   - Child can't use Safari, YouTube, games, etc.
   - **Still allows:** Home screen, settings, Camera, offline games
   - **Requires:** `com.apple.developer.networking.networkextension` entitlement
   - **App Store risk:** VPN apps get extra scrutiny, may be rejected for "misleading functionality"

**Combined flow:**
- Parent grants Screen Time access → app blocks entertainment apps via ManagedSettings
- VPN starts → blocks all network traffic
- Your app shows fullscreen lock screen with task
- Task complete → VPN stops → restrictions lifted

**Critical issues with this approach:**
- Entitlements require Apple approval (weeks/months, not guaranteed)
- FamilyActivityPicker requires child to tap "Allow" — they can refuse
- VPN + Screen Time combo might get rejected as "circumventing parental controls"
- Child can still play offline games, access settings, use Calculator

**Option C: In-App Lock with Focus Mode**
- Your app runs fullscreen with `UIApplication.shared.isIdleTimerDisabled = true`
- Use `DeviceActivity` framework to monitor screen time
- Show parental gate to exit
- **Limitation:** Child can still home-button out, but you can detect and nag

**Option D: MDM (Enterprise only)**
- Requires Apple Business Manager, school deployment
- Not viable for consumer app store

**Recommended iOS approach:**
For an App Store consumer app: **Guided Access (Option A)** is the only realistic path. The Screen Time + VPN combo (Option B) is technically possible but high-risk for rejection and complex to implement.

If you're building a B2B/school product: **MDM (Option D)** is the proper solution.

---

## Guided Access Workflow (iOS — Detailed)

### What is Guided Access?
It's a built-in Apple feature that locks the iPhone to a single app. Once enabled, the child **cannot**:
- Press the home button (nothing happens)
- Swipe up to exit (nothing happens)
- Use other apps
- Turn off the phone (without your passcode)

They can ONLY use your app until you (the parent) exit Guided Access.

### One-Time Setup (Parent does this once on child's phone)

1. **Enable Guided Access in Settings**
   - Child's phone → Settings → Accessibility → Guided Access → Turn ON
   - Set a **passcode** (you keep this secret, don't tell the child)
   - Optional: Set Face ID/Touch ID as alternative

2. **Add to Accessibility Shortcut**
   - Settings → Accessibility → scroll to bottom → Accessibility Shortcut
   - Select "Guided Access"
   - Now triple-clicking the side button (or home button) starts Guided Access

### How It Works in Your App

**Step 1: Parent assigns a task**
- You open your parent app
- Create a math puzzle for your child
- Tap "Send Task"
- Your app sends a push notification to child's phone: "New task from Dad!"

**Step 2: Child receives the task**
- Child's phone buzzes, sees notification
- They open your app (or it's already open)
- Your app checks: "Is this a child device? Is Guided Access enabled?"
- If NOT in Guided Access → show red banner: "Ask parent to start Guided Access"

**Step 3: Parent starts Guided Access**
- Child hands phone to you (or you're physically there)
- You triple-click the side button
- Guided Access starts — child is now locked in the app
- You hand phone back

**Step 4: Child solves the puzzle**
- Child is trapped in your app
- They solve the math problem
- Your app shows "Task Complete!"
- Your app sends notification to YOUR phone: "Child completed the task"

**Step 5: Parent exits Guided Access**
- You receive the "task done" notification
- You find the child, take the phone
- Triple-click side button
- Enter your secret passcode
- Guided Access ends — phone is normal again

### What Your App Needs to Do

**On child's phone:**
1. Detect if Guided Access is active: `UIAccessibility.isGuidedAccessEnabled`
2. If NOT active and task is pending → show "Please start Guided Access" screen
3. If active and task complete → show celebration screen, send notification to parent
4. If child tries to leave (detect app backgrounding while task incomplete) → nothing happens (Guided Access blocks it anyway)

**On parent's phone:**
1. Send FCM notification when task assigned
2. Receive FCM notification when task completed
3. Show "Child is done — you can exit Guided Access" alert

### The "Gotcha"

The child **could** refuse to enter Guided Access. Your app can detect this and:
- Show "Task available — Guided Access required" screen
- Send notification to parent: "Child opened app but didn't start Guided Access"
- Play annoying alarm sound (if they have the phone)

But ultimately: **Physical parent involvement is required** to start Guided Access. You cannot do it remotely from your phone.

### Why This Still Works

Yes, it's less automatic than Android. But:
- It's **guaranteed App Store safe**
- It's **bulletproof** once enabled (child truly cannot escape)
- It uses **Apple's own security** (not hacks that break)
- Most parent-child interactions happen in-person anyway

### Comparison

| Feature | Android (Overlay) | iOS (Guided Access) |
|---------|-------------------|---------------------|
| Remote lock from parent phone | ✅ Yes | ❌ No (manual start) |
| Child can escape | ❌ No | ❌ No (once in GA) |
| App Store approval | ⚠️ Risky (overlay permission) | ✅ Safe |
| Child can refuse | ❌ No | ✅ Yes (don't start GA) |
| Works offline | ✅ Yes | ✅ Yes |

**Bottom line:** Android gets the slick "press button, child locked" experience. iOS requires the parent to physically triple-click the phone. But once locked, both are equally effective.

### Flutter Code for Guided Access Detection

**iOS Native (Swift) — Add to `AppDelegate.swift` or create `GuidedAccessPlugin.swift`:**

```swift
import Flutter
import UIKit

public class GuidedAccessPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.kidsapp/guidedaccess",
      binaryMessenger: registrar.messenger()
    )
    let instance = GuidedAccessPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
  
  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isGuidedAccessEnabled":
      result(UIAccessibility.isGuidedAccessEnabled)
    case "requestGuidedAccess":
      // Note: Cannot programmatically start Guided Access
      // This just opens Settings to help parent enable it
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
```

**Flutter Side — `guided_access_channel.dart`:**

```dart
import 'package:flutter/services.dart';

class GuidedAccessChannel {
  static const MethodChannel _channel = 
      MethodChannel('com.kidsapp/guidedaccess');
  
  /// Check if Guided Access is currently active
  static Future<bool> isGuidedAccessEnabled() async {
    try {
      final bool isEnabled = await _channel.invokeMethod('isGuidedAccessEnabled');
      return isEnabled;
    } catch (e) {
      return false;
    }
  }
  
  /// Open Settings so parent can enable Guided Access
  static Future<void> openSettings() async {
    await _channel.invokeMethod('requestGuidedAccess');
  }
}
```

**Usage in Child's App — `lock_screen.dart`:**

```dart
class LockScreen extends StatefulWidget {
  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _isGuidedAccessEnabled = false;
  bool _hasPendingTask = true;
  
  @override
  void initState() {
    super.initState();
    _checkGuidedAccess();
    // Check periodically in case parent just enabled it
    Timer.periodic(Duration(seconds: 2), (_) => _checkGuidedAccess());
  }
  
  Future<void> _checkGuidedAccess() async {
    final isEnabled = await GuidedAccessChannel.isGuidedAccessEnabled();
    setState(() => _isGuidedAccessEnabled = isEnabled);
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isGuidedAccessEnabled && _hasPendingTask) {
      return Scaffold(
        backgroundColor: Colors.red.shade100,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Guided Access Required',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text('Ask your parent to triple-click the side button'),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => GuidedAccessChannel.openSettings(),
                child: Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }
    
    // Show the actual task UI
    return TaskWidget(
      onComplete: () {
        // Send notification to parent that task is done
        FirebaseMessaging.instance.sendMessage(
          to: '/topics/parent_${familyId}',
          data: {'type': 'task_complete', 'child_id': childId},
        );
      },
    );
  }
}
```

**Register the plugin in `AppDelegate.swift`:**

```swift
@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Register our custom plugin
    GuidedAccessPlugin.register(with: self.registrar(forPlugin: "GuidedAccessPlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

### Flutter Bridge Setup

```dart
// screen_lock_channel.dart
class ScreenLockChannel {
  static const platform = MethodChannel('com.kidsapp/screenlock');
  
  static Future<void> lock() async {
    await platform.invokeMethod('lock');
  }
  
  static Future<void> unlock() async {
    await platform.invokeMethod('unlock');
  }
  
  static Future<bool> isLocked() async {
    return await platform.invokeMethod('isLocked');
  }
}
```

### Packages to Use

- `android_intent_plus` — check/request overlay permission
- `usage_stats` — monitor app launches (Android)
- `firebase_messaging` — parent → child trigger
- `flutter_foreground_task` — keep service alive
- `device_info_plus` — detect Android vs iOS capabilities

## Open Questions / Blockers

1. **iOS limitation accepted:** No true screen lock. Guided Access + in-app nag is the realistic path.
2. **Content versioning:** Add `version` header to API calls, cache with Hive/SharedPreferences.
3. **Offline solving:** Queue to SQLite, sync on reconnect via `connectivity_plus`.

---

## Reusable Pattern for Taxi App

The same API-driven architecture applies to HeyCaby:
- Ride types, pricing, promos = API-driven
- App stores static shell, content updates via backend
- Versioning allows quick feature flags without release cycles

---

*Last updated: Brainstorm session*
