import 'package:flutter/material.dart';
import 'package:quanta/constants.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/models/post_model.dart';
import 'package:quanta/services/enhanced_search_service.dart';
import 'package:quanta/screens/chat_screen.dart';
import 'package:quanta/screens/enhanced_post_detail_screen.dart';
import 'package:quanta/widgets/skeleton_widgets.dart';
import 'dart:async';

class SearchScreenNew extends StatefulWidget {
  const SearchScreenNew({super.key});

  @override
  State<SearchScreenNew> createState() => _SearchScreenNewState();
}

class _SearchScreenNewState extends State<SearchScreenNew>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final EnhancedSearchService _enhancedSearchService = EnhancedSearchService();
  late TabController _tabController;

  List<AvatarModel> _avatarResults = [];
  List<PostModel> _postResults = [];
  List<Map<String, dynamic>> _hashtagResults = [];
  List<String> _trendingHashtags = [];
  List<String> _popularSearches = [];
  List<String> _recentSearches = [];

  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrendingContent();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: kCardColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: kBodyTextStyle,
                        decoration: InputDecoration(
                          hintText: 'Search avatars, posts, hashtags...',
                          hintStyle: TextStyle(color: kLightTextColor),
                          prefixIcon: Icon(
                            Icons.search,
                            color: kLightTextColor,
                          ),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, child) {
                              return value.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: kLightTextColor,
                                      ),
                                      onPressed: _clearSearch,
                                    )
                                  : const SizedBox.shrink();
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: _onSearchChanged,
                        onSubmitted: _performSearch,
                      ),
                    ),
                  ),
                  if (_hasSearched) ...[
                    SizedBox(width: 8),
                    TextButton(
                      onPressed: _clearSearch,
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: kPrimaryColor),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tab bar (only show when searching)
            if (_hasSearched)
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  labelColor: kPrimaryColor,
                  unselectedLabelColor: kLightTextColor,
                  indicatorColor: kPrimaryColor,
                  tabs: [
                    Tab(text: 'Avatars (${_avatarResults.length})'),
                    Tab(text: 'Posts (${_postResults.length})'),
                    Tab(text: 'Hashtags (${_hashtagResults.length})'),
                  ],
                ),
              ),

            // Content
            Expanded(
              child: _hasSearched
                  ? _buildSearchResults()
                  : _buildDiscoverContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return TabBarView(
        controller: _tabController,
        children: [
          SkeletonLoader.searchResults(itemCount: 6),
          Container(
            padding: EdgeInsets.all(16),
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => Container(
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SkeletonWidget(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonWidget(width: double.infinity, height: 14),
                          SizedBox(height: 4),
                          SkeletonWidget(width: 80, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                6,
                (index) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: SkeletonWidget(
                      width: 40,
                      height: 40,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: SkeletonWidget(width: 120, height: 16),
                    subtitle: SkeletonWidget(width: 80, height: 12),
                    trailing: SkeletonWidget(width: 16, height: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildAvatarResults(),
        _buildPostResults(),
        _buildHashtagResults(),
      ],
    );
  }

  Widget _buildAvatarResults() {
    if (_avatarResults.isEmpty) {
      return _buildEmptyState(
        'No avatars found',
        'Try searching for different keywords',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _avatarResults.length,
      itemBuilder: (context, index) {
        final avatar = _avatarResults[index];
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: avatar.avatarImageUrl != null
                    ? NetworkImage(avatar.avatarImageUrl!)
                    : null,
                child: avatar.avatarImageUrl == null
                    ? Icon(Icons.person, color: kLightTextColor)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avatar.name,
                      style: kBodyTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      avatar.niche.displayName,
                      style: kCaptionTextStyle.copyWith(color: kLightTextColor),
                    ),
                    if (avatar.bio.isNotEmpty)
                      Text(
                        avatar.bio,
                        style: kCaptionTextStyle.copyWith(
                          color: kLightTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _navigateToChat(avatar),
                child: Text('Chat', style: TextStyle(color: kPrimaryColor)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostResults() {
    if (_postResults.isEmpty) {
      return _buildEmptyState(
        'No posts found',
        'Try searching for different keywords or hashtags',
      );
    }

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _postResults.length,
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return GestureDetector(
          onTap: () => _viewPost(post),
          child: Container(
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      color: kBackgroundColor,
                    ),
                    child: post.hasMedia
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                post.type == PostType.video && post.thumbnailUrl != null
                                    ? post.thumbnailUrl!
                                    : post.mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: kLightTextColor,
                                      size: 48,
                                    ),
                                  );
                                },
                              ),
                              if (post.type == PostType.video)
                                Center(
                                  child: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Center(
                            child: Icon(
                              Icons.image,
                              color: kLightTextColor,
                              size: 48,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.caption,
                        style: kCaptionTextStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.favorite, color: kPrimaryColor, size: 14),
                          SizedBox(width: 4),
                          Text(
                            _formatCount(post.likesCount),
                            style: kCaptionTextStyle.copyWith(
                              color: kLightTextColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHashtagResults() {
    if (_hashtagResults.isEmpty) {
      return _buildEmptyState(
        'No hashtags found',
        'Try searching for trending topics',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtagData = _hashtagResults[index];
        final hashtag = hashtagData['hashtag'] as String;
        final count = hashtagData['count'] as int? ?? 0;
        
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPrimaryColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tag, color: kPrimaryColor),
            ),
            title: Text(hashtag, style: kBodyTextStyle),
            subtitle: Text(
              count > 1 ? '$count posts' : '$count post',
              style: kCaptionTextStyle.copyWith(color: kLightTextColor),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: kLightTextColor,
              size: 16,
            ),
            onTap: () => _searchHashtag(hashtag),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trending hashtags
          if (_trendingHashtags.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Trending Hashtags',
                style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _trendingHashtags.length,
                itemBuilder: (context, index) {
                  final hashtag = _trendingHashtags[index];
                  return Container(
                    width: 120,
                    margin: EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: kCardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => _searchHashtag(hashtag),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.tag, color: kPrimaryColor, size: 32),
                            SizedBox(height: 8),
                            Text(
                              hashtag,
                              style: kCaptionTextStyle.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          // Recent searches (if any)
          if (_recentSearches.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Searches',
                    style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: _clearRecentSearches,
                    child: Text(
                      'Clear',
                      style: TextStyle(color: kPrimaryColor, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            ..._recentSearches.take(5).map(
              (recentQuery) => ListTile(
                leading: Icon(Icons.history, color: kLightTextColor),
                title: Text(recentQuery, style: kBodyTextStyle),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: kLightTextColor, size: 16),
                      onPressed: () => _removeRecentSearch(recentQuery),
                      padding: EdgeInsets.all(4),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      color: kLightTextColor,
                      size: 16,
                    ),
                  ],
                ),
                onTap: () => _performSearch(recentQuery),
              ),
            ),
          ],

          // Popular search suggestions
          if (_popularSearches.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'Popular Searches',
                style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ..._popularSearches.map(
              (suggestion) => ListTile(
                leading: Icon(Icons.trending_up, color: kPrimaryColor),
                title: Text(suggestion, style: kBodyTextStyle),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: kLightTextColor,
                  size: 16,
                ),
                onTap: () => _performSearch(suggestion),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: kLightTextColor, size: 64),
          SizedBox(height: 16),
          Text(title, style: kHeadingTextStyle.copyWith(fontSize: 18)),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _loadTrendingContent() async {
    try {
      // Load trending hashtags, popular searches, and recent searches from enhanced service
      final results = await Future.wait([
        _enhancedSearchService.getTrendingHashtags(limit: 20),
        _enhancedSearchService.getPopularSearches(limit: 8),
        _enhancedSearchService.getRecentSearches(limit: 5),
      ]);
      
      setState(() {
        _trendingHashtags = results[0];
        _popularSearches = results[1];
        _recentSearches = results[2];
      });
    } catch (e) {
      debugPrint('Error loading trending content: $e');
      // No fallback content for production - show empty states
      setState(() {
        _trendingHashtags = [];
        _popularSearches = [];
        _recentSearches = [];
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchController.text = query;
    });

    try {
      // Use enhanced search service with automatic tracking
      final searchResults = await _enhancedSearchService.performSearch(
        query,
        limit: 20,
        trackQuery: true,
      );

      setState(() {
        _avatarResults = searchResults.avatars;
        _postResults = searchResults.posts;
        _hashtagResults = searchResults.hashtagsWithCounts;
        _isSearching = false;
      });

      // Show user-friendly error if search failed but we got results
      if (searchResults.hasError && searchResults.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(searchResults.error!),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _hasSearched = false;
      _avatarResults.clear();
      _postResults.clear();
      _hashtagResults.clear();
    });
  }

  void _searchHashtag(String hashtag) {
    _performSearch(hashtag);
  }

  /// Clear all recent searches
  Future<void> _clearRecentSearches() async {
    try {
      await _enhancedSearchService.clearRecentSearches();
      setState(() {
        _recentSearches.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recent searches cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  /// Remove a specific recent search
  Future<void> _removeRecentSearch(String query) async {
    try {
      await _enhancedSearchService.removeRecentSearch(query);
      setState(() {
        _recentSearches.remove(query);
      });
    } catch (e) {
      debugPrint('Error removing recent search: $e');
    }
  }

  void _navigateToChat(AvatarModel avatar) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          name: avatar.name,
          avatar: avatar.avatarImageUrl ?? 'assets/images/p.jpg',
          avatarId: avatar.id,
        ),
      ),
    );
  }

  void _viewPost(PostModel post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EnhancedPostDetailScreen(
          postId: post.id,
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  // This method is no longer needed as we use the enhanced search service directly
  // It's kept for backward compatibility but the enhanced service handles hashtag counts
}
