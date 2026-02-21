# 修复搜索页面导航和 MiniPlayer 显示问题

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标:** 将 SearchResultsScreen 集成到 MainScreen 的导航系统中，修复点击跳转和 MiniPlayer 显示问题

**架构:** 
- 添加 `PageType.searchResults` 到导航枚举
- 在 `NavigationState` 中添加 `searchQuery` 字段
- 修改发现页和音乐库的搜索，使用 `navigationProvider` 导航
- 在 MainScreen 中添加 SearchResultsScreen 的条件渲染

**技术栈:** Flutter, Riverpod

---

## 需求确认

1. **问题 1**: 搜索页面点击艺术家/专辑无法跳转
   - 原因：SearchResultsScreen 是独立页面，不在 MainScreen 的 Stack 中
   - 解决：集成到导航系统，使用 navigationProvider

2. **问题 2**: MiniPlayer 不显示
   - 原因：SearchResultsScreen 不在 MainScreen 的 widget 树中
   - 解决：集成到 MainScreen 后，MiniPlayer 会自动显示

---

## Task 1: 扩展 Navigation 枚举和状态

**文件:**
- 修改: `lib/providers/navigation_provider.dart`

**步骤 1: 添加 PageType.searchResults**

在 PageType 枚举中添加：
```dart
enum PageType {
  discovery,
  library,
  player,
  settings,
  album,
  songs,
  genreDetail,
  playlistDetail,
  searchResults, // 新增
}
```

**步骤 2: 在 NavigationState 中添加 searchQuery**

```dart
class NavigationState {
  final PageType currentPage;
  final Artist? selectedArtist;
  final Album? selectedAlbum;
  final String? selectedGenre;
  final Playlist? selectedPlaylist;
  final String? searchQuery; // 新增
  final LibraryTargetCategory? libraryTargetCategory;
  final List<NavigationHistoryItem> pageStack;

  const NavigationState({
    required this.currentPage,
    this.selectedArtist,
    this.selectedAlbum,
    this.selectedGenre,
    this.selectedPlaylist,
    this.searchQuery, // 新增
    this.libraryTargetCategory,
    this.pageStack = const [],
  });

  NavigationState copyWith({
    PageType? currentPage,
    Artist? selectedArtist,
    Album? selectedAlbum,
    String? selectedGenre,
    Playlist? selectedPlaylist,
    String? searchQuery, // 新增
    LibraryTargetCategory? libraryTargetCategory,
    List<NavigationHistoryItem>? pageStack,
  }) {
    return NavigationState(
      currentPage: currentPage ?? this.currentPage,
      selectedArtist: selectedArtist ?? this.selectedArtist,
      selectedAlbum: selectedAlbum ?? this.selectedAlbum,
      selectedGenre: selectedGenre ?? this.selectedGenre,
      selectedPlaylist: selectedPlaylist ?? this.selectedPlaylist,
      searchQuery: searchQuery ?? this.searchQuery, // 新增
      libraryTargetCategory: libraryTargetCategory ?? this.libraryTargetCategory,
      pageStack: pageStack ?? this.pageStack,
    );
  }
}
```

**步骤 3: 添加 pushSearchResults 方法**

```dart
void pushSearchResults(String query) {
  state = state.copyWith(
    currentPage: PageType.searchResults,
    searchQuery: query,
    pageStack: [
      ...state.pageStack,
      NavigationHistoryItem(
        pageType: state.currentPage,
        libraryCategory: state.libraryTargetCategory,
        selectedArtist: state.selectedArtist,
        selectedAlbum: state.selectedAlbum,
        selectedGenre: state.selectedGenre,
        selectedPlaylist: state.selectedPlaylist,
      ),
    ],
  );
}
```

**步骤 4: 运行静态分析**

