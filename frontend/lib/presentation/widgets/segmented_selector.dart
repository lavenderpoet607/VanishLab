import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SegmentedSelector<T> extends StatelessWidget {
  final List<(T value, String label)> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  const SegmentedSelector({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final index = segments.indexWhere((s) => s.$1 == selected);
    final enabled = onChanged != null;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        border: Border.all(color: AppTheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segWidth = constraints.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOut,
                left: segWidth * (index < 0 ? 0 : index),
                top: 0,
                bottom: 0,
                width: segWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: enabled ? AppTheme.solidLight : AppTheme.textMuted,
                    borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final seg in segments)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: seg.$1 == selected,
                        enabled: enabled,
                        label: seg.$2,
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: enabled ? () => onChanged!(seg.$1) : null,
                          borderRadius: BorderRadius.circular(AppTheme.radiusControl - 2),
                          child: Center(
                            child: Text(
                              seg.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.body.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: seg.$1 == selected
                                    ? AppTheme.onSolidLight
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
