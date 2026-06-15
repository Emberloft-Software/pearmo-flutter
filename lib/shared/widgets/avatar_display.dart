import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../avatars/avatar_catalog.dart';

/// Renders a user's avatar by default. Only swaps to their real photo when
/// [photoUrl] (a signed URL) is provided AND [showPhoto] is true — callers
/// are responsible for that decision (see [PublicProfile.hasPublicPhoto]
/// and the candidate's `is_photo_public` flag).
class AvatarDisplay extends StatelessWidget {
  const AvatarDisplay({
    super.key,
    required this.avatarId,
    this.photoUrl,
    this.showPhoto = false,
    this.size = 64,
    this.borderColor,
  });

  final String avatarId;
  final String? photoUrl;
  final bool showPhoto;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final color = AvatarCatalog.colorFor(avatarId);
    final icon = AvatarCatalog.iconFor(avatarId);

    Widget child;
    if (showPhoto && photoUrl != null && photoUrl!.isNotEmpty) {
      child = ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _avatarCircle(color, icon),
          errorWidget: (_, _, _) => _avatarCircle(color, icon),
        ),
      );
    } else {
      child = _avatarCircle(color, icon);
    }

    if (borderColor == null) return child;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: 2),
      ),
      child: child,
    );
  }

  Widget _avatarCircle(Color color, IconData icon) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.55), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}
