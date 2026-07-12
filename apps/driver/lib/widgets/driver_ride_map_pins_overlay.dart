import 'dart:async';

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
    this.driverLat,
    this.driverLng,
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
  final double? driverLat;
  final double? driverLng;
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
  Timer? _secondaryDelay;
  Offset? _pickupPx;
  Offset? _dropoffPx;
  Offset? _driverPx;

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
    _secondaryDelay = Timer(const Duration(milliseconds: 700), () {
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
        oldWidget.destinationLng != widget.destinationLng ||
        oldWidget.driverLat != widget.driverLat ||
        oldWidget.driverLng != widget.driverLng) {
      _refreshPositions();
    }
  }

  Future<void> _refreshPositions() async {
    final map = widget.mapboxMap;
    if (map == null || !mounted) return;

    Offset? pickup;
    Offset? dropoff;
    Offset? driver;

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

    if (driverMapCoordIsValid(widget.driverLat, widget.driverLng)) {
      try {
        final px = await map.pixelForCoordinate(
          Point(coordinates: Position(widget.driverLng!, widget.driverLat!)),
        );
        driver = Offset(px.x, px.y);
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
      _driverPx = driver;
    });
  }

  @override
  void dispose() {
    _secondaryDelay?.cancel();
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
          if (_pickupPx != null)
            _positionedPin(
              _pickupPx!,
              widget.pickupColor,
              _DriverMapMarkerKind.pickup,
            ),
          if (_dropoffPx != null)
            _positionedPin(
              _dropoffPx!,
              widget.dropoffColor,
              _DriverMapMarkerKind.dropoff,
            ),
          if (_driverPx != null) _positionedCar(_driverPx!),
        ],
      ),
    );
  }

  Widget _positionedPin(
    Offset anchor,
    Color color,
    _DriverMapMarkerKind kind,
  ) {
    final pinW = widget.pinSize * 1.55;
    final pinH = widget.pinSize * 1.35;
    return Positioned(
      left: anchor.dx - pinW / 2,
      top: anchor.dy - pinH,
      child: _DriverRideMapPin(
        color: color,
        kind: kind,
        pulsePrimary: _pulsePrimary,
        pulseSecondary: _pulseSecondary,
        size: widget.pinSize,
      ),
    );
  }

  Widget _positionedCar(Offset anchor) {
    final width = widget.pinSize * 0.92;
    final height = widget.pinSize * 1.18;
    return Positioned(
      left: anchor.dx - width / 2,
      top: anchor.dy - height / 2,
      child: CustomPaint(
        size: Size(width, height),
        painter: _DriverClayCarPainter(color: widget.pickupColor),
      ),
    );
  }
}

enum _DriverMapMarkerKind { pickup, dropoff }

class _DriverRideMapPin extends StatelessWidget {
  const _DriverRideMapPin({
    required this.color,
    required this.kind,
    required this.pulsePrimary,
    required this.pulseSecondary,
    required this.size,
  });

  final Color color;
  final _DriverMapMarkerKind kind;
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
              kind: kind,
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
    required this.kind,
    required this.pulseA,
    required this.pulseB,
  });

  final Color color;
  final _DriverMapMarkerKind kind;
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

    final glyphCenter = Offset(anchor.dx, anchor.dy - 24);
    final glyph = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (kind == _DriverMapMarkerKind.pickup) {
      canvas.drawCircle(glyphCenter.translate(0, -4), 3.4, glyph);
      glyph
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6;
      canvas.drawLine(
        glyphCenter.translate(0, 1),
        glyphCenter.translate(0, 8),
        glyph,
      );
      canvas.drawLine(
        glyphCenter.translate(-5, 4),
        glyphCenter.translate(5, 4),
        glyph,
      );
    } else {
      glyph
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;
      canvas.drawLine(
        glyphCenter.translate(-5, -8),
        glyphCenter.translate(-5, 9),
        glyph,
      );
      glyph.style = PaintingStyle.fill;
      canvas.drawRect(
        Rect.fromLTWH(glyphCenter.dx - 4, glyphCenter.dy - 7, 5, 5),
        glyph,
      );
      canvas.drawRect(
        Rect.fromLTWH(glyphCenter.dx + 1, glyphCenter.dy - 2, 5, 5),
        glyph,
      );
      glyph.color = Colors.white.withValues(alpha: 0.35);
      canvas.drawRect(
        Rect.fromLTWH(glyphCenter.dx + 1, glyphCenter.dy - 7, 5, 5),
        glyph,
      );
      canvas.drawRect(
        Rect.fromLTWH(glyphCenter.dx - 4, glyphCenter.dy - 2, 5, 5),
        glyph,
      );
    }
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
      oldDelegate.kind != kind ||
      oldDelegate.pulseA != pulseA ||
      oldDelegate.pulseB != pulseB;
}

class _DriverClayCarPainter extends CustomPainter {
  const _DriverClayCarPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.08, size.width * 0.68,
          size.height * 0.84),
      Radius.circular(size.width * 0.28),
    );
    canvas.drawRRect(body.shift(const Offset(0, 4)), shadow);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.45)!, color],
        ).createShader(body.outerRect),
    );
    final glass = Paint()
      ..color = const Color(0xFF344054).withValues(alpha: 0.86);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.27, size.height * 0.24, size.width * 0.46,
            size.height * 0.27),
        const Radius.circular(7),
      ),
      glass,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.27, size.height * 0.58, size.width * 0.46,
            size.height * 0.15),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF667085).withValues(alpha: 0.75),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.08),
      3.2,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DriverClayCarPainter oldDelegate) =>
      oldDelegate.color != color;
}
