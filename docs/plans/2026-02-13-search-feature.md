# 搜索功能实施计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**目标:** 实现完整的搜索功能，支持搜索歌曲、专辑、艺术家，并保存搜索历史

**架构:** 
- 使用 Subsonic API search3 端点获取搜索结果
- 使用 shared_preferences 本地存储搜索历史
- 创建独立的搜索结果页面，使用 TabBar 分栏展示

**技术栈:** Flutter, Riverpod, Subsonic API, shared_preferences

---

## 需求确认

1. **搜索范围**: 歌曲 + 专辑 + 艺术家
2. **展示形式**: 分栏列表（艺术家/专辑/歌曲三栏Tab）
3. **触发方式**:
   - 发现页: 搜索框输入后按回车
   - 音乐库: 点击搜索图标
4. **搜索历史**: 保存最近 10 条搜索记录，使用 shared_preferences
5. **不需要**: 加载更多功能

---

## Task 1: 创建 SearchResult 数据模型

**文件:**
- 创建: `lib/data/models/search_result.dart`
- 测试: 在 `test/models/search_result_test.dart` 添加测试

**步骤 1: 编写失败的测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sonic_player/data/models/search_result.dart';
import 'package:sonic_player/data/models/models.dart';

void main() {
  group('SearchResult', () {
    test('should create SearchResult from JSON', () {
      final json = {
        'artist': [
          {'id': '1', 'name': 'Artist 1'},
        ],
        'album': [
          {'id': '2', 'name': 'Album 1', 'artistId': '1', 'artist': 'Artist 1'},
        ],
        'song': [
          {'id': '3', 'title': 'Song 1', 'albumId': '2', 'album': 'Album 1', 'artistId': '1', 'artist': 'Artist 1'},
        ],
      };

      final result = SearchResult.fromJson(json);

      expect(result.artists.length, 1);
      expect(result.albums.length, 1);
      expect(result.songs.length, 1);
      expect(result.artists.first.name, 'Artist 1');
      expect(result.albums.first.name, 'Album 1');
      expect(result.songs.first.title, 'Song 1');
    });

    test('should handle empty results', () {
      final json = <String, dynamic>{};

      final result = SearchResult.fromJson(json);

      expect(result.artists, isEmpty);
      expect(result.albums, isEmpty);
      expect(result.songs, isEmpty);
    });
  });
}
```

**步骤 2: 运行测试验证失败**

运行: `flutter test test/models/search_result_test.dart`
预期: FAIL - "SearchResult not found"

**步骤 3: 实现 SearchResult 类**

```dart
import 'models.dart';

class SearchResult {
  final List<Artist> artists;
  final List<Album> albums;
  final List<Song> songs;

