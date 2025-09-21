import 'package:flutter/material.dart';
import '../models/avatar_model.dart';

enum AvatarSwitcherStyle { dropdown, modal, carousel }

class AvatarSwitcher extends StatefulWidget {
  final List<AvatarModel> avatars;
  final AvatarModel? activeAvatar;
  final Function(AvatarModel) onAvatarSelected;
  final AvatarSwitcherStyle style;
  final String? emptyStateText;
  final Widget? emptyStateIcon;
  final bool showAvatarNames;
  final bool showAvatarStats;
  final double? maxHeight;
  final EdgeInsetsGeometry? padding;

  const AvatarSwitcher({
    Key? key,
    required this.avatars,
    required this.activeAvatar,
    required this.onAvatarSelected,
    this.style = AvatarSwitcherStyle.dropdown,
    this.emptyStateText,
    this.emptyStateIcon,
    this.showAvatarNames = true,
    this.showAvatarStats = false,
    this.maxHeight,
    this.padding,
  }) : super(key: key);

  @override
  State<AvatarSwitcher> createState() => _AvatarSwitcherState();
}

class _AvatarSwitcherState extends State<AvatarSwitcher> {
  @override
  Widget build(BuildContext context) {
    if (widget.avatars.isEmpty) {
      return _buildEmptyState();
    }

    switch (widget.style) {
      case AvatarSwitcherStyle.dropdown:
        return _buildDropdownSwitcher();
      case AvatarSwitcherStyle.modal:
        return _buildModalSwitcher();
      case AvatarSwitcherStyle.carousel:
        return _buildCarouselSwitcher();
    }
  }

  Widget _buildEmptyState() {
    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.emptyStateIcon ?? const Icon(Icons.person_add, size: 48),
          const SizedBox(height: 8),
          Text(
            widget.emptyStateText ?? 'No avatars available',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSwitcher() {
    return Container(
      padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<AvatarModel>(
        value: widget.activeAvatar,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: Text(
          'Select Avatar',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        items: widget.avatars.map((avatar) {
          return DropdownMenuItem<AvatarModel>(
            value: avatar,
            child: _buildAvatarDropdownItem(avatar),
          );
        }).toList(),
        onChanged: (avatar) {
          if (avatar != null) {
            widget.onAvatarSelected(avatar);
          }
        },
      ),
    );
  }

  Widget _buildAvatarDropdownItem(AvatarModel avatar) {
    final isActive = widget.activeAvatar?.id == avatar.id;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundImage: avatar.avatarImageUrl != null
              ? NetworkImage(avatar.avatarImageUrl!)
              : null,
          child: avatar.avatarImageUrl == null
              ? Text(
                  avatar.name.isNotEmpty ? avatar.name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      avatar.name,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive ? Theme.of(context).primaryColor : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isActive)
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).primaryColor,
                    ),
                ],
              ),
              if (widget.showAvatarStats)
                Text(
                  '${avatar.followersCount} followers • ${avatar.postsCount} posts',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModalSwitcher() {
    return InkWell(
      onTap: () => _showAvatarSelectionModal(),
      child: Container(
        padding: widget.padding ?? const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (widget.activeAvatar != null) ...[
              CircleAvatar(
                radius: 20,
                backgroundImage: widget.activeAvatar!.avatarImageUrl != null
                    ? NetworkImage(widget.activeAvatar!.avatarImageUrl!)
                    : null,
                child: widget.activeAvatar!.avatarImageUrl == null
                    ? Text(
                        widget.activeAvatar!.name.isNotEmpty
                            ? widget.activeAvatar!.name[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.showAvatarNames)
                      Text(
                        widget.activeAvatar!.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.showAvatarStats)
                      Text(
                        '${widget.activeAvatar!.followersCount} followers',
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ] else ...[
              const CircleAvatar(radius: 20, child: Icon(Icons.person)),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Select Avatar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  void _showAvatarSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _AvatarSelectionModal(
        avatars: widget.avatars,
        activeAvatar: widget.activeAvatar,
        onAvatarSelected: (avatar) {
          Navigator.pop(context);
          widget.onAvatarSelected(avatar);
        },
        showAvatarNames: widget.showAvatarNames,
        showAvatarStats: widget.showAvatarStats,
        maxHeight: widget.maxHeight,
      ),
    );
  }

  Widget _buildCarouselSwitcher() {
    return Container(
      height: widget.maxHeight ?? 120,
      padding: widget.padding ?? const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: widget.avatars.length,
        itemBuilder: (context, index) {
          final avatar = widget.avatars[index];
          final isActive = widget.activeAvatar?.id == avatar.id;

          return GestureDetector(
            onTap: () => widget.onAvatarSelected(avatar),
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isActive
                          ? Border.all(
                              color: Theme.of(context).primaryColor,
                              width: 3,
                            )
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: isActive ? 28 : 25,
                      backgroundImage: avatar.avatarImageUrl != null
                          ? NetworkImage(avatar.avatarImageUrl!)
                          : null,
                      child: avatar.avatarImageUrl == null
                          ? Text(
                              avatar.name.isNotEmpty
                                  ? avatar.name[0].toUpperCase()
                                  : 'A',
                              style: TextStyle(
                                fontSize: isActive ? 18 : 16,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (widget.showAvatarNames)
                    Text(
                      avatar.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isActive ? Theme.of(context).primaryColor : null,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  if (widget.showAvatarStats && isActive)
                    Text(
                      '${avatar.followersCount}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AvatarSelectionModal extends StatelessWidget {
  final List<AvatarModel> avatars;
  final AvatarModel? activeAvatar;
  final Function(AvatarModel) onAvatarSelected;
  final bool showAvatarNames;
  final bool showAvatarStats;
  final double? maxHeight;

  const _AvatarSelectionModal({
    Key? key,
    required this.avatars,
    required this.activeAvatar,
    required this.onAvatarSelected,
    required this.showAvatarNames,
    required this.showAvatarStats,
    this.maxHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight ?? MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  'Select Avatar',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Avatar list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final avatar = avatars[index];
                final isActive = activeAvatar?.id == avatar.id;

                return ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: avatar.avatarImageUrl != null
                        ? NetworkImage(avatar.avatarImageUrl!)
                        : null,
                    child: avatar.avatarImageUrl == null
                        ? Text(
                            avatar.name.isNotEmpty
                                ? avatar.name[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  title: showAvatarNames
                      ? Text(
                          avatar.name,
                          style: TextStyle(
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        )
                      : null,
                  subtitle: showAvatarStats
                      ? Text(
                          '${avatar.followersCount} followers • ${avatar.postsCount} posts',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : Text(
                          avatar.bio,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                  trailing: isActive
                      ? Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                        )
                      : null,
                  onTap: () => onAvatarSelected(avatar),
                );
              },
            ),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
