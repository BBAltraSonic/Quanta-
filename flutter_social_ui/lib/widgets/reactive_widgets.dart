import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../store/app_state.dart';
import '../store/state_service_adapter.dart';
import '../models/post_model.dart';
import '../models/avatar_model.dart';
import '../models/comment.dart';

/// A reactive builder that rebuilds when specific parts of the app state change
class StateSelector<T> extends StatefulWidget {
  final T Function(StateServiceAdapter state) selector;
  final Widget Function(BuildContext context, T value, Widget? child) builder;
  final Widget? child;

  const StateSelector({
    super.key,
    required this.selector,
    required this.builder,
    this.child,
  });

  @override
  State<StateSelector<T>> createState() => _StateSelectorState<T>();
}

class _StateSelectorState<T> extends State<StateSelector<T>> {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();
  late T _value;
  
  @override
  void initState() {
    super.initState();
    _value = widget.selector(_stateAdapter);
    _stateAdapter.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _stateAdapter.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    final newValue = widget.selector(_stateAdapter);
    if (_value != newValue) {
      setState(() {
        _value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value, widget.child);
  }
}

/// A consumer that rebuilds when any part of the app state changes
class StateConsumer extends StatefulWidget {
  final Widget Function(BuildContext context, StateServiceAdapter state, Widget? child) builder;
  final Widget? child;

  const StateConsumer({
    super.key,
    required this.builder,
    this.child,
  });

  @override
  State<StateConsumer> createState() => _StateConsumerState();
}

class _StateConsumerState extends State<StateConsumer> {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();

  @override
  void initState() {
    super.initState();
    _stateAdapter.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _stateAdapter.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _stateAdapter, widget.child);
  }
}

/// Reactive builder for post-specific data
class PostSelector extends StatelessWidget {
  final String postId;
  final Widget Function(
    BuildContext context,
    PostModel? post,
    bool isLiked,
    bool isBookmarked,
    Widget? child,
  ) builder;
  final Widget? child;

  const PostSelector({
    super.key,
    required this.postId,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateSelector(
      selector: (state) => _PostData(
        post: state.getPost(postId),
        isLiked: state.isPostLiked(postId),
        isBookmarked: state.isPostBookmarked(postId),
      ),
      builder: (context, data, child) => builder(
        context,
        data.post,
        data.isLiked,
        data.isBookmarked,
        child,
      ),
      child: child,
    );
  }
}

class _PostData {
  final PostModel? post;
  final bool isLiked;
  final bool isBookmarked;

  _PostData({
    required this.post,
    required this.isLiked,
    required this.isBookmarked,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _PostData &&
        other.post?.id == post?.id &&
        other.post?.likesCount == post?.likesCount &&
        other.post?.commentsCount == post?.commentsCount &&
        other.isLiked == isLiked &&
        other.isBookmarked == isBookmarked;
  }

  @override
  int get hashCode => Object.hash(
    post?.id,
    post?.likesCount,
    post?.commentsCount,
    isLiked,
    isBookmarked,
  );
}

/// Reactive builder for avatar-specific data
class AvatarSelector extends StatelessWidget {
  final String avatarId;
  final Widget Function(
    BuildContext context,
    AvatarModel? avatar,
    bool isFollowing,
    Widget? child,
  ) builder;
  final Widget? child;

  const AvatarSelector({
    super.key,
    required this.avatarId,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateSelector(
      selector: (state) => _AvatarData(
        avatar: state.getAvatar(avatarId),
        isFollowing: state.isFollowingAvatar(avatarId),
      ),
      builder: (context, data, child) => builder(
        context,
        data.avatar,
        data.isFollowing,
        child,
      ),
      child: child,
    );
  }
}

class _AvatarData {
  final AvatarModel? avatar;
  final bool isFollowing;