运行: `flutter analyze lib/providers/navigation_provider.dart`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/providers/navigation_provider.dart
git commit -m "feat: add searchResults page type and navigation"
```

---

## Task 2: 修改 MainScreen 添加 SearchResultsScreen

**文件:**
- 修改: `lib/main.dart`

**步骤 1: 导入 SearchResultsScreen**

```dart
import 'ui/screens/search_results_screen.dart';
```

**步骤 2: 在 Stack 中添加 SearchResultsScreen 条件渲染**

在 Stack 的 children 中，添加：

```dart
if (navigation.currentPage == PageType.searchResults &&
    navigation.searchQuery != null)
  SearchResultsScreen(
    query: navigation.searchQuery!,
    onBack: () => navigationNotifier.pop(),
  ),
```

位置：在 playlistDetail 之后，MiniPlayer 之前

**步骤 3: 修改 _buildMainContent 处理 searchResults**

在 default case 中，添加对 searchResults 的处理：

```dart
default:
  // For sub-pages, show the corresponding main page
  if (page == PageType.album ||
      page == PageType.songs ||
      page == PageType.genreDetail ||
      page == PageType.playlistDetail ||
      page == PageType.searchResults) { // 添加 searchResults
    // Return to the previous main page (from pageStack)
    final navigation = ref.read(navigationProvider);
    if (navigation.pageStack.isNotEmpty) {
      final mainPage = navigation.pageStack.last.pageType;
      // Only recurse if it's a main page
      if (mainPage == PageType.discovery ||
          mainPage == PageType.library ||
          mainPage == PageType.player ||
          mainPage == PageType.settings) {
        return _buildMainContent(mainPage, visited);
      }
    }
    return const DiscoveryScreen();
  }
  return const DiscoveryScreen();
```

**步骤 4: 运行静态分析**

运行: `flutter analyze lib/main.dart`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/main.dart
git commit -m "feat: integrate SearchResultsScreen into MainScreen navigation"
```

---

## Task 3: 修改 SearchResultsScreen 支持 onBack 回调

**文件:**
- 修改: `lib/ui/screens/search_results_screen.dart`

**步骤 1: 添加 onBack 参数**

```dart
class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;
  final VoidCallback? onBack; // 新增

  const SearchResultsScreen({
    super.key,
    required this.query,
    this.onBack, // 新增
  });
```

**步骤 2: 修改 AppBar 添加返回按钮**

```dart
appBar: AppBar(
  title: Text('搜索: ${widget.query}'),
  leading: widget.onBack != null
      ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        )
      : null,
  bottom: TabBar(
    controller: _tabController,
    tabs: const [
      Tab(text: '艺术家'),
      Tab(text: '专辑'),
      Tab(text: '歌曲'),
    ],
  ),
),
```

**步骤 3: 修改点击跳转逻辑**

由于现在 SearchResultsScreen 在 MainScreen 的 Stack 中，点击艺术家/专辑时：
- 不需要关闭 SearchResultsScreen
- 直接调用 navigationProvider 的 push 方法
- 新的页面会显示在 SearchResultsScreen 之上

保持现有的点击逻辑即可：
```dart
// 艺术家点击
ref.read(navigationProvider.notifier).pushAlbumPage(artist);

// 专辑点击
ref.read(navigationProvider.notifier).pushSongPage(album);
```

**步骤 4: 运行静态分析**

运行: `flutter analyze lib/ui/screens/search_results_screen.dart`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/ui/screens/search_results_screen.dart
git commit -m "feat: add onBack callback to SearchResultsScreen"
```

---

## Task 4: 修改发现页搜索使用 navigationProvider

**文件:**
- 修改: `lib/ui/screens/discovery_screen.dart`

**步骤 1: 修改 onSubmitted 回调**

```dart
onSubmitted: (query) {
  if (query.isNotEmpty) {
    // Save to search history
    ref.read(searchHistoryProvider.notifier).addSearch(query);
    
    // Navigate to search results using navigationProvider
    ref.read(navigationProvider.notifier).pushSearchResults(query);
  }
},
```

**步骤 2: 修改历史标签点击**

```dart
onPressed: () {
  ref.read(navigationProvider.notifier).pushSearchResults(query);
},
```

**步骤 3: 删除不必要的导入**

删除：
```dart
import 'search_results_screen.dart';
```

**步骤 4: 运行静态分析**

运行: `flutter analyze lib/ui/screens/discovery_screen.dart`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/ui/screens/discovery_screen.dart
git commit -m "refactor: use navigationProvider for search in discovery"
```

