import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_social_ui/services/analytics_service.dart';

void main() {
  group('AnalyticsEvents Constants', () {

    // Test constants without initializing Supabase to avoid test setup complexity

    test('should have all required event constants', () {
      // Verify all the key events from the audit are defined
      expect(AnalyticsEvents.postView, equals('post_view'));
      expect(AnalyticsEvents.likeToggle, equals('like_toggle'));
      expect(AnalyticsEvents.commentAdd, equals('comment_add'));
      expect(AnalyticsEvents.shareAttempt, equals('share_attempt'));
      expect(AnalyticsEvents.bookmarkToggle, equals('bookmark_toggle'));
      expect(AnalyticsEvents.followToggle, equals('follow_toggle'));
      expect(AnalyticsEvents.commentModalOpen, equals('comment_modal_open'));
      expect(AnalyticsEvents.videoPlay, equals('video_play'));
      expect(AnalyticsEvents.videoPause, equals('video_pause'));
      expect(AnalyticsEvents.screenView, equals('screen_view'));
    });
  });
}
