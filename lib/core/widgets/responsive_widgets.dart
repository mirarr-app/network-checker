import 'package:flutter/material.dart';

/// Provides drawer-opening access from [HomeScreen] mobile layout so child
/// [AdaptiveAppBar] widgets reserve leading space for the menu button cleanly.
class HomeDrawerScope extends InheritedWidget {
  final VoidCallback openDrawer;

  const HomeDrawerScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  static HomeDrawerScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeDrawerScope>();
  }

  static Widget? menuButton(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) return null;
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Open menu',
      onPressed: scope.openDrawer,
    );
  }

  @override
  bool updateShouldNotify(HomeDrawerScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}

/// An [AppBar] that keeps its title on a single line via [FittedBox] and
/// integrates the mobile [HomeDrawerScope] menu button without overlapping text.
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;
  final bool? centerTitle;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.leading,
    this.centerTitle,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: leading ?? HomeDrawerScope.menuButton(context),
      centerTitle: centerTitle,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(title, maxLines: 1),
      ),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Ensures button labels stay on a single row and scale down gracefully when
/// font scale or narrow screen width constrains available space.
class SingleLineButtonLabel extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const SingleLineButtonLabel(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: style),
    );
  }
}

/// Dialog title row that wraps long titles cleanly instead of overflowing.
class DialogTitleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final double iconSize;

  const DialogTitleRow({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.iconSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: iconSize, color: iconColor),
        const SizedBox(width: 8),
        Expanded(child: Text(title)),
      ],
    );
  }
}
