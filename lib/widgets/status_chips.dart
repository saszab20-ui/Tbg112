import 'package:flutter/material.dart';
import 'package:tarnobrzeg112/core/enums.dart';
import 'package:tarnobrzeg112/themes/app_colors.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge(this.role, {super.key});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final color = switch (role) {
      UserRole.admin => const Color(0xFFFFC857),
      UserRole.moderator => const Color(0xFF7C83FF),
      UserRole.user => AppColors.muted,
    };
    return _Badge(text: role.shortLabel, color: color);
  }
}

class UnitBadge extends StatelessWidget {
  const UnitBadge({required this.type, required this.name, super.key});

  final UnitType type;
  final String name;

  @override
  Widget build(BuildContext context) {
    final cleanName = name.trim();
    final color = switch (type) {
      UnitType.osp => AppColors.red,
      UnitType.psp => AppColors.orange,
      UnitType.policja => const Color(0xFF4DA3FF),
      UnitType.zrm => AppColors.green,
      UnitType.media => const Color(0xFFFF5ACD),
      UnitType.informator => AppColors.cyan,
      UnitType.inne => AppColors.muted,
      UnitType.ratownikMedyczny => AppColors.green,
      UnitType.kierowcaKaretki => const Color(0xFF8DE969),
      UnitType.dyspozytor => const Color(0xFFB28DFF),
    };
    final suffix = cleanName.isEmpty ? '' : ' · $cleanName';
    return _Badge(text: '${type.badgeLabel}$suffix', color: color);
  }
}

class AccountStatusBadge extends StatelessWidget {
  const AccountStatusBadge(this.status, {super.key});

  final AccountStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      AccountStatus.active => AppColors.green,
      AccountStatus.pending => AppColors.orange,
      AccountStatus.rejected => Colors.grey,
      AccountStatus.banned => AppColors.red,
      AccountStatus.suspended => Colors.amber,
    };
    return _Badge(text: status.label, color: color);
  }
}

class MutedBadge extends StatelessWidget {
  const MutedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Badge(text: 'WYCISZONY', color: AppColors.orange);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
