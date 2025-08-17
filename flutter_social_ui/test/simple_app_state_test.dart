import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/store/app_state.dart';

void main() {
  test('AppState should have ProfileViewMode enum', () {
    // Just test that the enum exists
    expect(ProfileViewMode.values.length, equals(3));
  });

  test('AppState should instantiate without errors', () {
    final appState = AppState();
    expect(appState, isNotNull);
    expect(appState.isAuthenticated, isFalse);
  });
}
