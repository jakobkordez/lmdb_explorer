import 'package:flutter/material.dart';

class ValueContainer extends StatefulWidget {
  final ColorScheme colorScheme;
  final Widget child;
  final bool enableHorizontalScroll;

  const ValueContainer({
    super.key,
    required this.colorScheme,
    required this.child,
    this.enableHorizontalScroll = true,
  });

  @override
  State<ValueContainer> createState() => _ValueContainerState();
}

class _ValueContainerState extends State<ValueContainer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      decoration: BoxDecoration(
        color: widget.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: widget.enableHorizontalScroll
          ? Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: widget.child,
              ),
            )
          : Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: widget.child,
            ),
    );
  }
}

