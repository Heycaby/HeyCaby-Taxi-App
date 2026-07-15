export type GeoPoint = { lat: number; lng: number };

export function tileCoordinate(point: GeoPoint, zoom: number) {
  const scale = 2 ** zoom;
  const x = ((point.lng + 180) / 360) * scale;
  const latitude = Math.min(85.05112878, Math.max(-85.05112878, point.lat));
  const rad = (latitude * Math.PI) / 180;
  const y =
    ((1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2) * scale;
  return { x, y };
}

/** Web Mercator pixel offset from map center (256px per tile at zoom). */
export function projectOffset(point: GeoPoint, center: GeoPoint, zoom: number) {
  const projected = tileCoordinate(point, zoom);
  const origin = tileCoordinate(center, zoom);
  return {
    x: (projected.x - origin.x) * 256,
    y: (projected.y - origin.y) * 256,
  };
}

export type ScreenPoint = { x: number; y: number };

export function buildRouteSegments(points: ScreenPoint[]) {
  const segments: Array<{
    from: ScreenPoint;
    to: ScreenPoint;
    length: number;
    heading: number;
  }> = [];

  for (let index = 1; index < points.length; index += 1) {
    const from = points[index - 1]!;
    const to = points[index]!;
    const dx = to.x - from.x;
    const dy = to.y - from.y;
    const length = Math.hypot(dx, dy);
    segments.push({
      from,
      to,
      length,
      heading: (Math.atan2(dy, dx) * 180) / Math.PI + 90,
    });
  }

  return segments;
}

/** progress 0..1 along polyline by arc length */
export function pointAlongRoute(
  segments: ReturnType<typeof buildRouteSegments>,
  totalLength: number,
  progress: number,
): ScreenPoint & { heading: number } {
  if (segments.length === 0 || totalLength <= 0) {
    return { x: 0, y: 0, heading: 0 };
  }

  const clamped = Math.min(1, Math.max(0, progress));
  const target = clamped * totalLength;
  let walked = 0;

  for (const segment of segments) {
    if (walked + segment.length >= target) {
      const ratio =
        segment.length === 0 ? 0 : (target - walked) / segment.length;
      return {
        x: segment.from.x + (segment.to.x - segment.from.x) * ratio,
        y: segment.from.y + (segment.to.y - segment.from.y) * ratio,
        heading: segment.heading,
      };
    }
    walked += segment.length;
  }

  const last = segments[segments.length - 1]!;
  return { x: last.to.x, y: last.to.y, heading: last.heading };
}

/** Piecewise timeline: driver → pickup → destination with brief holds. */
export function routeProgressAt(t: number) {
  const loop = t % 1;
  if (loop < 0.34) return (loop / 0.34) * 0.42;
  if (loop < 0.4) return 0.42;
  if (loop < 0.92) return 0.42 + ((loop - 0.4) / 0.52) * 0.58;
  return 1;
}
