# Auto Resume Toggle Binding Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Bind the "启动自动播放" switch in Settings to the auto-resume playback provider with user feedback.

**Architecture:** Wire the UI switch to `autoResumePlaybackProvider` so it reflects persisted state and updates via `setEnabled`. Use the existing `showTopSnackBar` helper for user feedback. Keep changes minimal and isolated to the settings screen.

**Tech Stack:** Flutter, Riverpod, SharedPreferences

---

### Task 1: Bind the auto-resume switch to provider state

**Files:**
- Modify: `lib/ui/screens/settings_screen.dart`

**Step 1: Replace the hardcoded switch with a Consumer**

Find the "启动自动播放" switch (currently `value: false`, `onChanged: (value) {}`) and replace it with:

```dart
          Consumer(
            builder: (context, ref, child) {
              final autoResumeEnabled = ref.watch(autoResumePlaybackProvider);
              return _buildSwitchTile(
                '启动自动播放',
                '应用启动时继续上次播放',
                autoResumeEnabled,
                (value) async {
                  await ref
                      .read(autoResumePlaybackProvider.notifier)
                      .setEnabled(value);
                  if (context.mounted) {
                    showTopSnackBar(
                      context,
                      message: value ? '已开启启动自动播放' : '已关闭启动自动播放',
                    );
                  }
                },
              );
            },
          ),
```

**Step 2: Ensure imports are still valid**

`settings_screen.dart` already imports `../../providers/providers.dart` and `snackbar_utils.dart`, so no new import is expected.

---

### Task 2: Manual verification

**Step 1: Manual test**

- Open Settings → 播放控制
- Toggle "启动自动播放"
- Expected: switch state changes and a snackbar shows

**Step 2: Persist check**

- Close and reopen the app
- Expected: switch retains the last value

---

### Task 3: Commit

```bash
git add lib/ui/screens/settings_screen.dart
git commit -m "feat(settings): bind auto resume toggle to provider"
```
