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
///
/// If [traitScores] is provided (the PEARMO answers collected earlier in
/// onboarding), "Suggested for you" also puts the best personality match
/// first in the grid and pre-selects it on first visit — still just a
/// suggestion, overridden the moment the user taps anything else.
class AvatarPicker extends StatefulWidget {
  const AvatarPicker({
    super.key,
    required this.selectedId,
    required this.onSelected,
    this.gender,
    this.traitScores,
  });

  final String selectedId;
  final ValueChanged<String> onSelected;
  final Gender? gender;
  final Map<PersonalityTrait, double>? traitScores;

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  bool _showAll = false;

  bool get _canFilter =>
      widget.gender == Gender.man || widget.gender == Gender.woman;

  AvatarCharacter? get _suggested =>
      widget.traitScores != null ? AvatarCatalog.suggestCharacter(widget.traitScores!) : null;

  @override
  void initState() {
    super.initState();
    final suggested = _suggested;
    // Only auto-apply if the current selection is still the untouched
    // default — never override a choice the user (or a prior visit) made.
    if (suggested != null && widget.selectedId == AvatarCatalog.allIds.first) {
      final isMale = widget.gender == Gender.man;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onSelected(suggested.idFor(isMale));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var ids = _showAll || !_canFilter
        ? AvatarCatalog.allIds
        : AvatarCatalog.idsForGender(widget.gender);
    final suggested = _suggested;
    if (suggested != null && _canFilter && !_showAll) {
      final isMale = widget.gender == Gender.man;
      final suggestedId = suggested.idFor(isMale);
      ids = [suggestedId, ...ids.where((id) => id != suggestedId)];
    }
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
              Flexible(
                child: Text(
                  _showAll ? 'All characters' : 'Suggested for you',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.caption,
                ),
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
