# EmoSonic

A cross-platform Subsonic music player built with Flutter. Supports Android and Windows.

## Features

- **Subsonic API Support** - Connect to any Subsonic-compatible server (Navidrome, Airsonic, etc.)
- **Cross-Platform** - Available for Android and Windows
- **Background Playback** - Continue playing music when app is in background
- **Media Controls** - System media controls integration (SMTC on Windows, MediaSession on Android)
- **Playlist Management** - Create, edit, and manage playlists
- **Offline Caching** - Album artwork and metadata caching
- **Scrobbling** - Automatic playback tracking

## Screenshots

*Coming soon*

## Download

Download the latest release from [GitHub Releases](../../releases).

### Android

1. Download `app-release.apk` from the latest release
2. Enable "Install from Unknown Sources" in Settings → Security
3. Install the APK
4. Open the app and configure your Subsonic server

### Windows

1. Download `emosonic_windows_v*.zip` from the latest release
2. Extract the ZIP file to your preferred location
3. Run `emosonic.exe`
4. Configure your Subsonic server on first launch

## Building from Source

### Prerequisites

- Flutter SDK 3.24.0 or later
- Android SDK (for Android builds)
- Visual Studio 2022 with C++ workload (for Windows builds)

### Build Commands

```bash
# Get dependencies
flutter pub get

# Build Android APK
flutter build apk --release

# Build Windows executable
flutter build windows --release
```

## Server Configuration

On first launch, you'll need to configure your Subsonic server:

1. **Server URL** - Your Subsonic server address (e.g., `https://music.example.com`)
2. **Username** - Your Subsonic username
3. **Password** - Your Subsonic password

The app will test the connection before saving the configuration.

## Supported Subsonic Servers

- [Navidrome](https://www.navidrome.org/)
- [Airsonic](https://airsonic.github.io/)
- [Supysonic](https://github.com/spl0k/supysonic)
- Any server implementing the Subsonic API

## Development

### Project Structure

```
lib/
├── core/           # Utilities, constants, extensions
├── data/           # Models, API clients, repositories
├── providers/      # Riverpod state management
├── services/       # Audio playback, media controls
└── ui/             # Screens and widgets
```

### Running Tests

```bash
flutter test
```

## CI/CD

This project uses GitHub Actions for automated builds:

- **Automatic builds** on version tags (`v*`)
- **Manual builds** via workflow dispatch
- **Multi-platform** - Android and Windows builds
- **Automatic releases** with artifacts

### GitHub Secrets

For automatic server URL injection in CI builds:

1. Go to Settings → Secrets and variables → Actions
2. Add `SONIC_SERVER_URL` with your server address
3. The build will automatically inject this URL as the default

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Built with [Flutter](https://flutter.dev/)
- Audio playback powered by [just_audio](https://pub.dev/packages/just_audio)
- State management with [Riverpod](https://riverpod.dev/)
