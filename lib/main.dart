import 'dart:ui';

import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Dock(
            items: const [
              Icons.person,
              Icons.message,
              Icons.call,
              Icons.camera,
              Icons.photo,
            ],
            builder: (icon) {
              return Container(
                constraints: const BoxConstraints(minWidth: 48),
                height: 48,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color:
                      Colors.primaries[icon.hashCode % Colors.primaries.length],
                ),
                child: Center(child: Icon(icon, color: Colors.white)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class Dock extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  final List<IconData> items;

  final Widget Function(IconData) builder;

  @override
  State<Dock> createState() => _DockState();
}

class _DockState extends State<Dock> {
  late final List<IconData> items = widget.items.toList();
  late List<int> positions;

  IconData? draggedItem;
  IconData? hoveredItem;
  bool isOutside = false;
  int selectedIndex = -1;
  final GlobalKey dockKey = GlobalKey();
  late int? hoveredIndex;
  late double baseItemHeight;
  late double baseTranslationY;
  late double verticalItemsPadding;

  double getScaledSize(int index) {
    return getPropertyValue(
      index: index,
      baseValue: baseItemHeight,
      maxValue: 70,
      nonHoveredMaxValue: 50,
    );
  }

  double getTranslationY(int index) {
    return getPropertyValue(
      index: index,
      baseValue: baseTranslationY,
      maxValue: -15,
      nonHoveredMaxValue: -12,
    );
  }

  double getPropertyValue({
    required int index,
    required double baseValue,
    required double maxValue,
    required double nonHoveredMaxValue,
  }) {
    late final double propertyValue;
    if (hoveredIndex == null) {
      return baseValue;
    }
    final difference = (hoveredIndex! - index).abs();
    final itemsAffected = items.length;
    if (difference == 0) {
      propertyValue = maxValue;
    } else if (difference <= itemsAffected) {
      final ratio = (itemsAffected - difference) / itemsAffected;

      propertyValue = lerpDouble(baseValue, nonHoveredMaxValue, ratio)!;
    } else {
      propertyValue = baseValue;
    }

    return propertyValue;
  }

  @override
  void initState() {
    super.initState();
    positions = List.generate(items.length, (index) => index);
    hoveredIndex = null;
    baseItemHeight = 40;

    verticalItemsPadding = 10;
    baseTranslationY = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        key: dockKey,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        width: isOutside ? 266 : 328,
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.black12,
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          alignment: Alignment.center,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final icon = entry.value;
            final position = positions.indexOf(index);
            final leftPosition = position * 60;

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              left: leftPosition.toDouble(),
              curve: Curves.easeOut,
              child: Draggable<IconData>(
                key: ValueKey(index),
                data: icon,
                feedback: Material(
                  color: Colors.transparent,
                  child: widget.builder(entry.value),
                ),
                childWhenDragging: const SizedBox.shrink(),
                onDragStarted: () {
                  setState(() {
                    draggedItem = icon;
                    selectedIndex = index;
                  });
                },
                onDragUpdate: (details) {
                  setState(() {
                    final draggedItemPosition = details.localPosition;
                    isOutside = isOutOfBounds(draggedItemPosition);
                    updateOrder(details.globalPosition.dx);
                  });
                },
                onDragEnd: (details) {
                  onDragEndHandler();
                },
                child: MouseRegion(
                  onEnter: ((event) {
                    setState(() {
                      hoveredIndex = index;
                    });
                  }),
                  onExit: (event) {
                    setState(() {
                      hoveredIndex = null;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    transform: Matrix4.identity()
                      ..translate(
                        0.0,
                        getTranslationY(index),
                        0.0,
                      ),
                    height: 60,
                    width: 60,
                    alignment: AlignmentDirectional.bottomCenter,
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: 1.15,
                      child: widget.builder(icon),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void updateOrder(double dragX) {
    setState(() {
      final RenderBox renderBox =
          dockKey.currentContext?.findRenderObject() as RenderBox;
      final localPosition = renderBox.globalToLocal(Offset(dragX, 0));
      final dragPosition =
          (localPosition.dx / 60).clamp(0, positions.length).round();

      if (!isOutside) {
        if (!positions.contains(selectedIndex)) {
          positions.add(selectedIndex);
        } else if (dragPosition != positions.indexOf(selectedIndex)) {
          final originalIndex = positions.indexOf(selectedIndex);
          positions.removeAt(originalIndex);
          positions.insert(dragPosition, selectedIndex);
        }
      } else {
        if (selectedIndex != 3) {
          positions.remove(selectedIndex);
        }
      }
    });
  }

  bool isOutOfBounds(Offset draggedPosition) {
    final box = dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;

    final dockBounds = box.localToGlobal(Offset.zero) & box.size;
    return !dockBounds.contains(draggedPosition);
  }

  void onDragEndHandler() {
    setState(() {
      if (isOutside && selectedIndex != -1) {
        positions.insert(selectedIndex, selectedIndex);
      }
      draggedItem = null;
      selectedIndex = -1;
      hoveredItem = null;
      isOutside = false;
    });
  }
}