  _AvatarData({
    required this.avatar,
    required this.isFollowing,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _AvatarData &&
        other.avatar?.id == avatar?.id &&
        other.avatar?.followersCount == avatar?.followersCount &&
        other.isFollowing == isFollowing;
  }

  @override
  int get hashCode => Object.hash(
    avatar?.id,
    avatar?.followersCount,
    isFollowing,
  );
}

/// Reactive builder for feed posts
class FeedPostsSelector extends StatelessWidget {
  final Widget Function(
    BuildContext context,
    List<PostModel> posts,
    bool isLoading,
    String? error,
    Widget? child,
  ) builder;
  final String feedContext;
  final Widget? child;

  const FeedPostsSelector({
    super.key,
    required this.builder,
    this.feedContext = 'feed',
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateSelector(
      selector: (state) => _FeedData(
        posts: state.feedPosts,
        isLoading: state.getLoadingState(feedContext),
        error: state.error,
      ),
      builder: (context, data, child) => builder(
        context,
        data.posts,
        data.isLoading,
        data.error,
        child,
      ),
      child: child,
    );
  }
}

class _FeedData {
  final List<PostModel> posts;
  final bool isLoading;
  final String? error;

  _FeedData({
    required this.posts,
    required this.isLoading,
    required this.error,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _FeedData &&
        listEquals(other.posts, posts) &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(posts, isLoading, error);
}

/// Reactive builder for comments
class CommentsSelector extends StatelessWidget {
  final String postId;
  final Widget Function(
    BuildContext context,
    List<Comment> comments,
    bool isLoading,
    Widget? child,
  ) builder;
  final Widget? child;

  const CommentsSelector({
    super.key,
    required this.postId,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return StateSelector(
      selector: (state) => _CommentsData(
        comments: state.getPostComments(postId),
        isLoading: state.getLoadingState('comments_$postId'),
      ),
      builder: (context, data, child) => builder(
        context,
        data.comments,
        data.isLoading,
        child,
      ),
      child: child,
    );
  }
}

class _CommentsData {
  final List<Comment> comments;
  final bool isLoading;

  _CommentsData({
    required this.comments,
    required this.isLoading,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _CommentsData &&
        listEquals(other.comments, comments) &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode => Object.hash(comments, isLoading);
}

/// Mixin to provide reactive state functionality to StatefulWidgets
mixin ReactiveStateMixin<T extends StatefulWidget> on State<T> {
  StateServiceAdapter get stateAdapter => _stateAdapter;
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();

  @override
  void initState() {
    super.initState();
    _stateAdapter.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _stateAdapter.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  /// Override this to perform selective updates
  void onStateChanged() {}
}

/// Wrapper to make any widget reactive to state changes
class ReactiveWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onStateChanged;

  const ReactiveWrapper({
    super.key,
    required this.child,
    this.onStateChanged,
  });

  @override
  State<ReactiveWrapper> createState() => _ReactiveWrapperState();
}

class _ReactiveWrapperState extends State<ReactiveWrapper> {
  final StateServiceAdapter _stateAdapter = StateServiceAdapter();

  @override
  void initState() {
    super.initState();
    _stateAdapter.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    _stateAdapter.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    widget.onStateChanged?.call();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Performance-optimized list builder for posts
class ReactivePostsList extends StatelessWidget {
  final String context;
  final Widget Function(BuildContext context, PostModel post, int index) itemBuilder;
  final Widget Function(BuildContext context)? loadingBuilder;
  final Widget Function(BuildContext context, String error)? errorBuilder;
  final Widget Function(BuildContext context)? emptyBuilder;

  const ReactivePostsList({
    super.key,
    required this.context,
    required this.itemBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return FeedPostsSelector(
      feedContext: this.context,
      builder: (context, posts, isLoading, error, child) {
        if (isLoading && posts.isEmpty) {
          return loadingBuilder?.call(context) ?? 
                 const Center(child: CircularProgressIndicator());
        }

        if (error != null && posts.isEmpty) {
          return errorBuilder?.call(context, error) ??
                 Center(child: Text('Error: $error'));
        }

        if (posts.isEmpty) {
          return emptyBuilder?.call(context) ??
                 const Center(child: Text('No posts available'));
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) => itemBuilder(context, posts[index], index),
        );
      },
    );
  }
}
