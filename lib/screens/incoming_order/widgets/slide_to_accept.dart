// SlideToAcceptButton — slider "glisser pour accepter" pour l'ecran
// IncomingOrder.
//
// Pattern POS : le slide force un geste intentionnel (evite les faux positifs
// "tap accidentel" sous les gants, en cuisine, sous pression). Cible tactile
// >= 64dp, track 80% de la largeur, contraste fort.
//
// Une fois le handle a droite (>= 85% de la course), le callback [onCompleted]
// est appele une seule fois. Le handle reste en place jusqu'a reset() via
// [resetKey] (change le key pour reset).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SlideToAcceptButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color trackColor;
  final Color handleColor;
  final Color labelColor;
  final Color iconColor;
  final double height;
  final bool enabled;
  final VoidCallback onCompleted;

  const SlideToAcceptButton({
    super.key,
    required this.label,
    required this.onCompleted,
    this.icon = Icons.arrow_forward_rounded,
    this.trackColor = const Color(0x33FFFFFF),
    this.handleColor = Colors.white,
    this.labelColor = Colors.white,
    this.iconColor = const Color(0xFFFF5A1F),
    this.height = 72,
    this.enabled = true,
  });

  @override
  State<SlideToAcceptButton> createState() => _SlideToAcceptButtonState();
}

class _SlideToAcceptButtonState extends State<SlideToAcceptButton>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _maxDrag = 0;
  bool _completed = false;
  late final AnimationController _resetController;

  static const double _completionThreshold = 0.85;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        setState(() {
          _dragX = _dragX * (1 - _resetController.value);
        });
      });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _completed) return;
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(0.0, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails _) {
    if (!widget.enabled || _completed) return;
    if (_maxDrag <= 0) return;
    if (_dragX / _maxDrag >= _completionThreshold) {
      _completed = true;
      setState(() => _dragX = _maxDrag);
      HapticFeedback.heavyImpact();
      widget.onCompleted();
    } else {
      HapticFeedback.selectionClick();
      _resetController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final handleSize = widget.height - 12.h;
        _maxDrag = math.max(0, constraints.maxWidth - handleSize - 12.w);
        final progress = _maxDrag == 0 ? 0.0 : (_dragX / _maxDrag);
        final labelOpacity = (1 - progress * 1.4).clamp(0.0, 1.0);

        return SizedBox(
          height: widget.height,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Track
              Container(
                height: widget.height,
                decoration: BoxDecoration(
                  color: widget.trackColor,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
              ),
              // Label centre (fade out a mesure qu'on glisse)
              Center(
                child: Opacity(
                  opacity: labelOpacity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_right_rounded,
                        color: widget.labelColor.withValues(alpha: 0.55),
                        size: 24.sp,
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: widget.labelColor.withValues(alpha: 0.8),
                        size: 24.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.labelColor,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Handle draggable
              Positioned(
                left: 6.w + _dragX,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: widget.handleColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                      size: 32.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
