import 'package:flutter/material.dart';
import 'package:flutter_social_ui/constants.dart';
import 'package:flutter_social_ui/models/avatar_model.dart';
import 'package:flutter_social_ui/models/post_model.dart';
import 'package:flutter_social_ui/services/search_service.dart';
import 'package:flutter_social_ui/services/content_service.dart';
import 'package:flutter_social_ui/screens/chat_screen.dart';
import 'package:flutter_social_ui/widgets/post_item.dart';
import 'dart:async';

class SearchScreenNew extends StatefulWidget {
  const SearchScreenNew({super.key});

  @override
  _SearchScreenNewState createState() => _SearchScreenNewState();
}

class _SearchScreenNewState extends State<SearchScreenNew> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  final ContentService _contentService = ContentService();
  late TabController _tabController;
  
  List<AvatarModel> _avatarResults = [];
  List<PostModel> _postResults = [];
  List<String> _hashtagResults = [];
  List<String> _trendingHashtags = [];
  
  bool _isSearching = false;
  bool _hasSearched = false;
  String _currentQuery = '';
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
                          prefixIcon: Icon(Icons.search, color: kLightTextColor),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: kLightTextColor),
                                  onPressed: _clearSearch,
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      child: Text('Cancel', style: TextStyle(color: kPrimaryColor)),
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
              child: _hasSearched ? _buildSearchResults() : _buildDiscoverContent(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: kPrimaryColor),
            SizedBox(height: 16),
            Text('Searching...', style: kBodyTextStyle.copyWith(color: kLightTextColor)),
          ],
        ),
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
      return _buildEmptyState('No avatars found', 'Try searching for different keywords');
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
                backgroundImage: avatar.imageUrl != null
                    ? NetworkImage(avatar.imageUrl!)
                    : null,
                child: avatar.imageUrl == null
                    ? Icon(Icons.person, color: kLightTextColor)
                    : null,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(avatar.name, style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold)),
                    Text(avatar.niche.displayName, style: kCaptionTextStyle.copyWith(color: kLightTextColor)),
                    if (avatar.bio.isNotEmpty)
                      Text(
                        avatar.bio,
                        style: kCaptionTextStyle.copyWith(color: kLightTextColor),
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
      return _buildEmptyState('No posts found', 'Try searching for different keywords or hashtags');
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
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      color: kBackgroundColor,
                    ),
                    child: post.hasMedia
                        ? Image.network(post.mediaUrl, fit: BoxFit.cover)
                        : Center(
                            child: Icon(Icons.image, color: kLightTextColor, size: 48),
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
                            style: kCaptionTextStyle.copyWith(color: kLightTextColor),
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
      return _buildEmptyState('No hashtags found', 'Try searching for trending topics');
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtag = _hashtagResults[index];
        return Container(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tag, color: kPrimaryColor),
            ),
            title: Text(hashtag, style: kBodyTextStyle),
            subtitle: Text('Trending hashtag', style: kCaptionTextStyle.copyWith(color: kLightTextColor)),
            trailing: Icon(Icons.arrow_forward_ios, color: kLightTextColor, size: 16),
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
                              style: kCaptionTextStyle.copyWith(fontWeight: FontWeight.bold),
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
          
          // Popular search suggestions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Popular Searches',
              style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          ...['AI avatars', 'Technology', 'Travel', 'Fitness', 'Cooking', 'Art', 'Music']
              .map((suggestion) => ListTile(
                    leading: Icon(Icons.trending_up, color: kPrimaryColor),
                    title: Text(suggestion, style: kBodyTextStyle),
                    trailing: Icon(Icons.arrow_forward_ios, color: kLightTextColor, size: 16),
                    onTap: () => _performSearch(suggestion),
                  )),
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
      final hashtags = await _contentService.getTrendingHashtags(limit: 10);
      setState(() {
        _trendingHashtags = hashtags.map((h) => h['hashtag'].toString()).toList();
      });
    } catch (e) {
      // Use fallback hashtags
      setState(() {
        _trendingHashtags = ['#ai', '#avatar', '#tech', '#creative', '#viral'];
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
      _currentQuery = query;
      _searchController.text = query;
    });
    
    try {
      final results = await Future.wait([
        _searchService.searchAvatars(query: query, limit: 20),
        _searchService.searchPosts(query: query, limit: 20),
        _searchService.searchHashtags(query: query, limit: 20),
      ]);
      
      setState(() {
        _avatarResults = results[0] as List<AvatarModel>;
        _postResults = results[1] as List<PostModel>;
        _hashtagResults = results[2] as List<String>;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search error: $e')),
      );
    }
  }
  
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _hasSearched = false;
      _currentQuery = '';
      _avatarResults.clear();
      _postResults.clear();
      _hashtagResults.clear();
    });
  }
  
  void _searchHashtag(String hashtag) {
    _performSearch(hashtag);
  }
  
  void _navigateToChat(AvatarModel avatar) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          name: avatar.name,
          avatar: avatar.imageUrl ?? 'assets/images/p.jpg',
          avatarId: avatar.id,
        ),
      ),
    );
  }
  
  void _viewPost(PostModel post) {
    // For now, just show a snackbar - could navigate to post detail
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing post: ${post.caption.substring(0, 30)}...')),
    );
  }
  
  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
}
