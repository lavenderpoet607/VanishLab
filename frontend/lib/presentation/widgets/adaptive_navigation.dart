import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class NavDestinationSpec {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavDestinationSpec(this.icon, this.selectedIcon, this.label);
}

const List<NavDestinationSpec> kAppDestinations = [
  NavDestinationSpec(Icons.brush_outlined, Icons.brush, 'Inpaint'),
  NavDestinationSpec(Icons.download_for_offline_outlined, Icons.download_for_offline, 'Downloader'),
  NavDestinationSpec(Icons.view_agenda_outlined, Icons.view_agenda, 'Tasks'),
];

class AdaptiveNavigationScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? trailingHeader;

  const AdaptiveNavigationScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.trailingHeader,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 768) {
          return Scaffold(
            body: Row(
              children: [
                SafeArea(
                  right: false,
                  child: NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: onDestinationSelected,
                    labelType: NavigationRailLabelType.all,
                    groupAlignment: -0.9,
                    trailing: trailingHeader != null
                        ? Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: trailingHeader!,
                              ),
                            ),
                          )
                        : null,
                    destinations: [
                      for (final d in kAppDestinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: AppTheme.border),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: BottomDock(
            selectedIndex: selectedIndex,
            onSelected: onDestinationSelected,
          ),
        );
      },
    );
  }
}

class BottomDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const BottomDock({super.key, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < kAppDestinations.length; i++)
                Expanded(
                  child: _DockItem(
                    spec: kAppDestinations[i],
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final NavDestinationSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _DockItem({required this.spec, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusControl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? spec.selectedIcon : spec.icon,
              size: 22,
              color: selected ? AppTheme.accent : AppTheme.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.body.copyWith(
                fontSize: 10,
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
