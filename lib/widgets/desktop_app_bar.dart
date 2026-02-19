import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:window_manager/window_manager.dart';

import '../bloc/explorer/explorer_bloc.dart';
import '../bloc/explorer/explorer_state.dart';

/// A slim, frameless desktop-style app bar that supports window dragging,
/// minimize/maximize/close, and displays the current environment path.
class DesktopAppBar extends StatelessWidget implements PreferredSizeWidget {
  const DesktopAppBar({super.key});

  static const double _height = 40.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: colorScheme.surface,
          child: Container(
            height: _height,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Image.asset(
                  'assets/app_icon.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
                // Draggable area spanning title + path
                Expanded(
                  child: DragToMoveArea(
                    child: SizedBox(
                      height: _height,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: BlocBuilder<ExplorerBloc, ExplorerState>(
                          builder: (context, state) {
                            return Row(
                              children: [
                                Text(
                                  'LMDB Explorer',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                if (state is ExplorerLoaded) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '—',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: colorScheme.outline,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      state.environmentPath,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const _WindowControls(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WindowControls extends StatelessWidget {
  const _WindowControls();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _WindowButton(
          icon: Icons.minimize_rounded,
          onPressed: windowManager.minimize,
          hoverColor: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        _MaximizeButton(hoverColor: colorScheme.onSurface.withValues(alpha: 0.08)),
        _WindowButton(
          icon: Icons.close_rounded,
          onPressed: windowManager.close,
          hoverColor: const Color(0xFFE81123),
          hoverIconColor: Colors.white,
        ),
      ],
    );
  }
}

class _MaximizeButton extends StatefulWidget {
  const _MaximizeButton({required this.hoverColor});
  final Color hoverColor;

  @override
  State<_MaximizeButton> createState() => _MaximizeButtonState();
}

class _MaximizeButtonState extends State<_MaximizeButton> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  Widget build(BuildContext context) {
    return _WindowButton(
      icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
      onPressed: () async {
        if (await windowManager.isMaximized()) {
          windowManager.unmaximize();
        } else {
          windowManager.maximize();
        }
      },
      hoverColor: widget.hoverColor,
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = _hovering && widget.hoverIconColor != null
        ? widget.hoverIconColor!
        : colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: DesktopAppBar._height,
          color: _hovering ? widget.hoverColor : Colors.transparent,
          child: Center(
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}
