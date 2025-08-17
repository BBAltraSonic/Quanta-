import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quanta/widgets/avatar_switcher.dart';
import 'package:quanta/models/avatar_model.dart';

void main() {
  group('AvatarSwitcher Widget Tests', () {
    late List<AvatarModel> testAvatars;
    late AvatarModel activeAvatar;
    late Function(AvatarModel) mockOnAvatarSelected;
    late List<AvatarModel> selectedAvatars;

    setUp(() {
      selectedAvatars = [];
      mockOnAvatarSelected = (avatar) {
        selectedAvatars.add(avatar);
      };

      testAvatars = [
        AvatarModel(
          id: '1',
          ownerUserId: 'user1',
          name: 'Fashion Avatar',
          bio: 'Fashion and style influencer',
          niche: AvatarNiche.fashion,
          personalityTraits: [
            PersonalityTrait.creative,
            PersonalityTrait.friendly,
          ],
          personalityPrompt: 'Test prompt',
          followersCount: 1000,
          postsCount: 50,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AvatarModel(
          id: '2',
          ownerUserId: 'user1',
          name: 'Tech Avatar',
          bio: 'Technology and innovation expert',
          niche: AvatarNiche.tech,
          personalityTraits: [
            PersonalityTrait.analytical,
            PersonalityTrait.professional,
          ],
          personalityPrompt: 'Test prompt',
          followersCount: 2000,
          postsCount: 75,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        AvatarModel(
          id: '3',
          ownerUserId: 'user1',
          name: 'Fitness Avatar',
          bio: 'Health and fitness coach',
          niche: AvatarNiche.fitness,
          personalityTraits: [
            PersonalityTrait.energetic,
            PersonalityTrait.inspiring,
          ],
          personalityPrompt: 'Test prompt',
          followersCount: 1500,
          postsCount: 60,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      activeAvatar = testAvatars[0];
    });
   
 group('Dropdown Style Tests', () {
      testWidgets('should display dropdown with all avatars', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.dropdown,
              ),
            ),
          ),
        );

        // Find the dropdown button
        expect(find.byType(DropdownButton<AvatarModel>), findsOneWidget);

        // Tap to open dropdown
        await tester.tap(find.byType(DropdownButton<AvatarModel>));
        await tester.pumpAndSettle();

        // Verify all avatars are displayed in dropdown items
        for (final avatar in testAvatars) {
          expect(find.text(avatar.name), findsWidgets);
        }
      });

      testWidgets('should highlight active avatar in dropdown', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.dropdown,
              ),
            ),
          ),
        );

        // Tap to open dropdown
        await tester.tap(find.byType(DropdownButton<AvatarModel>));
        await tester.pumpAndSettle();

        // Find the active avatar item and verify it has a check icon
        expect(find.byIcon(Icons.check_circle), findsWidgets);
      });

      testWidgets(
        'should call onAvatarSelected when avatar is selected from dropdown',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AvatarSwitcher(
                  avatars: testAvatars,
                  activeAvatar: activeAvatar,
                  onAvatarSelected: mockOnAvatarSelected,
                  style: AvatarSwitcherStyle.dropdown,
                ),
              ),
            ),
          );

          // Tap to open dropdown
          await tester.tap(find.byType(DropdownButton<AvatarModel>));
          await tester.pumpAndSettle();

          // Select a different avatar
          await tester.tap(find.text('Tech Avatar').last);
          await tester.pumpAndSettle();

          // Verify callback was called with correct avatar
          expect(selectedAvatars.length, 1);
          expect(selectedAvatars[0].name, 'Tech Avatar');
        },
      );

      testWidgets('should show avatar stats when enabled in dropdown', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.dropdown,
                showAvatarStats: true,
              ),
            ),
          ),
        );

        // Tap to open dropdown
        await tester.tap(find.byType(DropdownButton<AvatarModel>));
        await tester.pumpAndSettle();

        // Verify stats are displayed
        expect(find.textContaining('followers'), findsWidgets);
        expect(find.textContaining('posts'), findsWidgets);
      });
    });   
 group('Modal Style Tests', () {
      testWidgets('should display modal trigger with active avatar info', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.modal,
              ),
            ),
          ),
        );

        // Verify active avatar name is displayed
        expect(find.text(activeAvatar.name), findsOneWidget);

        // Verify dropdown arrow is present
        expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      });

      testWidgets('should open modal when tapped', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.modal,
              ),
            ),
          ),
        );

        // Tap to open modal
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Verify modal is displayed
        expect(find.text('Select Avatar'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Verify all avatars are listed
        for (final avatar in testAvatars) {
          expect(find.text(avatar.name), findsWidgets);
        }
      });

      testWidgets(
        'should call onAvatarSelected when avatar is selected from modal',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AvatarSwitcher(
                  avatars: testAvatars,
                  activeAvatar: activeAvatar,
                  onAvatarSelected: mockOnAvatarSelected,
                  style: AvatarSwitcherStyle.modal,
                ),
              ),
            ),
          );

          // Open modal
          await tester.tap(find.byType(InkWell));
          await tester.pumpAndSettle();

          // Select a different avatar
          await tester.tap(find.text('Tech Avatar'));
          await tester.pumpAndSettle();

          // Verify callback was called and modal closed
          expect(selectedAvatars.length, 1);
          expect(selectedAvatars[0].name, 'Tech Avatar');
          expect(
            find.text('Select Avatar'),
            findsNothing,
          ); // Modal should be closed
        },
      );

      testWidgets('should close modal when close button is tapped', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.modal,
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        // Verify modal is closed
        expect(find.text('Select Avatar'), findsNothing);
      });

      testWidgets('should highlight active avatar in modal', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.modal,
              ),
            ),
          ),
        );

        // Open modal
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Verify active avatar has check icon
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    });    g
roup('Carousel Style Tests', () {
      testWidgets('should display horizontal scrollable avatar list', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.carousel,
              ),
            ),
          ),
        );

        // Verify ListView is horizontal
        final listView = tester.widget<ListView>(find.byType(ListView));
        expect(listView.scrollDirection, Axis.horizontal);

        // Verify all avatar names are displayed
        for (final avatar in testAvatars) {
          expect(find.text(avatar.name), findsWidgets);
        }
      });

      testWidgets('should highlight active avatar in carousel', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.carousel,
              ),
            ),
          ),
        );

        // Find the active avatar container
        final activeAvatarFinder = find.descendant(
          of: find.byType(GestureDetector),
          matching: find.text(activeAvatar.name),
        );
        expect(activeAvatarFinder, findsOneWidget);
      });

      testWidgets(
        'should call onAvatarSelected when avatar is tapped in carousel',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AvatarSwitcher(
                  avatars: testAvatars,
                  activeAvatar: activeAvatar,
                  onAvatarSelected: mockOnAvatarSelected,
                  style: AvatarSwitcherStyle.carousel,
                ),
              ),
            ),
          );

          // Tap on a different avatar
          await tester.tap(find.text('Tech Avatar'));
          await tester.pumpAndSettle();

          // Verify callback was called
          expect(selectedAvatars.length, 1);
          expect(selectedAvatars[0].name, 'Tech Avatar');
        },
      );

      testWidgets(
        'should show avatar stats for active avatar when enabled in carousel',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: AvatarSwitcher(
                  avatars: testAvatars,
                  activeAvatar: activeAvatar,
                  onAvatarSelected: mockOnAvatarSelected,
                  style: AvatarSwitcherStyle.carousel,
                  showAvatarStats: true,
                ),
              ),
            ),
          );

          // Verify active avatar stats are displayed
          expect(
            find.text(activeAvatar.followersCount.toString()),
            findsOneWidget,
          );
        },
      );
    });    gr
