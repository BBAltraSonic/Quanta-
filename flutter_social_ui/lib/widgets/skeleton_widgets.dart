import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';

class SkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  const SkeletonWidget({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
  });

  @override
  _SkeletonWidgetState createState() => _SkeletonWidgetState();
}

class _SkeletonWidgetState extends State<SkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = widget.baseColor ?? kCardColor;
    final highlightColor = widget.highlightColor ?? kCardColor.withOpacity(0.3);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 1).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 1).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and user info
          Row(
            children: [
              SkeletonWidget(
                width: 40,
                height: 40,
                borderRadius: BorderRadius.circular(20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonWidget(width: 120, height: 16),
                    SizedBox(height: 4),
                    SkeletonWidget(width: 80, height: 12),
                  ],
                ),
              ),
              SkeletonWidget(width: 24, height: 24),
            ],
          ),
          SizedBox(height: 16),

          // Caption
          SkeletonWidget(width: double.infinity, height: 14),
          SizedBox(height: 8),
          SkeletonWidget(width: 200, height: 14),
          SizedBox(height: 16),

          // Media loading indicator
          SkeletonWidget(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.circular(8),
          ),
          SizedBox(height: 16),

          // Engagement buttons
          Row(
            children: [
              SkeletonWidget(width: 60, height: 32),
              SizedBox(width: 16),
              SkeletonWidget(width: 60, height: 32),
              SizedBox(width: 16),
              SkeletonWidget(width: 60, height: 32),
              Spacer(),
              SkeletonWidget(width: 24, height: 24),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonAvatarCard extends StatelessWidget {
  const SkeletonAvatarCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: EdgeInsets.only(right: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SkeletonWidget(
            width: 80,
            height: 80,
            borderRadius: BorderRadius.circular(40),
          ),
          SizedBox(height: 12),
          SkeletonWidget(width: 100, height: 16),
          SizedBox(height: 8),
          SkeletonWidget(width: 80, height: 12),
          SizedBox(height: 12),
          SkeletonWidget(width: 120, height: 32),
        ],
      ),
    );
  }
}

class SkeletonCommentItem extends StatelessWidget {
  const SkeletonCommentItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonWidget(
            width: 32,
            height: 32,
            borderRadius: BorderRadius.circular(16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SkeletonWidget(width: 80, height: 14),
                    SizedBox(width: 8),
                    SkeletonWidget(width: 40, height: 12),
                  ],
                ),
                SizedBox(height: 8),
                SkeletonWidget(width: double.infinity, height: 12),
                SizedBox(height: 4),
                SkeletonWidget(width: 150, height: 12),
                SizedBox(height: 8),
                Row(
                  children: [
                    SkeletonWidget(width: 40, height: 12),
                    SizedBox(width: 16),
                    SkeletonWidget(width: 40, height: 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonNotificationItem extends StatelessWidget {
  const SkeletonNotificationItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SkeletonWidget(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidget(width: double.infinity, height: 14),
                SizedBox(height: 8),
                SkeletonWidget(width: 100, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          SkeletonWidget(
            width: 50,
            height: 50,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class SkeletonSearchResult extends StatelessWidget {
  const SkeletonSearchResult({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SkeletonWidget(
            width: 50,
            height: 50,
            borderRadius: BorderRadius.circular(25),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonWidget(width: 150, height: 16),
                SizedBox(height: 8),
                SkeletonWidget(width: 200, height: 12),
                SizedBox(height: 4),
                SkeletonWidget(width: 100, height: 12),
              ],
            ),
          ),
          SkeletonWidget(width: 80, height: 32),
        ],
      ),
    );
  }
}

class SkeletonProfileHeader extends StatelessWidget {
  const SkeletonProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile image and basic info
          Row(
            children: [
              SkeletonWidget(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(40),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonWidget(width: 150, height: 20),
                    SizedBox(height: 8),
                    SkeletonWidget(width: 100, height: 14),
                    SizedBox(height: 8),
                    SkeletonWidget(width: 200, height: 12),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  SkeletonWidget(width: 40, height: 20),
                  SizedBox(height: 4),
                  SkeletonWidget(width: 60, height: 12),
                ],
              ),
              Column(
                children: [
                  SkeletonWidget(width: 40, height: 20),
                  SizedBox(height: 4),
                  SkeletonWidget(width: 60, height: 12),
                ],
              ),
              Column(
                children: [
                  SkeletonWidget(width: 40, height: 20),
                  SizedBox(height: 4),
                  SkeletonWidget(width: 60, height: 12),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SkeletonWidget(width: double.infinity, height: 40),
              ),
              SizedBox(width: 12),
              SkeletonWidget(width: 40, height: 40),
            ],
          ),
        ],
      ),
    );
  }
}

class SkeletonChatMessage extends StatelessWidget {
  final bool isMe;

  const SkeletonChatMessage({super.key, this.isMe = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            SkeletonWidget(
              width: 32,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
            SizedBox(width: 8),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: 250),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                SkeletonWidget(
                  width: 180,
                  height: 14,
                  borderRadius: BorderRadius.circular(7),
                ),
                SizedBox(height: 4),
                SkeletonWidget(
                  width: 120,
                  height: 14,
                  borderRadius: BorderRadius.circular(7),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            SizedBox(width: 8),
            SkeletonWidget(
              width: 32,
              height: 32,
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ],
      ),
    );
  }
}

