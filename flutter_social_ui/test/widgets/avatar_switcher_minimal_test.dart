import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/widgets/avatar_switcher.dart';
import 'package:quanta/models/avatar_model.dart';

void main() {
  testWidgets('AvatarSwitcher should render without errors', (tester) async {
    final testAvatar = AvatarModel(
      id: '1',
      ownerUserId: 'user1',
      name: 'Test Avatar',
      bio: 'Test bio',
      niche: AvatarNiche.tech,
      personalityTraits: [PersonalityTrait.friendly],
      personalityPrompt: 'Test prompt',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AvatarSwitcher(
            avatars: [testAvatar],
            activeAvatar: testAvatar,
            onAvatarSelected: (avatar) {},
            style: AvatarSwitcherStyle.dropdown,
          ),
        ),
      ),
    );

    expect(find.byType(AvatarSwitcher), findsOneWidget);
  });
}
