import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/avatars/avatar_catalog.dart';
import '../../../shared/widgets/avatar_display.dart';

/// Grid of selectable generated avatars.
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key, required this.selectedId, required this.onSelected});

  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: AvatarCatalog.allIds.length,
      itemBuilder: (context, index) {
        final id = AvatarCatalog.allIds[index];
        final isSelected = id == selectedId;
        return GestureDetector(
          onTap: () => onSelected(id),
          child: AvatarDisplay(
            avatarId: id,
            size: 64,
            borderColor: isSelected ? AppColors.primary : null,
          ),
        );
      },
    );
  }
}