  const SearchResult({
    required this.artists,
    required this.albums,
    required this.songs,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final artists = <Artist>[];
    final albums = <Album>[];
    final songs = <Song>[];

    if (json['artist'] != null) {
      for (final artist in json['artist']) {
        try {
          artists.add(Artist.fromJson(artist));
        } catch (e) {
          // Log error but continue processing
        }
      }
    }

    if (json['album'] != null) {
      for (final album in json['album']) {
        try {
          albums.add(Album.fromJson(album));
        } catch (e) {
          // Log error but continue processing
        }
      }
    }

    if (json['song'] != null) {
      for (final song in json['song']) {
        try {
          songs.add(Song.fromJson(song));
        } catch (e) {
          // Log error but continue processing
        }
      }
    }

    return SearchResult(
      artists: artists,
      albums: albums,
      songs: songs,
    );
  }
}
```

**步骤 4: 运行测试验证通过**

运行: `flutter test test/models/search_result_test.dart`
预期: PASS

**步骤 5: 提交**

```bash
git add lib/data/models/search_result.dart test/models/search_result_test.dart
git commit -m "feat: add SearchResult model for search functionality"
```

---

## Task 2: 扩展 API 搜索方法

**文件:**
- 修改: `lib/data/services/subsonic/subsonic_api_client.dart`

**步骤 1: 修改 search 方法**

将现有的 `search` 方法从返回 `List<Song>` 改为返回 `SearchResult`:

```dart
Future<SearchResult> search(String query) async {
  _logger.info('Searching for: $query');
  final response = await _get('search3', params: {
    'query': query,
    'artistCount': 20,
    'albumCount': 20,
    'songCount': 50,
  });
  
  final searchResult = response['searchResult3'];
  if (searchResult != null) {
    return SearchResult.fromJson(searchResult);
  }
  
  return const SearchResult(artists: [], albums: [], songs: []);
}
```

**步骤 2: 更新 Provider**

修改 `lib/providers/providers.dart` 中的 searchProvider:

```dart
final searchProvider = FutureProvider.family<SearchResult, String>((ref, query) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.search(query);
});
```

**步骤 3: 运行测试**

运行: `flutter analyze`
预期: No errors

**步骤 4: 提交**

```bash
git add lib/data/services/subsonic/subsonic_api_client.dart lib/providers/providers.dart
git commit -m "feat: extend search API to return artists, albums and songs"
```

---

## Task 3: 添加搜索历史 Provider

**文件:**
- 修改: `lib/providers/providers.dart`

**步骤 1: 创建搜索历史 Provider**

```dart
// Search History Provider
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const String _prefsKey = 'search_history';
  static const int _maxHistory = 10;

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_prefsKey) ?? [];
    state = history;
  }

  Future<void> addSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    final newHistory = [query, ...state.where((q) => q != query)];
    if (newHistory.length > _maxHistory) {
      newHistory.removeLast();
    }
    
    state = newHistory;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, newHistory);
  }

  Future<void> clearHistory() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
```

**步骤 2: 添加 SharedPreferences 导入**

在 providers.dart 顶部添加:
```dart
import 'package:shared_preferences/shared_preferences.dart';
```

**步骤 3: 运行测试**

运行: `flutter analyze`
预期: No errors

**步骤 4: 提交**

```bash
git add lib/providers/providers.dart
git commit -m "feat: add search history provider with local storage"
```

---

## Task 4: 创建搜索结果页面

**文件:**
- 创建: `lib/ui/screens/search_results_screen.dart`

**步骤 1: 创建基础页面结构**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/models.dart';
import '../../providers/providers.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String query;

  const SearchResultsScreen({
    super.key,
    required this.query,
  });

  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchProvider(widget.query));

    return Scaffold(
      appBar: AppBar(
        title: Text('搜索: ${widget.query}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '艺术家'),
            Tab(text: '专辑'),
            Tab(text: '歌曲'),
          ],
        ),
      ),
      body: searchResults.when(
        data: (result) => TabBarView(
          controller: _tabController,
          children: [
            _buildArtistsList(result.artists),
            _buildAlbumsList(result.albums),
            _buildSongsList(result.songs),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('搜索失败: $error'),
        ),
      ),
    );
  }

  Widget _buildArtistsList(List<Artist> artists) {
    if (artists.isEmpty) {
      return const Center(child: Text('没有找到艺术家'));
    }
    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(artist.name),
          onTap: () {
            // Navigate to artist detail
          },
        );
      },
    );
  }

  Widget _buildAlbumsList(List<Album> albums) {
    if (albums.isEmpty) {
      return const Center(child: Text('没有找到专辑'));
    }
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return ListTile(
          leading: const Icon(Icons.album),
          title: Text(album.name),
          subtitle: Text(album.artistName),
          onTap: () {
            // Navigate to album detail
          },
        );
      },
    );
  }

  Widget _buildSongsList(List<Song> songs) {
    if (songs.isEmpty) {
      return const Center(child: Text('没有找到歌曲'));
    }
    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return ListTile(
          leading: const Icon(Icons.music_note),
          title: Text(song.title),
          subtitle: Text(song.artistName),
          onTap: () {
            // Play song
          },
        );
      },
    );
  }
}
```

**步骤 2: 运行测试**

运行: `flutter analyze`
预期: No errors