---

## Task 5: 修改音乐库搜索使用 navigationProvider

**文件:**
- 修改: `lib/ui/screens/library_screen.dart`

**步骤 1: 修改 _showSearchDialog 中的导航**

```dart
onSubmitted: (query) {
  if (query.isNotEmpty) {
    Navigator.pop(context); // 关闭对话框
    ref.read(searchHistoryProvider.notifier).addSearch(query);
    // 使用 navigationProvider 导航
    ref.read(navigationProvider.notifier).pushSearchResults(query);
  }
},
```

**步骤 2: 删除不必要的导入**

删除：
```dart
import 'search_results_screen.dart';
```

**步骤 3: 运行静态分析**

运行: `flutter analyze lib/ui/screens/library_screen.dart`
预期: No errors

**步骤 4: 提交**

```bash
git add lib/ui/screens/library_screen.dart
git commit -m "refactor: use navigationProvider for search in library"
```

---

## Task 6: 修复 pop() 方法恢复 searchQuery

**文件:**
- 修改: `lib/providers/navigation_provider.dart`

**步骤 1: 修改 pop() 方法**

在 pop() 方法中，恢复 searchQuery：

```dart
void pop() {
  if (state.pageStack.isNotEmpty) {
    final previousItem = state.pageStack.last;
    final newStack = state.pageStack.sublist(0, state.pageStack.length - 1);

    state = NavigationState(
      currentPage: previousItem.pageType,
      pageStack: newStack,
      libraryTargetCategory: previousItem.libraryCategory,
      selectedArtist: previousItem.selectedArtist,
      selectedAlbum: previousItem.selectedAlbum,
      selectedGenre: previousItem.selectedGenre,
      selectedPlaylist: previousItem.selectedPlaylist,
      // searchQuery 设为 null，因为返回后不再处于搜索页面
      searchQuery: null,
    );
  }
}
```

**步骤 2: 运行静态分析**

运行: `flutter analyze lib/providers/navigation_provider.dart`
预期: No errors

**步骤 3: 提交**

```bash
git add lib/providers/navigation_provider.dart
git commit -m "fix: clear searchQuery when popping from search results"
```

---

## Task 7: 最终验证

**步骤 1: 运行所有测试**

```bash
flutter test
```
预期: All tests pass

**步骤 2: 运行静态分析**

```bash
flutter analyze
```
预期: No issues found

**步骤 3: 手动测试验证**

1. 在发现页搜索，检查：
   - 能正常跳转到搜索结果页
   - MiniPlayer 显示正常
   - 搜索历史显示正常
   - 点击历史能跳转到搜索结果

2. 在音乐库搜索，检查：
   - 对话框正常显示
   - 搜索后能跳转到结果页
   - MiniPlayer 显示正常

3. 在搜索结果页，检查：
   - 点击艺术家能跳转到艺术家详情
   - 点击专辑能跳转到专辑详情
   - 点击歌曲能播放
   - 返回按钮能正常返回
   - MiniPlayer 始终显示

**步骤 4: 提交最终更改**

```bash
git commit -m "feat: integrate search results into main navigation system"
```

---

## 注意事项

1. **向后兼容**: 确保修改不影响现有的 Album/Songs/PlaylistDetail 页面
2. **状态管理**: 使用 navigationProvider 管理所有导航状态
3. **MiniPlayer**: 集成到 MainScreen 后，MiniPlayer 会自动显示
4. **返回逻辑**: 确保从搜索结果返回时能正确回到之前的页面
