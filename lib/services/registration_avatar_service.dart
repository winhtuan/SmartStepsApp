import 'package:flutter/material.dart';

import 'supabase_config.dart';

class RegistrationAvatar {
  const RegistrationAvatar({
    required this.label,
    required this.emoji,
    required this.color,
    required this.storagePath,
    this.imageUrl,
  });

  final String label;
  final String emoji;
  final Color color;
  final String storagePath;
  final String? imageUrl;
}

class RegistrationAvatarService {
  const RegistrationAvatarService._();

  static const _avatarDefinitions = [
    RegistrationAvatar(
      label: 'Mèo',
      emoji: '🐱',
      color: Color(0xFFFFEDA0),
      storagePath: 'mascots/cat.png',
    ),
    RegistrationAvatar(
      label: 'Chó',
      emoji: '🐶',
      color: Color(0xFFFFD5A8),
      storagePath: 'mascots/dog.png',
    ),
    RegistrationAvatar(
      label: 'Gấu',
      emoji: '🐻',
      color: Color(0xFFD8F5C7),
      storagePath: 'mascots/bear.png',
    ),
    RegistrationAvatar(
      label: 'Thỏ',
      emoji: '🐰',
      color: Color(0xFFDDEBFF),
      storagePath: 'mascots/rabbit.png',
    ),
    RegistrationAvatar(
      label: 'Cáo',
      emoji: '🦊',
      color: Color(0xFFFFC8A8),
      storagePath: 'mascots/fox.png',
    ),
    RegistrationAvatar(
      label: 'Gấu trúc',
      emoji: '🐼',
      color: Color(0xFFE7E7E7),
      storagePath: 'mascots/panda.png',
    ),
    RegistrationAvatar(
      label: 'Hổ',
      emoji: '🐯',
      color: Color(0xFFFFD36E),
      storagePath: 'mascots/tiger.png',
    ),
    RegistrationAvatar(
      label: 'Sư tử',
      emoji: '🦁',
      color: Color(0xFFFFE2A8),
      storagePath: 'mascots/lion.png',
    ),
    RegistrationAvatar(
      label: 'Khỉ',
      emoji: '🐵',
      color: Color(0xFFD8C2AA),
      storagePath: 'mascots/monkey.png',
    ),
    RegistrationAvatar(
      label: 'Cánh cụt',
      emoji: '🐧',
      color: Color(0xFFDDEBFF),
      storagePath: 'mascots/penguin.png',
    ),
  ];

  static List<RegistrationAvatar> get registrationAvatars {
    final client = supabaseClientOrNull;
    if (client == null) {
      return _avatarDefinitions;
    }

    return [
      for (final avatar in _avatarDefinitions)
        RegistrationAvatar(
          label: avatar.label,
          emoji: avatar.emoji,
          color: avatar.color,
          storagePath: avatar.storagePath,
          imageUrl: client.storage
              .from(SupabaseConfig.avatarBucket)
              .getPublicUrl(avatar.storagePath),
        ),
    ];
  }
}
