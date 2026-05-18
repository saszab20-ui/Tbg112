import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tarnobrzeg112/models/app_user.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, super.key, this.radius = 22});

  final AppUser user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl;
    final child = avatarUrl == null || avatarUrl.isEmpty
        ? Text(
            user.initials,
            style: TextStyle(
              color: AppColors.white,
              fontSize: radius * 0.54,
              fontWeight: FontWeight.w900,
            ),
          )
        : ClipOval(
            child: CachedNetworkImage(
              imageUrl: avatarUrl,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
            ),
          );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.panelAlt,
          child: child,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.45,
            height: radius * 0.45,
            decoration: BoxDecoration(
              color: user.presenceStatus.name == 'online'
                  ? AppColors.green
                  : AppColors.muted,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.black, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class OnlineAvatarStack extends StatelessWidget {
  const OnlineAvatarStack({required this.users, super.key});

  final List<AppUser> users;

  @override
  Widget build(BuildContext context) {
    final visible = users.take(5).toList();
    return SizedBox(
      width: 34.0 + visible.length * 20,
      height: 34,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: i * 20,
              child: UserAvatar(user: visible[i], radius: 17),
            ),
        ],
      ),
    );
  }
}
