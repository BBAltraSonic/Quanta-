import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_social_ui/constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppShell provides global bottom nav
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: null,
        centerTitle: false,
        leadingWidth: 56,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: IconButton(
            onPressed: () {
              // TODO: navigate to settings screen
            },
            icon: SvgPicture.asset(
              'assets/icons/settings-minimalistic-svgrepo-com.svg',
              width: 22,
              height: 22,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            tooltip: 'Settings',
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              onPressed: () {
                // TODO: open edit profile
              },
              icon: SvgPicture.asset(
                'assets/icons/pen-new-square-svgrepo-com.svg',
                width: 22,
                height: 22,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              tooltip: 'Edit profile',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fullscreen profile photo background with dark + red overlays
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                const Image(
                  image: AssetImage('assets/images/We.jpg'),
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.55),
                        Colors.black.withOpacity(0.78),
                      ],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        kPrimaryColor.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 240, 20, 14),
                  sliver: SliverToBoxAdapter(child: _headerBlock()),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverToBoxAdapter(child: _userPostsMasonry()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Header (name + bio + metrics)
  Widget _headerBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            CircleAvatar(
              radius: 22,
              backgroundImage: AssetImage('assets/images/p.jpg'),
            ),
            SizedBox(width: 10),
            Text(
              'Lana Smith',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.1,
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.verified, color: kPrimaryColor, size: 18),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Photographer | Traveler | Coffee lover',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 14),
        // Metrics chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _MetricChip(value: '50', label: 'Following'),
            _MetricChip(value: '8,000', label: 'Followers'),
            _MetricChip(value: '50', label: 'Posts'),
          ],
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // Masonry-like grid of user's posts (uses variable images)
  Widget _userPostsMasonry() {
    // Rotate through a few different images for visual variety.
    // Ensure these exist in assets/images and are declared in pubspec.yaml.
    const images = <String>['assets/images/We.jpg', 'assets/images/p.jpg'];
    int idx = 0;

    String nextImg() {
      final path = images[idx % images.length];
      idx++;
      return path;
    }

    Widget tile({
      required double h,
      bool play = false,
      String? badge,
      double radius = 18,
      String? image,
    }) {
      final imgPath = image ?? nextImg();
      return Container(
        height: h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          image: DecorationImage(image: AssetImage(imgPath), fit: BoxFit.cover),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // subtle gradient for text legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (play)
              Center(
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: kPrimaryColor,
                    size: 34,
                  ),
                ),
              ),
            if (badge != null)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        const gap = 12.0;

        // Two bespoke columns: left thin, right wide
        final leftColW = (totalW - gap) * 0.35;
        final rightColW = totalW - leftColW - gap;

        const leftTopH = 120.0;
        const leftBottomH = 120.0;

        const rightTopH = 180.0;
        const rightBottomH = 120.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column
            SizedBox(
              width: leftColW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: tile(h: leftTopH, badge: '5/7', radius: 18),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: tile(h: leftBottomH, radius: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Right column
            SizedBox(
              width: rightColW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: tile(
                      h: rightTopH,
                      play: true,
                      badge: '1/3',
                      radius: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: tile(h: rightBottomH, radius: 18),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: tile(
                            h: rightBottomH,
                            badge: '1/3',
                            radius: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Const-friendly metric chip used in header Wrap
class _MetricChip extends StatelessWidget {
  final String value;
  final String label;
  const _MetricChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.95)),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: kPrimaryColor),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