oup('Empty State Tests', () {
      testWidgets('should display empty state when no avatars provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: const [],
                activeAvatar: null,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.dropdown,
              ),
            ),
          ),
        );

        // Verify empty state is displayed
        expect(find.text('No avatars available'), findsOneWidget);
        expect(find.byIcon(Icons.person_add), findsOneWidget);
      });

      testWidgets('should display custom empty state text and icon', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: const [],
                activeAvatar: null,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.dropdown,
                emptyStateText: 'Create your first avatar',
                emptyStateIcon: const Icon(Icons.add_circle),
              ),
            ),
          ),
        );

        // Verify custom empty state is displayed
        expect(find.text('Create your first avatar'), findsOneWidget);
        expect(find.byIcon(Icons.add_circle), findsOneWidget);
      });
    });

    group('Configuration Tests', () {
      testWidgets('should hide avatar names when showAvatarNames is false', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.carousel,
                showAvatarNames: false,
              ),
            ),
          ),
        );

        // Verify avatar names are not displayed
        for (final avatar in testAvatars) {
          expect(find.text(avatar.name), findsNothing);
        }
      });

      testWidgets('should apply custom padding', (tester) async {
        const customPadding = EdgeInsets.all(24);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.dropdown,
                padding: customPadding,
              ),
            ),
          ),
        );

        // Find the container with padding
        final containerFinder = find.byType(Container).first;
        final container = tester.widget<Container>(containerFinder);
        expect(container.padding, customPadding);
      });

      testWidgets('should apply custom max height to carousel', (tester) async {
        const customHeight = 120.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.carousel,
                maxHeight: customHeight,
              ),
            ),
          ),
        );

        // Find the carousel container and verify height
        final containerFinder = find
            .descendant(
              of: find.byType(AvatarSwitcher),
              matching: find.byType(Container),
            )
            .first;

        // The height should be set directly on the container
        final renderBox = tester.renderObject<RenderBox>(containerFinder);
        expect(renderBox.size.height, customHeight);
      });
    }); 
   group('Avatar Image Tests', () {
      testWidgets('should display initials when no avatar image', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: testAvatars,
                activeAvatar: activeAvatar,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.carousel,
              ),
            ),
          ),
        );

        // Verify initials are displayed (multiple F's expected due to Fashion and Fitness)
        expect(
          find.text('F'),
          findsWidgets,
        ); // Fashion Avatar -> F, Fitness Avatar -> F
        expect(find.text('T'), findsWidgets); // Tech Avatar -> T
        expect(
          find.text('F'),
          findsWidgets,
        ); // Fitness Avatar -> F (duplicate with Fashion)
      });

      testWidgets('should handle avatar images gracefully', (
        tester,
      ) async {
        final avatarWithImage = testAvatars[0].copyWith(
          avatarImageUrl: 'test_image_url',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AvatarSwitcher(
                avatars: [avatarWithImage],
                activeAvatar: avatarWithImage,
                onAvatarSelected: mockOnAvatarSelected,
                style: AvatarSwitcherStyle.carousel,
              ),
            ),
          ),
        );

        // Verify CircleAvatar is present and handles image URL
        expect(find.byType(CircleAvatar), findsOneWidget);
        
        // Verify that the CircleAvatar has a backgroundImage when URL is provided
        final circleAvatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        expect(circleAvatar.backgroundImage, isNotNull);
      });
    });
  });
}