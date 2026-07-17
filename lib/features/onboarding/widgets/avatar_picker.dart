import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/avatars/avatar_catalog.dart';
import '../../../shared/widgets/avatar_display.dart';

/// Grid of the 3D character avatars with the selected character's meaning
/// shown above it. When [gender] is man/woman the grid pre-filters to the
/// matching variants (with a "Show all" toggle) — a display suggestion
/// only; any user may pick any character.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.gender,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;
  final Gender? gender;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _showAll = false;

  bool get _canFilter =>
      widget.gender == Gender.man || widget.gender == Gender.woman;

  @override
  Widget build(BuildContext context) {
    final ids = _showAll || !_canFilter
        ? AvatarCatalog.allIds
        : AvatarCatalog.idsForGender(widget.gender);
    final selected = AvatarCatalog.resolve(widget.selectedId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Meaning card for the currently selected character.
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              AvatarDisplay(avatarId: selected.id, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('The ${selected.character.name}',
                        style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(
                      selected.character.tagline,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(selected.character.description,
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_canFilter) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                _showAll ? 'All characters' : 'Suggested for you',
                style: AppTextStyles.caption,
              ),
              Switch(
                value: _showAll,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => setState(() => _showAll = v),
              ),
            ],
          ),
        ] else
          const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: ids.length,
          itemBuilder: (context, index) {
            final id = ids[index];
            final isSelected = id == widget.selectedId;
            return GestureDetector(
              onTap: () => widget.onSelected(id),
              child: AvatarDisplay(
                avatarId: id,
                size: 64,
                borderColor: isSelected ? AppColors.primary : null,
              ),
            );
          },
        ),
      ],
    );
  }
}
