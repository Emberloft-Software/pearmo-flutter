import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../avatars/avatar_catalog.dart';

/// Renders a user's avatar by default. Only swaps to their real photo when
/// [photoUrl] (a signed URL) is provided AND [showPhoto] is true — callers
/// are responsible for that decision (see [PublicProfile.hasPublicPhoto]
/// and the candidate's `is_photo_public` flag).
///
/// Avatars are the bundled 3D characters on the shared stage gradient —
/// one common treatment for every character (no per-character meaning in
/// the rendering). Legacy `av_XXX` ids resolve via [AvatarCatalog.resolve].
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
    Widget child;
    if (showPhoto && photoUrl != null && photoUrl!.isNotEmpty) {
      child = ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _characterCircle(),
          errorWidget: (_, _, _) => _characterCircle(),
        ),
      );
    } else {
      child = _characterCircle();
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

  Widget _characterCircle() {
    final info = AvatarCatalog.resolve(avatarId);
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: AvatarCatalog.stageGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: Image.asset(
          info.assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          // Never crash on a missing/corrupt asset — fall back to a plain
          // initial-style circle on the same stage gradient.
          errorBuilder: (_, _, _) => Center(
            child: Icon(Icons.person, color: AppColors.background, size: size * 0.5),
          ),
        ),
      ),
    );
  }
}
