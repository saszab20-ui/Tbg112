import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';
import 'package:tarnobrzeg112/utils/date_time_utils.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, super.key, this.radius = 22});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final borderColor = _presenceBorderColor(user);
    final initials = Text(
      user.initials,
      style: TextStyle(
        color: AppColors.white,
        fontSize: radius * 0.54,
        fontWeight: FontWeight.w900,
      ),
    );
    final child = avatarUrl == null || avatarUrl.isEmpty
        ? initials
        : ClipOval(
            child: kIsWeb
                ? Image.network(
                    avatarUrl,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(child: initials),
                  )
                : CachedNetworkImage(
                    imageUrl: avatarUrl,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Center(child: initials),
                    errorWidget: (_, _, _) => Center(child: initials),
                  ),
          );
    return Tooltip(
      message: _presenceLabel(user),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2.5),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.panelAlt,
          child: child,
        ),
      ),
    );
  }

  Color _presenceBorderColor(AppUser user) {
    return switch (user.presenceStatus) {
      PresenceStatus.online => AppColors.green,
      PresenceStatus.busy => AppColors.orange,
      PresenceStatus.unavailable => Colors.grey,
      PresenceStatus.offline => AppColors.red,
      PresenceStatus.manual => AppColors.cyan,
    };
  }

  String _presenceLabel(AppUser user) {
    if (user.presenceStatus == PresenceStatus.manual &&
        user.customStatus.isNotEmpty) {
      return user.customStatus;
    }
    return switch (user.presenceStatus) {
      PresenceStatus.online => 'Aktywny teraz',
      PresenceStatus.busy => 'Zajęty',
      PresenceStatus.unavailable => 'Niewidoczny',
      PresenceStatus.offline =>
        user.lastSeenAt == null
            ? 'Offline'
            : 'Widziano ${DateTimeUtils.chatTime(user.lastSeenAt!)}',
      PresenceStatus.manual => 'Własny status',
    };
  }
}

class OnlineAvatarStack extends StatelessWidget {
  const OnlineAvatarStack({required this.users, super.key});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    final count = users.length;
    if (count == 0) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.people_alt_outlined,
            size: 16,
            color: AppColors.green,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Aktywni: $count',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
