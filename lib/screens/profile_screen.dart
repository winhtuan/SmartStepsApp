import 'package:flutter/material.dart';

import '../theme/duo_theme.dart';
import '../widgets/duo_components.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('profile-screen'),
      backgroundColor: DuoColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          children: [
            DuoCard(
              color: DuoColors.primaryYellow,
              borderColor: DuoColors.darkYellow.withValues(alpha: 0.28),
              child: Row(
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.face_rounded,
                      color: DuoColors.darkYellow,
                      size: 46,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bé An',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Level 4 • An toàn tại nhà',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        const DuoProgressBar(value: 0.64),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.local_fire_department_rounded,
                    value: '7',
                    label: 'Ngày streak',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _ProfileStatCard(
                    icon: Icons.star_rounded,
                    value: '1.240',
                    label: 'XP',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Thành tích', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const DuoAchievementCard(
              icon: Icons.shield_rounded,
              title: 'Người bảo vệ nhỏ',
              subtitle: 'Hoàn thành bài học an toàn đầu tiên',
            ),
            const SizedBox(height: 12),
            const DuoAchievementCard(
              icon: Icons.bolt_rounded,
              title: 'Học đều mỗi ngày',
              subtitle: 'Giữ streak trong 7 ngày',
            ),
            const SizedBox(height: 12),
            const DuoAchievementCard(
              icon: Icons.workspace_premium_rounded,
              title: 'Chuyên gia nhí',
              subtitle: 'Mở khóa khi đạt Level 6',
              isUnlocked: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DuoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Icon(icon, color: DuoColors.darkYellow, size: 30),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
