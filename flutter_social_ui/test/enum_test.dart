import 'package:flutter_test/flutter_test.dart';

// Try to import ProfileViewMode directly
import 'package:quanta/store/app_state.dart' show ProfileViewMode;

void main() {
  test('ProfileViewMode enum should be accessible', () {
    expect(ProfileViewMode.owner, isNotNull);
    expect(ProfileViewMode.public, isNotNull);
    expect(ProfileViewMode.guest, isNotNull);
  });
}