// Utility class for creating skeleton loading states
class SkeletonLoader {
  static Widget postFeed({int itemCount = 3}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonPostCard(),
    );
  }

  static Widget avatarGrid({int itemCount = 6}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonAvatarCard(),
    );
  }

  static Widget commentList({int itemCount = 5}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonCommentItem(),
    );
  }

  static Widget notificationList({int itemCount = 8}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonNotificationItem(),
    );
  }

  static Widget searchResults({int itemCount = 6}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonSearchResult(),
    );
  }

  static Widget chatMessages({int itemCount = 8}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonChatMessage(
        isMe: index % 3 == 0, // Mix of user and avatar messages
      ),
    );
  }

  static Widget videoFeed() {
    return Container(
      color: Colors.black,
      height: 400, // Fixed height instead of infinite
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: double.infinity,
                height: 200, // Fixed height instead of infinite
                color: Colors.grey[300],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget profileAnalytics() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonWidget(width: 150, height: 18),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonWidget(width: 80, height: 12),
                      SizedBox(height: 4),
                      SkeletonWidget(width: 60, height: 16),
                      SizedBox(height: 2),
                      SkeletonWidget(width: 100, height: 10),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonWidget(width: 80, height: 12),
                      SizedBox(height: 4),
                      SkeletonWidget(width: 60, height: 16),
                      SizedBox(height: 2),
                      SkeletonWidget(width: 100, height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget followersList({int itemCount = 5}) {
    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SkeletonWidget(
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(28),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonWidget(width: 120, height: 16),
                  SizedBox(height: 8),
                  SkeletonWidget(width: 200, height: 14),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonWidget(width: 60, height: 20),
                      SizedBox(width: 8),
                      SkeletonWidget(width: 100, height: 12),
                    ],
                  ),
                ],
              ),
            ),
            SkeletonWidget(width: 80, height: 36),
          ],
        ),
      ),
    );
  }
  
  // Additional skeleton widgets for different screens
  
  static Widget authForm() {
    return Shimmer.fromColors(
      baseColor: kCardColor,
      highlightColor: kCardColor.withOpacity(0.3),
      child: Container(
        padding: EdgeInsets.all(kDefaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo placeholder
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            SizedBox(height: 24),
            // Title placeholders
            Container(
              height: 28,
              width: 200,
              color: kCardColor,
            ),
            SizedBox(height: 8),
            Container(
              height: 16,
              width: 150,
              color: kCardColor,
            ),
            SizedBox(height: 48),
            // Form fields
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(kDefaultBorderRadius),
              ),
            ),
            SizedBox(height: 24),
            // Button placeholder
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  static Widget avatarCreationForm() {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress indicator
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 32),
          // Form title
          SkeletonWidget(width: 200, height: 24),
          SizedBox(height: 16),
          SkeletonWidget(width: 300, height: 16),
          SizedBox(height: 32),
          // Form fields
          ...List.generate(3, (index) => Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(height: 16),
            ],
          )),
          // Button
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget settingsScreen() {
    return ListView.separated(
      padding: EdgeInsets.all(16),
      itemCount: 8,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SkeletonWidget(
              width: 24,
              height: 24,
              borderRadius: BorderRadius.circular(4),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonWidget(width: 150, height: 16),
                  SizedBox(height: 4),
                  SkeletonWidget(width: 200, height: 12),
                ],
              ),
            ),
            SkeletonWidget(width: 24, height: 24),
          ],
        ),
      ),
    );
  }
  
  static Widget editProfileForm() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile picture placeholder
          SkeletonWidget(
            width: 120,
            height: 120,
            borderRadius: BorderRadius.circular(60),
          ),
          SizedBox(height: 24),
          // Form fields
          ...List.generate(5, (index) => Column(
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(height: 16),
            ],
          )),
          // Save button
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget onboardingScreen() {
    return Container(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Onboarding illustration placeholder
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          SizedBox(height: 48),
          // Title
          SkeletonWidget(width: 250, height: 28),
          SizedBox(height: 16),
          // Subtitle
          SkeletonWidget(width: 300, height: 16),
          SizedBox(height: 8),
          SkeletonWidget(width: 280, height: 16),
          SizedBox(height: 48),
          // Buttons
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kCardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget contentUploadForm() {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media upload area
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: Center(
              child: SkeletonWidget(
                width: 80,
                height: 80,
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          SizedBox(height: 24),
          // Caption field
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(height: 16),
          // Tags field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          SizedBox(height: 24),
          // Upload button
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ],
      ),
    );
  }
  
  static Widget avatarManagementGrid({int itemCount = 6}) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonWidget(width: double.infinity, height: 16),
                  SizedBox(height: 8),
                  SkeletonWidget(width: 100, height: 12),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[700],
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey[700],
                          borderRadius: BorderRadius.circular(16),
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
  }
}
