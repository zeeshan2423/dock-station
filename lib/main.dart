import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Entry point of the application.
void main() {
  runApp(const MyApp());
}

/// [Widget] building the [MaterialApp].
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

/// Dock of the reorderable [items].
class Dock extends StatefulWidget {
  const Dock({
    super.key,
    this.items = const [],
    required this.builder,
  });

  /// Initial [IconData] items to put in this [Dock].
  final List<IconData> items;

  /// Builder building the provided [IconData] item.
  final Widget Function(IconData) builder;

  @override
  State<Dock> createState() => _DockState();
}

/// State of the [Dock] used to manipulate the [_items].
class _DockState extends State<Dock> {
  /// [IconData] items being manipulated.
  late final List<IconData> _items = widget.items.toList();

  IconData? _draggedItem;
  IconData? _hoveredItem; // Track the hovered item for enlarging
  bool _isItemOutside = false; // To track if the dragged item is outside
  int _draggedItemIndex = -1; // To track the index of the dragged item
  final GlobalKey _dockKey =
      GlobalKey(); // Key for the dock area to track bounds

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen drag target to detect outside drops
        SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          child: DragTarget<IconData>(
            onAcceptWithDetails: (details) {
              setState(() {
                // When the item is released, ensure it is added back to the list
                if (_draggedItem != null && _isItemOutside) {
                  // If the dragged item is outside, move it to the last position
                  _items.remove(_draggedItem);
                  _items.add(_draggedItem!); // Add to the last position
                }
                _draggedItem = null;
                _draggedItemIndex = -1;
                _isItemOutside = false;
              });
            },
            onWillAcceptWithDetails: (icon) => true,
            builder: (context, candidateData, rejectedData) {
              return const SizedBox.expand(); // Full screen for drag target
            },
          ),
        ),

        // Dock in the center (row remains unchanged)
        Center(
          child: AnimatedContainer(
            key: _dockKey, // Attach the key to the dock container
            duration: const Duration(milliseconds: 300), // Animation duration
            curve: Curves.easeInOut, // Smooth animation curve
            width: _isItemOutside ? 264.0 : 328.0, // Adjust width when outside
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black12,
            ),
            padding: const EdgeInsets.all(4),
            child: SizedBox(
              height: 64,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: _items
                    .asMap()
                    .entries
                    .map(
                      (entry) => LongPressDraggable<IconData>(
                        key: ValueKey(entry.key),
                        data: entry.value,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.25, // Enlarge the icon while dragging
                            child: widget.builder(entry.value),
                          ),
                        ),
                        childWhenDragging:
                            _isItemOutside ? const SizedBox.shrink() : null,
                        onDragStarted: () {
                          setState(() {
                            _draggedItem = entry.value;
                            _draggedItemIndex = entry.key;
                          });
                        },
                        onDragUpdate: (details) {
                          final draggedItemPosition = details.localPosition;
                          setState(() {
                            // Check if the dragged item is outside the dock bounds
                            _isItemOutside =
                                _isDraggedItemOutside(draggedItemPosition);
                            if (!_isItemOutside) {
                              final box = _dockKey.currentContext
                                  ?.findRenderObject() as RenderBox?;
                              if (box != null) {
                                final localPosition =
                                    box.globalToLocal(details.globalPosition);
                                setState(() {
                                  _reorderItems(localPosition.dx);
                                });
                              }
                            }
                          });
                        },
                        onDragEnd: (_) {
                          setState(() {
                            _draggedItem = null;
                            _draggedItemIndex = -1;
                          });
                        },
                        child: MouseRegion(
                          onEnter: (_) {
                            setState(() {
                              _hoveredItem = entry.value; // Set hovered item
                            });
                          },
                          onExit: (_) {
                            setState(() {
                              _hoveredItem = null; // Clear hovered item
                            });
                          },
                          child: AnimatedBuilder(
                            animation: Listenable.merge([
                              _hoveredItem != null
                                  ? ValueNotifier(_hoveredItem!)
                                  : ValueNotifier(null)
                            ]),
                            builder: (context, child) {
                              double scale = 1.0;

                              if (_hoveredItem == entry.value) {
                                scale = 1.25; // Focused item scale
                              } else if (_hoveredItem != null &&
                                  (entry.key ==
                                          _items.indexOf(_hoveredItem!) - 1 ||
                                      entry.key ==
                                          _items.indexOf(_hoveredItem!) + 1)) {
                                scale = 1.125; // Adjacent item scale
                              }

                              return AnimatedScale(
                                duration: const Duration(milliseconds: 300),
                                scale: scale,
                                child: widget.builder(entry.value),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Reorder the items based on the dragged position.
  void _reorderItems(double draggedItemX) {
    const itemWidth = 72.0; // Icon width + margin
    final newIndex = (draggedItemX / itemWidth).floor();
    if (newIndex >= 0 &&
        newIndex < _items.length &&
        newIndex != _draggedItemIndex) {
      setState(() {
        final draggedItem = _items.removeAt(_draggedItemIndex);
        _items.insert(newIndex, draggedItem);
        _draggedItemIndex = newIndex;
      });
    }
  }

  /// Check if the dragged item is outside the dock's bounds.
  bool _isDraggedItemOutside(Offset draggedPosition) {
    final box = _dockKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return false;

    final dockBounds = box.localToGlobal(Offset.zero) & box.size;
    return !dockBounds.contains(draggedPosition);
  }
}