**步骤 3: 提交**

```bash
git add lib/ui/screens/search_results_screen.dart
git commit -m "feat: create search results screen with tabbed interface"
```

---

## Task 5: 实现发现页搜索

**文件:**
- 修改: `lib/ui/screens/discovery_screen.dart`

**步骤 1: 修改搜索框 onSubmitted**

找到 `_buildSearchBar` 方法，修改 `onSubmitted`:

```dart
onSubmitted: (query) {
  if (query.isNotEmpty) {
    // Save to search history
    ref.read(searchHistoryProvider.notifier).addSearch(query);
    
    // Navigate to search results
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(query: query),
      ),
    );
  }
},
```

**步骤 2: 添加导入**

```dart
import 'search_results_screen.dart';
```

**步骤 3: 运行测试**

运行: `flutter analyze`
预期: No errors

**步骤 4: 提交**

```bash
git add lib/ui/screens/discovery_screen.dart
git commit -m "feat: implement search from discovery screen"
```

---

## Task 6: 实现音乐库搜索

**文件:**
- 修改: `lib/ui/screens/library_screen.dart`

**步骤 1: 修改搜索按钮点击事件**

找到搜索按钮的 `onPressed`，修改为:

```dart
IconButton(
  icon: const Icon(Icons.search),
  onPressed: () {
    _showSearchDialog(context, ref);
  },
),
```

**步骤 2: 添加搜索对话框方法**

```dart
void _showSearchDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('搜索'),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入搜索关键词...',
            prefixIcon: Icon(Icons.search),
          ),
          onSubmitted: (query) {
            if (query.isNotEmpty) {
              Navigator.pop(context);
              ref.read(searchHistoryProvider.notifier).addSearch(query);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchResultsScreen(query: query),
                ),
              );
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
}
```

**步骤 3: 添加导入**

```dart
import 'search_results_screen.dart';
```

**步骤 4: 运行测试**

运行: `flutter analyze`
预期: No errors

**步骤 5: 提交**

```bash
git add lib/ui/screens/library_screen.dart
git commit -m "feat: implement search from library screen"
```

---

## Task 7: 添加搜索历史 UI

**文件:**
- 修改: `lib/ui/screens/search_results_screen.dart`

**步骤 1: 添加搜索历史显示**

在 SearchResultsScreen 中添加搜索历史显示区域（当搜索框为空时显示）:

由于我们已经从发现页/音乐库传递了 query，搜索历史应该在搜索对话框或发现页显示。让我们修改方案：

在发现页的搜索框下方添加搜索历史:

修改 `discovery_screen.dart` 的 `_buildSearchBar` 方法，在 TextField 下方添加历史记录:

```dart
Consumer(
  builder: (context, ref, child) {
    final searchHistory = ref.watch(searchHistoryProvider);
    if (searchHistory.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '搜索历史',
                style: TextStyle(
                  color: Colors.white.withAlpha(179),
                  fontSize: 12,
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(searchHistoryProvider.notifier).clearHistory();
                },
                child: const Text('清除', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            children: searchHistory.map((query) {
              return ActionChip(
                label: Text(query),
                onPressed: () {
                  // Navigate to search results with this query
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SearchResultsScreen(query: query),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  },
)
```

**步骤 2: 运行测试**

运行: `flutter analyze`
预期: No errors

**步骤 3: 提交**

```bash
git add lib/ui/screens/discovery_screen.dart
git commit -m "feat: add search history UI to discovery screen"
```

---

## 最终验证

所有任务完成后:

1. 运行完整测试: `flutter test`
2. 运行静态分析: `flutter analyze`
3. 手动测试搜索功能
4. 提交最终更改

---

## 注意事项

1. **错误处理**: 所有 API 调用都有 try-catch，避免崩溃
2. **空状态**: 每个列表都有空状态提示
3. **加载状态**: 使用 CircularProgressIndicator
4. **性能**: 使用 const 构造函数和 ListView.builder
5. **代码质量**: 遵循现有代码风格
