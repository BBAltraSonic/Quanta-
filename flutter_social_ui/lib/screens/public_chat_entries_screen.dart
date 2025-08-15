import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quanta/constants.dart';
import 'package:quanta/services/messages_service.dart';
import 'package:quanta/services/avatar_service.dart';
import 'package:quanta/models/avatar_model.dart';
import 'package:quanta/widgets/skeleton_widgets.dart';
import 'package:timeago/timeago.dart' as timeago;

class PublicChatEntriesScreen extends StatefulWidget {
  const PublicChatEntriesScreen({super.key});

  @override
  _PublicChatEntriesScreenState createState() => _PublicChatEntriesScreenState();
}

class _PublicChatEntriesScreenState extends State<PublicChatEntriesScreen>
    with SingleTickerProviderStateMixin {
  final MessagesService _messagesService = MessagesService();
  final AvatarService _avatarService = AvatarService();
  
  late TabController _tabController;
  
  List<PublicChatEntry> _avatarEntries = [];
  List<PublicChatEntry> _creatorEntries = [];
  List<PublicChatEntry> _searchResults = [];
  
  final Map<String, AvatarModel> _avatarCache = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPublicEntries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPublicEntries() async {
    setState(() => _isLoading = true);
    
    try {
      final entries = await _messagesService.getUserPublicChats();
      
      // Cache avatars
      final avatarIds = entries.map((e) => e.avatarId).toSet();
      for (final avatarId in avatarIds) {
        if (!_avatarCache.containsKey(avatarId)) {
          final avatar = await _avatarService.getAvatarById(avatarId);
          if (avatar != null) {
            _avatarCache[avatarId] = avatar;
          }
        }
      }
      
      setState(() {
        _avatarEntries = entries.where((e) => e.visibility == 'avatar').toList();
        _creatorEntries = entries.where((e) => e.visibility == 'creator').toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading public entries: $e');
      setState(() {
        _avatarEntries = [];
        _creatorEntries = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshEntries() async {
    setState(() => _isRefreshing = true);
    await _loadPublicEntries();
    setState(() => _isRefreshing = false);
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }

    _searchDebounce = Timer(Duration(milliseconds: 300), () async {
      setState(() => _isSearching = true);
      try {
        final allEntries = [..._avatarEntries, ..._creatorEntries];
        final results = allEntries.where((entry) {
          final avatar = _avatarCache[entry.avatarId];
          final avatarName = avatar?.name.toLowerCase() ?? '';
          final messageText = entry.messageText.toLowerCase();
          final query = value.toLowerCase();
          
          return avatarName.contains(query) || messageText.contains(query);
        }).toList();
        
        if (!mounted) return;
        setState(() {
          _searchResults = results;
        });
      } catch (e) {
        debugPrint('Search error: $e');
      } finally {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Public Conversations',
          style: kHeadingTextStyle.copyWith(fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(100),
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: kBodyTextStyle,
                  decoration: InputDecoration(
                    hintText: 'Search public conversations',
                    hintStyle: kCaptionTextStyle.copyWith(color: kLightTextColor),
                    filled: true,
                    fillColor: kCardColor,
                    prefixIcon: Icon(Icons.search, color: kLightTextColor),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: kLightTextColor),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _isSearching = false;
                                _searchResults = [];
                              });
                            },
                          )
                        : null,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: kPrimaryColor),
                    ),
                  ),
                ),
              ),
              
              // Tab bar
              if (_searchController.text.isEmpty)
                TabBar(
                  controller: _tabController,
                  labelColor: kPrimaryColor,
                  unselectedLabelColor: kLightTextColor,
                  indicatorColor: kPrimaryColor,
                  tabs: [
                    Tab(text: 'Avatar Showcase (${_avatarEntries.length})'),
                    Tab(text: 'Creator Portfolio (${_creatorEntries.length})'),
                  ],
                ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _refreshEntries,
              color: kPrimaryColor,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (_searchController.text.isNotEmpty) {
      return _buildSearchResults();
    }
    
    return TabBarView(
      controller: _tabController,
      children: [
        _buildEntriesList(_avatarEntries, 'avatar'),
        _buildEntriesList(_creatorEntries, 'creator'),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Column(
        children: [
          LinearProgressIndicator(minHeight: 2, color: kPrimaryColor),
          Expanded(child: _buildLoadingState()),
        ],
      );
    }
    
    if (_searchResults.isEmpty) {
      return _buildEmptyState(isSearch: true);
    }
    
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildEntryCard(_searchResults[index]);
      },
    );
  }

  Widget _buildEntriesList(List<PublicChatEntry> entries, String type) {
    if (entries.isEmpty) {
      return _buildEmptyState(type: type);
    }

    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: entries.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _buildEntryCard(entries[index]);
      },
    );
  }

  Widget _buildEntryCard(PublicChatEntry entry) {
    final avatar = _avatarCache[entry.avatarId];
    
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with avatar and info
            Row(
              children: [
                // Avatar image
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: avatar?.avatarImageUrl != null
                        ? Image.network(
                            avatar!.avatarImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.smart_toy,
                              color: kPrimaryColor,
                              size: 20,
                            ),
                          )
                        : Icon(
                            Icons.smart_toy,
                            color: kPrimaryColor,
                            size: 20,
                          ),
                  ),
                ),
                
                SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avatar?.name ?? 'Unknown Avatar',
                        style: kBodyTextStyle.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${_getVisibilityLabel(entry.visibility)} • ${timeago.format(entry.createdAt)}',
                        style: kCaptionTextStyle.copyWith(color: kLightTextColor),
                      ),
                    ],
                  ),
                ),
                
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: kLightTextColor),
                  color: kCardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'change_visibility',
                      child: Row(
                        children: [
                          Icon(Icons.swap_horiz, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Change Visibility', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'make_private',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Make Private', style: TextStyle(color: Colors.orange)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (action) => _handleEntryAction(entry, action),
                ),
              ],
            ),
            
            SizedBox(height: 12),
            
            // Message content
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You:',
                    style: kCaptionTextStyle.copyWith(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    entry.messageText,
                    style: kBodyTextStyle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  if (entry.avatarResponse != null) ...[
                    SizedBox(height: 8),
                    Divider(color: Colors.white.withOpacity(0.1)),
                    SizedBox(height: 8),
                    Text(
                      '${avatar?.name ?? 'Avatar'}:',
                      style: kCaptionTextStyle.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      entry.avatarResponse!,
                      style: kBodyTextStyle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SkeletonLoader.notificationList(itemCount: 6);
  }

  Widget _buildEmptyState({String? type, bool isSearch = false}) {
    if (isSearch) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: kLightTextColor),
            SizedBox(height: 16),
            Text(
              'No matching conversations',
              style: kHeadingTextStyle.copyWith(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Try different search terms',
              style: kBodyTextStyle.copyWith(color: kLightTextColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    
    final isAvatar = type == 'avatar';
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isAvatar ? Icons.smart_toy : Icons.person,
            size: 64,
            color: kLightTextColor,
          ),
          SizedBox(height: 16),
          Text(
            isAvatar
                ? 'No Avatar Showcase entries'
                : 'No Creator Portfolio entries',
            style: kHeadingTextStyle.copyWith(fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            isAvatar
                ? 'Make conversations public as "Avatar Showcase"\nto display them on avatar profiles.'
                : 'Make conversations public as "Creator Portfolio"\nto showcase them on your profile.',
            style: kBodyTextStyle.copyWith(color: kLightTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getVisibilityLabel(String visibility) {
    switch (visibility) {
      case 'avatar':
        return 'Avatar Showcase';
      case 'creator':
        return 'Creator Portfolio';
      default:
        return 'Public';
    }
  }

  void _handleEntryAction(PublicChatEntry entry, String action) {
    switch (action) {
      case 'change_visibility':
        _showChangeVisibilityDialog(entry);
        break;
      case 'make_private':
        _showMakePrivateDialog(entry);
        break;
    }
  }

  void _showChangeVisibilityDialog(PublicChatEntry entry) {
    final currentVisibility = entry.visibility;
    final newVisibility = currentVisibility == 'avatar' ? 'creator' : 'avatar';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(
          'Change Visibility',
          style: kHeadingTextStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Move this conversation from ${_getVisibilityLabel(currentVisibility)} to ${_getVisibilityLabel(newVisibility)}?',
          style: kBodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: kLightTextColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _changeVisibility(entry, newVisibility);
            },
            child: Text('Move', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  void _showMakePrivateDialog(PublicChatEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(
          'Make Private',
          style: kHeadingTextStyle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Remove this conversation from public visibility? It will no longer be displayed publicly.',
          style: kBodyTextStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: kLightTextColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _makePrivate(entry);
            },
            child: Text('Make Private', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _changeVisibility(PublicChatEntry entry, String newVisibility) async {
    try {
      // Delete old entry and create new one with different visibility
      await _messagesService.makeMessagePrivate(entry.id);
      
      final result = await _messagesService.makeMessagePublic(
        sessionId: entry.sessionId,
        messageId: entry.messageId,
        visibility: newVisibility,
      );
      
      if (result != null) {
        await _refreshEntries();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to ${_getVisibilityLabel(newVisibility)}'),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        throw Exception('Failed to change visibility');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change visibility'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _makePrivate(PublicChatEntry entry) async {
    try {
      final success = await _messagesService.makeMessagePrivate(entry.id);
      
      if (success) {
        await _refreshEntries();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Conversation made private'),
            backgroundColor: Colors.green[700],
          ),
        );
      } else {
        throw Exception('Failed to make private');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to make conversation private'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }
}
