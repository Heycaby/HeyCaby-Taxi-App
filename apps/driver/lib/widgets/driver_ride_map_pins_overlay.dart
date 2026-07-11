import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide Size;

import 'driver_ride_flow_common.dart';

/// Animated pickup / drop-off pins projected onto the driver ride map.
class DriverRideMapPinsOverlay extends StatefulWidget {
  const DriverRideMapPinsOverlay({
    super.key,
    required this.mapboxMap,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    required this.pickupColor,
    required this.dropoffColor,
    this.cameraTick = 0,
    this.pinSize = 46,
  });

  final MapboxMap? mapboxMap;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final Color pickupColor;
  final Color dropoffColor;
  final int cameraTick;
  final double pinSize;

  @override
  State<DriverRideMapPinsOverlay> createState() =>
      _DriverRideMapPinsOverlayState();
}

class _DriverRideMapPinsOverlayState extends State<DriverRideMapPinsOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulsePrimary;
  late final AnimationController _pulseSecondary;
  Offset? _pickupPx;
  Offset? _dropoffPx;

  @override
  void initState() {
    super.initState();
    _pulsePrimary = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _pulseSecondary = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) _pulseSecondary.repeat();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPositions());
  }

  @override
  void didUpdateWidget(covariant DriverRideMapPinsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mapboxMap != widget.mapboxMap ||
        oldWidget.cameraTick != widget.cameraTick ||
        oldWidget.pickupLat != widget.pickupLat ||
        oldWidget.pickupLng != widget.pickupLng ||
        oldWidget.destinationLat != widget.destinationLat ||
        oldWidget.destinationLng != widget.destinationLng) {
      _refreshPositions();
    }
  }

  Future<void> _refreshPositions() async {
    final map = widget.mapboxMap;
    if (map == null || !mounted) return;

    Offset? pickup;
    Offset? dropoff;

    if (driverMapCoordIsValid(widget.pickupLat, widget.pickupLng)) {
      try {
        final px = await map.pixelForCoordinate(
          Point(
            coordinates: Position(widget.pickupLng!, widget.pickupLat!),
          ),
        );
        pickup = Offset(px.x, px.y);
      } catch (_) {}
    }

    if (driverMapCoordIsValid(widget.destinationLat, widget.destinationLng)) {
      try {
        final px = await map.pixelForCoordinate(
          Point(
            coordinates: Position(
              widget.destinationLng!,
              widget.destinationLat!,
            ),
          ),
        );
        dropoff = Offset(px.x, px.y);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _pickupPx = pickup;
      _dropoffPx = dropoff;
    });
  }

  @override
  void dispose() {
    _pulsePrimary.dispose();
    _pulseSecondary.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (_pickupPx != null) _positionedPin(_pickupPx!, widget.pickupColor),
          if (_dropoffPx != null)
            _positionedPin(_dropoffPx!, widget.dropoffColor),
        ],
      ),
    );
  }

  Widget _positionedPin(Offset anchor, Color color) {
    final pinW = widget.pinSize * 1.55;
    final pinH = widget.pinSize * 1.35;
    return Positioned(
      left: anchor.dx - pinW / 2,
      top: anchor.dy - pinH,
      child: _DriverRideMapPin(
        color: color,
        pulsePrimary: _pulsePrimary,
        pulseSecondary: _pulseSecondary,
        size: widget.pinSize,
      ),
    );
  }
}

class _DriverRideMapPin extends StatelessWidget {
  const _DriverRideMapPin({
    required this.color,
    required this.pulsePrimary,
    required this.pulseSecondary,
    required this.size,
  });

  final Color color;
  final Animation<double> pulsePrimary;
  final Animation<double> pulseSecondary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.55,
      height: size * 1.35,
      child: AnimatedBuilder(
        animation: Listenable.merge([pulsePrimary, pulseSecondary]),
        builder: (context, child) {
          return CustomPaint(
            painter: _DriverRideMapPinPainter(
              color: color,
              pulseA: Curves.easeOutCubic.transform(pulsePrimary.value),
              pulseB: Curves.easeOutCubic.transform(pulseSecondary.value),
            ),
            child: child,
          );
        },
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: 7,
            height: 7,
            margin: EdgeInsets.only(bottom: size * 0.04),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.55),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverRideMapPinPainter extends CustomPainter {
  _DriverRideMapPinPainter({
    required this.color,
    required this.pulseA,
    required this.pulseB,
  });

  final Color color;
  final double pulseA;
  final double pulseB;

  @override
  void paint(Canvas canvas, Size size) {
    final anchor = Offset(size.width / 2, size.height * 0.92);
    _drawPulseRing(canvas, anchor, pulseA, 0.34);
    _drawPulseRing(canvas, anchor, pulseB, 0.22);

    final bodyPath = Path()
      ..moveTo(anchor.dx, anchor.dy)
      ..lineTo(anchor.dx - 11, anchor.dy - 24)
      ..lineTo(anchor.dx, anchor.dy - 38)
      ..lineTo(anchor.dx + 11, anchor.dy - 24)
      ..close();

    final glow = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawPath(bodyPath, glow);

    final bodyFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.35)!,
          color,
          color.withValues(alpha: 0.92),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(bodyPath, bodyFill);

    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(bodyPath, stroke);
  }

  void _drawPulseRing(Canvas canvas, Offset center, double t, double maxAlpha) {
    if (t <= 0.01) return;
    final radius = 10 + t * 28;
    final ring = Paint()
      ..color = color.withValues(alpha: maxAlpha * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 - t;
    canvas.drawCircle(center, radius, ring);
  }

  @override
  bool shouldRepaint(covariant _DriverRideMapPinPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.pulseA != pulseA ||
      oldDelegate.pulseB != pulseB;
}
