# Private Travel Journal

A private, cross-platform travel journal app built using Flutter and Kotlin for Android. Capture, organize, and revisit your travel memories securely and beautifully.

---

## Features

- ✈️ Log and organize travel experiences
- 🖼 Add photos and notes to your trips
- 🔒 Private storage for your travel data
- 🎨 Beautiful and intuitive Flutter interface
- ☁️ Appwrite integration for backend services (Android)

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Android Studio / Xcode / Suitable IDE
- Java 8+
- (For Android) Android SDK & build tools

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/sivanimohan/privateTravelJournal.git
   cd privateTravelJournal
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   - **Android:**
     ```bash
     flutter run
     ```
   - **iOS:**  
     Make sure you have set up Xcode and CocoaPods, then:
     ```bash
     flutter run
     ```

---

## Android Build Configuration

- Located at `android/app/build.gradle`
- Uses Kotlin and integrates the Appwrite SDK for backend services.
- Debug signing config is pre-set for development builds.
- Minimum SDK: As per `flutter.minSdkVersion` (set in your Flutter config)
- Uses the Flutter Gradle plugin for seamless integration.

---

## Directory Structure

```
privateTravelJournal/
├── android/
│   └── app/
│       ├── build.gradle
│       └── src/
│           ├── main/
│           │   └── kotlin/...
│           └── debug/...
├── ios/
├── lib/
├── pubspec.yaml
└── README.md
```

---

## Dependencies

- [Flutter](https://flutter.dev/)
- [Kotlin](https://kotlinlang.org/) (for Android)
- [Appwrite Android SDK](https://github.com/appwrite/sdk-for-android) (`io.appwrite:sdk-for-android:6.1.0`)

---

## Customization

- Update `applicationId` in `android/app/build.gradle` for your package namespace.
- Set up Appwrite or your backend as needed.
- Replace default keystore for release builds as required.

---

## License

This project is licensed under the MIT License.

---

**Happy journaling!**
