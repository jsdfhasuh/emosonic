# Color Theme System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a comprehensive color theme system with 6 theme options (深海蓝, 曜石紫, 琥珀橙, 森林绿, 玫瑰红, 石墨灰) that affects the entire app's color scheme.

**Architecture:** Create a `AppColorTheme` model that defines primary background, surface, accent, and text colors for each theme. Use a StateNotifierProvider to manage theme state with SharedPreferences persistence. Update main.dart to use the theme provider for the entire app's ThemeData.

**Tech Stack:** Flutter, Riverpod, SharedPreferences

---

## Task 1: Create Color Theme Model and Provider

**Files:**
- Create: `lib/providers/color_theme_provider.dart`

**Step 1: Define AppColorTheme class**

Create a model that defines colors for each theme:
- backgroundColor (主背景)
- surfaceColor (卡片/表面)
- accentColor (强调色/按钮)
- secondaryAccentColor (次要强调)
- textPrimaryColor (主要文字)
- textSecondaryColor (次要文字)

**Step 2: Define 6 theme presets**

1. Deep Blue (深海蓝): #1E293B bg, #6B8DD6 accent
2. Obsidian Purple (曜石紫): #1E1B2E bg, #9A7BFF accent  
3. Amber Orange (琥珀橙): #2B1C14 bg, #F4A261 accent
4. Forest Green (森林绿): #1B2B23 bg, #6DD6A1 accent
5. Rose Red (玫瑰红): #2B1B22 bg, #FF6B8A accent
6. Graphite Grey (石墨灰): #1C1F24 bg, #8FA1B3 accent

**Step 3: Create provider with persistence**

Use StateNotifierProvider with SharedPreferences to save/load selected theme.

**Step 4: Commit**

```bash
git add lib/providers/color_theme_provider.dart
git commit -m "feat(theme): add color theme provider with 6 presets"
```

---

## Task 2: Update Main App to Use Dynamic Theme

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/providers/providers.dart` (export new provider)

**Step 1: Watch color theme provider**

In main.dart, add watch for the color theme provider and generate ThemeData based on current theme.

**Step 2: Update ThemeData generation**

Replace hardcoded color scheme with dynamic colors from the provider:
- scaffoldBackgroundColor
- primaryColor
- colorScheme (primary, secondary, surface, background)
- appBarTheme
- cardTheme
- iconTheme

**Step 3: Export provider**

Add export to `lib/providers/providers.dart`.

**Step 4: Commit**

```bash
git add lib/main.dart lib/providers/providers.dart
git commit -m "feat(theme): integrate dynamic color theme into app"
```

---

## Task 3: Update Settings Screen Theme Selector

**Files:**
- Modify: `lib/ui/screens/settings_screen.dart`

**Step 1: Replace hardcoded theme tile**

Change "个性化主题" from static text to dynamic consumer that shows current theme name.

**Step 2: Create theme picker dialog**

Show a dialog/bottom sheet with:
- Grid or list of 6 theme options
- Each shows theme name + color preview circle
- Selected theme highlighted

**Step 3: Bind to provider**

On selection, call `ref.read(colorThemeProvider.notifier).setTheme(theme)`.

**Step 4: Add feedback**

Show snackbar: "已切换至[主题名]".

**Step 5: Commit**

```bash
git add lib/ui/screens/settings_screen.dart
git commit -m "feat(settings): add color theme selector with 6 options"
```

---

## Task 4: Update Hardcoded Colors Throughout App

**Files:**
- Search and update: All `Color(0xFF...)` throughout lib/ui/

**Step 1: Identify hardcoded colors**

Find all manual color definitions that should use theme colors:
- AppBar colors
- Card/Container backgrounds  
- Button colors
- Text colors
- Icon colors
- Divider colors

**Step 2: Replace with theme-aware colors**

Use `Theme.of(context)` or ref.watch to get current theme colors:
```dart
final theme = ref.watch(colorThemeProvider);
// or
final colorScheme = Theme.of(context).colorScheme;
```

**Step 3: Key files to check**

- `lib/ui/screens/*.dart`
- `lib/ui/widgets/*.dart`
- `lib/services/*.dart` (if any UI colors)

**Step 4: Commit**

```bash
git add lib/ui/
git commit -m "refactor(ui): replace hardcoded colors with theme-aware colors"
```

---

## Task 5: Test and Verify

**Step 1: Manual testing**

- Open app, verify default theme (Deep Blue)
- Go to Settings → 个性化主题
- Try each theme, verify:
  - Background color changes
  - Accent color changes
  - Text remains readable
  - All screens update
  - Persist after restart

**Step 2: Check specific screens**

- [ ] Player screen
- [ ] Library screen
- [ ] Album detail screen
- [ ] Settings screen
- [ ] MiniPlayer
- [ ] Playlist drawer

**Step 3: Run analysis**

```bash
flutter analyze
```

---

## Color Specifications

### 1. Deep Blue (深海蓝) - Default
- Background: #1E293B
- Surface: #2D3B4E
- Accent: #6B8DD6
- Secondary: #8FA1B3
- Text Primary: #FFFFFF
- Text Secondary: #94A3B8

### 2. Obsidian Purple (曜石紫)
- Background: #1E1B2E
- Surface: #2D2A3E
- Accent: #9A7BFF
- Secondary: #B8A9E8
- Text Primary: #FFFFFF
- Text Secondary: #A69EC0

### 3. Amber Orange (琥珀橙)
- Background: #2B1C14
- Surface: #3D2A1F
- Accent: #F4A261
- Secondary: #E9C46A
- Text Primary: #FFFFFF
- Text Secondary: #D4A574

### 4. Forest Green (森林绿)
- Background: #1B2B23
- Surface: #2A3D33
- Accent: #6DD6A1
- Secondary: #88D4AA
- Text Primary: #FFFFFF
- Text Secondary: #8FAE9C

### 5. Rose Red (玫瑰红)
- Background: #2B1B22
- Surface: #3D2A33
- Accent: #FF6B8A
- Secondary: #FF9AAE
- Text Primary: #FFFFFF
- Text Secondary: #C99AA8

### 6. Graphite Grey (石墨灰)
- Background: #1C1F24
- Surface: #2A2E35
- Accent: #8FA1B3
- Secondary: #A8B5C4
- Text Primary: #FFFFFF
- Text Secondary: #8E99A4

---

## Implementation Notes

1. **Default Theme:** Start with Deep Blue (matches current app)
2. **Migration:** Existing users should see no change (Deep Blue = current colors)
3. **Accessibility:** Ensure contrast ratios meet WCAG guidelines
4. **Persistence:** Save theme index/name to SharedPreferences
5. **Performance:** Theme change should be instant without rebuild flicker
