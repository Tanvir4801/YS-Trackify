import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

class BridgeBottomNavigationBar extends StatefulWidget {
  const BridgeBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.labels,
    required this.icons,
    required this.activeIcons,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<String> labels;
  final List<IconData> icons;
  final List<IconData> activeIcons;

  @override
  State<BridgeBottomNavigationBar> createState() => _BridgeBottomNavigationBarState();
}

class _BridgeBottomNavigationBarState extends State<BridgeBottomNavigationBar> with TickerProviderStateMixin {
  late AnimationController _archController;
  late Animation<double> _archAnimation;
  int _previousIndex = 0;
  
  late List<AnimationController> _liftControllers;
  late List<Animation<double>> _liftAnimations;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;

    _archController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _archAnimation = Tween<double>(begin: _previousIndex.toDouble(), end: widget.currentIndex.toDouble())
        .animate(CurvedAnimation(parent: _archController, curve: Curves.elasticOut));
        
    _liftControllers = List.generate(
      widget.icons.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 400),
      )..value = i == widget.currentIndex ? 1.0 : 0.0,
    );
    _liftAnimations = _liftControllers.map((c) => CurvedAnimation(parent: c, curve: Curves.easeOutBack)).toList();
  }

  @override
  void didUpdateWidget(covariant BridgeBottomNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      
      _liftControllers[_previousIndex].reverse();
      _liftControllers[widget.currentIndex].forward();

      _archAnimation = Tween<double>(begin: _previousIndex.toDouble(), end: widget.currentIndex.toDouble())
          .animate(CurvedAnimation(parent: _archController, curve: Curves.elasticOut));
      _archController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _archController.dispose();
    for (var c in _liftControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double safeBottom = bottomPadding > 0 ? bottomPadding : 24.0;
    
    // Floating Dock Dimensions
    const double dockHeight = 65.0;
    const double dockTop = 50.0; // Space for the tower above the dock
    final double height = dockTop + dockHeight + safeBottom;

    return Container(
      color: Colors.transparent,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Painter
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _archAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _BridgePainter(
                    archPositionIndex: _archAnimation.value,
                    itemCount: widget.icons.length,
                    dockTop: dockTop,
                    dockHeight: dockHeight,
                  ),
                );
              },
            ),
          ),
          
          // Icons Row
          Positioned(
            left: 16,
            right: 16,
            top: dockTop,
            height: dockHeight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(widget.icons.length, (i) {
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onTap(i),
                    child: AnimatedBuilder(
                      animation: _liftAnimations[i],
                      builder: (context, child) {
                        final liftValue = _liftAnimations[i].value;
                        final selected = liftValue > 0.5;
                        
                        // Scale up active icon
                        final scale = 1.0 + (liftValue * 0.25);
                        // Translate up so it acts as the bridge tower overlapping the dock
                        final translateY = -35 * liftValue;
                        
                        return Transform.translate(
                          offset: Offset(0, translateY),
                          child: Transform.scale(
                            scale: scale,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(6 + (4 * liftValue)),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: liftValue > 0.1 ? const Color(0xFF020814) : Colors.transparent, // Dark steel tower
                                    boxShadow: liftValue > 0.1
                                        ? [
                                            BoxShadow(
                                              color: AppColors.gold.withValues(alpha: 0.6 * liftValue),
                                              blurRadius: 16 * liftValue,
                                              spreadRadius: 2 * liftValue,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [],
                                    border: liftValue > 0.1 
                                        ? Border.all(color: AppColors.gold.withValues(alpha: 1.0 * liftValue), width: 2.0)
                                        : null,
                                  ),
                                  child: Icon(
                                    selected ? widget.activeIcons[i] : widget.icons[i],
                                    color: selected ? AppColors.gold : AppColors.textTertiary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                                    color: selected ? AppColors.textPrimary : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _BridgePainter extends CustomPainter {
  final double archPositionIndex;
  final int itemCount;
  final double dockTop;
  final double dockHeight;

  _BridgePainter({
    required this.archPositionIndex,
    required this.itemCount,
    required this.dockTop,
    required this.dockHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double dockLeft = 16.0;
    final double dockRight = size.width - 16.0;
    final double dockBottom = dockTop + dockHeight;
    final double dockWidth = dockRight - dockLeft;

    final double itemWidth = dockWidth / itemCount;
    final double archCenterX = dockLeft + (itemWidth * archPositionIndex) + (itemWidth / 2);

    final Rect dockRect = Rect.fromLTRB(dockLeft, dockTop, dockRight, dockBottom);
    final RRect roundedDock = RRect.fromRectAndRadius(dockRect, const Radius.circular(24.0));

    // 1. Premium Shadow for floating dock
    canvas.drawShadow(Path()..addRRect(roundedDock), Colors.black, 20.0, true);

    // 2. Dark Steel Navbar background
    final Paint paintDock = Paint()
      ..color = const Color(0xFF020814)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(roundedDock, paintDock);

    // 3. Blueprint Grid Texture
    canvas.save();
    canvas.clipRRect(roundedDock);
    final Paint gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
      
    const int gridLines = 24;
    final double gridStep = dockWidth / gridLines;
    for (double i = dockLeft; i < dockRight; i += gridStep) {
      canvas.drawLine(Offset(i, dockTop), Offset(i, dockBottom), gridPaint);
    }
    for (double i = dockTop; i < dockBottom; i += gridStep) {
      canvas.drawLine(Offset(dockLeft, i), Offset(dockRight, i), gridPaint);
    }
    canvas.restore();

    // 4. Golden steel line separating content and navbar
    final Paint fullBorderPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(roundedDock, fullBorderPaint);
    
    // Highlight segment directly under the active tower
    final Paint paintBorderHighlight = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    
    canvas.drawLine(
      Offset(archCenterX - (itemWidth * 0.4), dockTop), 
      Offset(archCenterX + (itemWidth * 0.4), dockTop), 
      paintBorderHighlight
    );

    // 5. Matte golden cables with small animation
    _drawCableStays(canvas, archCenterX, itemWidth, dockTop);
  }

  void _drawCableStays(Canvas canvas, double cx, double itemWidth, double deckY) {
    // Dynamic wobble based on transition progress
    final double movement = (archPositionIndex % 1.0);
    // Wobble dips the origin down by up to 10 pixels mid-transition to simulate cable tension snap
    final double wobble = math.sin(movement * math.pi) * 10.0; 
    
    // Tower origin (attached to the floating button)
    final double towerOriginY = (dockTop - 15.0) + wobble;

    // Matte golden cables (no glow)
    final Paint cableMain = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;

    void drawCable(Offset start, Offset end) {
      canvas.drawLine(start, end, cableMain);
      
      // Draw golden anchor block at the base (deck)
      final Paint anchorPaint = Paint()
        ..color = AppColors.gold.withValues(alpha: 0.9)
        ..style = PaintingStyle.fill;
        
      final Path anchorPath = Path();
      anchorPath.moveTo(end.dx - 3, end.dy);
      anchorPath.lineTo(end.dx + 3, end.dy);
      anchorPath.lineTo(end.dx + 4, end.dy + 4);
      anchorPath.lineTo(end.dx - 4, end.dy + 4);
      anchorPath.close();
      
      canvas.drawPath(anchorPath, anchorPaint);
      
      // Small highlight on the anchor
      final Paint anchorHighlight = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      canvas.drawPath(anchorPath, anchorHighlight);
    }
    
    // Left cables
    drawCable(Offset(cx, towerOriginY), Offset(cx - (itemWidth * 1.3), deckY));
    drawCable(Offset(cx, towerOriginY), Offset(cx - (itemWidth * 0.75), deckY));
    
    // Center vertical cable
    drawCable(Offset(cx, towerOriginY), Offset(cx, deckY));
    
    // Right cables
    drawCable(Offset(cx, towerOriginY), Offset(cx + (itemWidth * 0.75), deckY));
    drawCable(Offset(cx, towerOriginY), Offset(cx + (itemWidth * 1.3), deckY));
  }

  @override
  bool shouldRepaint(covariant _BridgePainter oldDelegate) {
    return oldDelegate.archPositionIndex != archPositionIndex ||
           oldDelegate.itemCount != itemCount;
  }
}
