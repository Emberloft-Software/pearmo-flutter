import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/matches_providers.dart';
import 'avatar_display.dart';

/// [AvatarDisplay] that resolves a raw `profile_photo_url` storage path
/// (private bucket) into a signed URL via [signedProfilePhotoUrlProvider]
/// before rendering. Falls back to the plain avatar while the signed URL is
/// loading or unavailable.
class SignedAvatarDisplay extends ConsumerWidget {
  const SignedAvatarDisplay({
    super.key,
    required this.avatarId,
    this.photoPath,
    this.showPhoto = false,
    this.size = 64,
    this.borderColor,
  });

  final String avatarId;
  final String? photoPath;
  final bool showPhoto;
  final double size;
  final Color? borderColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photoPath;
    if (!showPhoto || path == null || path.isEmpty) {
      return AvatarDisplay(avatarId: avatarId, size: size, borderColor: borderColor);
    }

    final signedUrl = ref.watch(signedProfilePhotoUrlProvider(path));
    return AvatarDisplay(
      avatarId: avatarId,
      photoUrl: signedUrl.valueOrNull,
      showPhoto: signedUrl.valueOrNull != null,
      size: size,
      borderColor: borderColor,
    );
  }
}
