"use client";

import { useEffect, useMemo, useState, type CSSProperties } from "react";

import {
  buildRouteSegments,
  pointAlongRoute,
  projectOffset,
  routeProgressAt,
  tileCoordinate,
  type GeoPoint,
} from "../lib/map-projection";

/** Rotterdam — readable street labels at z13, route spans a real neighborhood. */
const DEMO_ROUTE: GeoPoint[] = [
  { lat: 51.9288, lng: 4.4882 },
  { lat: 51.9264, lng: 4.4836 },
  { lat: 51.9242, lng: 4.4792 },
  { lat: 51.9218, lng: 4.4754 },
  { lat: 51.9194, lng: 4.4722 },
  { lat: 51.9170, lng: 4.4694 },
  { lat: 51.9146, lng: 4.4670 },
  { lat: 51.9122, lng: 4.4648 },
];

const PICKUP = DEMO_ROUTE[3]!;
const DESTINATION = DEMO_ROUTE[DEMO_ROUTE.length - 1]!;
const MAP_CENTER = { lat: 51.9204, lng: 4.4764 };
const MAP_ZOOM = 13;
const TILE_RADIUS = 2;
const LOOP_MS = 16000;
const TILE_URL = `https://a.basemaps.cartocdn.com/rastertiles/voyager/${MAP_ZOOM}`;

function lerpAngle(from: number, to: number, alpha: number) {
  const delta = ((to - from + 540) % 360) - 180;
  return from + delta * alpha;
}

function TeslaMarker({ heading }: { heading: number }) {
  return (
    <div
      className="phone-map__tesla"
      style={{ transform: `translate(-50%, -50%) rotate(${heading}deg)` }}
      aria-hidden="true"
    >
      <span className="phone-map__tesla-halo" />
      <svg viewBox="0 0 36 56" fill="none" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="18" cy="28" rx="14" ry="20" fill="#063d2b" opacity="0.12" />
        <rect
          x="7"
          y="14"
          width="22"
          height="32"
          rx="10"
          fill="#ffffff"
          stroke="#063d2b"
          strokeWidth="1.8"
        />
        <path
          d="M11 22h14l-1.8-6.2c-2.2-.9-10-.9-12.2 0L11 22Z"
          fill="#063d2b"
        />
        <rect x="12.5" y="24" width="11" height="6.5" rx="2" fill="#c8ddd2" />
        <rect x="9" y="38" width="5" height="7" rx="2.2" fill="#063d2b" />
        <rect x="22" y="38" width="5" height="7" rx="2.2" fill="#063d2b" />
        <path
          d="M10 14h16c0-4-3.2-7-8-7s-8 3-8 7Z"
          fill="#00b35a"
          opacity="0.9"
        />
      </svg>
    </div>
  );
}

function PickupPin() {
  return (
    <div className="phone-map__pickup-pin" aria-hidden="true">
      <span className="phone-map__pickup-pulse" />
      <svg viewBox="0 0 28 36" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path
          d="M14 1C8.2 1 3.5 5.9 3.5 12c0 8.2 10.5 22.4 10.5 22.4S24.5 20.2 24.5 12C24.5 5.9 19.8 1 14 1Z"
          fill="#00b35a"
          stroke="#fff"
          strokeWidth="2.5"
        />
        <circle cx="14" cy="12" r="4.2" fill="#fff" />
      </svg>
      <span className="phone-map__pin-label">Pickup</span>
    </div>
  );
}

function DestinationPin() {
  return (
    <div className="phone-map__dest-pin" aria-hidden="true">
      <svg viewBox="0 0 32 32" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect
          x="4"
          y="4"
          width="24"
          height="24"
          rx="9"
          fill="#063d2b"
          stroke="#fff"
          strokeWidth="2.5"
        />
        <path
          d="M11 22V13l5-3 5 3v9"
          stroke="#fff"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
      </svg>
    </div>
  );
}

export function PhoneMapCanvas() {
  const [motionEnabled, setMotionEnabled] = useState(true);
  const [car, setCar] = useState({ x: 0, y: 0, heading: 0 });
  const [camera, setCamera] = useState({ x: 0, y: 0 });
  const [routeProgress, setRouteProgress] = useState(0);

  const screenRoute = useMemo(
    () => DEMO_ROUTE.map((point) => projectOffset(point, MAP_CENTER, MAP_ZOOM)),
    [],
  );
  const segments = useMemo(() => buildRouteSegments(screenRoute), [screenRoute]);
  const totalLength = useMemo(
    () => segments.reduce((sum, segment) => sum + segment.length, 0),
    [segments],
  );
  const pickupScreen = useMemo(
    () => projectOffset(PICKUP, MAP_CENTER, MAP_ZOOM),
    [],
  );
  const destinationScreen = useMemo(
    () => projectOffset(DESTINATION, MAP_CENTER, MAP_ZOOM),
    [],
  );

  const centerTile = tileCoordinate(MAP_CENTER, MAP_ZOOM);
  const baseX = Math.floor(centerTile.x);
  const baseY = Math.floor(centerTile.y);
  const offsetX = (centerTile.x - baseX) * 256;
  const offsetY = (centerTile.y - baseY) * 256;

  const routePath = screenRoute
    .map((point, index) => `${index === 0 ? "M" : "L"} ${point.x} ${point.y}`)
    .join(" ");

  const routeBounds = screenRoute.reduce(
    (bounds, point) => ({
      minX: Math.min(bounds.minX, point.x),
      maxX: Math.max(bounds.maxX, point.x),
      minY: Math.min(bounds.minY, point.y),
      maxY: Math.max(bounds.maxY, point.y),
    }),
    { minX: 0, maxX: 0, minY: 0, maxY: 0 },
  );
  const routePadding = 72;
  const viewBox = [
    routeBounds.minX - routePadding,
    routeBounds.minY - routePadding,
    routeBounds.maxX - routeBounds.minX + routePadding * 2,
    routeBounds.maxY - routeBounds.minY + routePadding * 2,
  ].join(" ");

  useEffect(() => {
    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
    setMotionEnabled(!reduced);
    if (reduced) {
      const parked = pointAlongRoute(segments, totalLength, 0.72);
      setCar(parked);
      setCamera({ x: parked.x * 0.32, y: parked.y * 0.32 });
      setRouteProgress(0.72);
      return;
    }

    let frame = 0;
    let start: number | null = null;
    let heading = segments[0]?.heading ?? 0;

    const tick = (timestamp: number) => {
      if (start === null) start = timestamp;
      const elapsed = timestamp - start;
      const t = (elapsed % LOOP_MS) / LOOP_MS;
      const progress = routeProgressAt(t);
      const next = pointAlongRoute(segments, totalLength, progress);
      heading = lerpAngle(heading, next.heading, 0.14);

      setCar({ ...next, heading });
      setRouteProgress(progress);
      setCamera((prev) => ({
        x: prev.x + (next.x * 0.34 - prev.x) * 0.08,
        y: prev.y + (next.y * 0.34 - prev.y) * 0.08,
      }));

      frame = requestAnimationFrame(tick);
    };

    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [segments, totalLength]);

  const tiles = [];
  for (let dy = -TILE_RADIUS; dy <= TILE_RADIUS; dy += 1) {
    for (let dx = -TILE_RADIUS; dx <= TILE_RADIUS; dx += 1) {
      const x = baseX + dx;
      const y = baseY + dy;
      tiles.push(
        <img
          alt=""
          aria-hidden="true"
          className="phone-map__tile"
          decoding="async"
          key={`${x}-${y}`}
          src={`${TILE_URL}/${x}/${y}@2x.png`}
          style={{
            left: `calc(50% + ${dx * 256 - offsetX}px)`,
            top: `calc(50% + ${dy * 256 - offsetY}px)`,
          }}
        />,
      );
    }
  }

  const worldStyle = {
    transform: `translate(${-camera.x}px, ${-camera.y}px)`,
  };

  return (
    <div className="map-canvas phone-map" aria-hidden="true">
      <div className="phone-map__wash" />
      <div className="phone-map__world" style={worldStyle}>
        <div className="phone-map__tiles">{tiles}</div>
        <svg className="phone-map__route" viewBox={viewBox} aria-hidden="true">
          <defs>
            <linearGradient id="routeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stopColor="#00b35a" />
              <stop offset="100%" stopColor="#007f40" />
            </linearGradient>
            <filter id="routeGlow" x="-20%" y="-20%" width="140%" height="140%">
              <feGaussianBlur stdDeviation="2" result="blur" />
              <feMerge>
                <feMergeNode in="blur" />
                <feMergeNode in="SourceGraphic" />
              </feMerge>
            </filter>
          </defs>
          <path d={routePath} className="phone-map__route-casing" />
          <path
            d={routePath}
            className={
              motionEnabled
                ? "phone-map__route-line phone-map__route-line--live"
                : "phone-map__route-line"
            }
            stroke="url(#routeGrad)"
            filter="url(#routeGlow)"
            style={
              motionEnabled
                ? ({
                    strokeDasharray: totalLength,
                    strokeDashoffset: totalLength * (1 - routeProgress * 0.92),
                  } as CSSProperties)
                : undefined
            }
          />
        </svg>
        <div
          className="phone-map__marker-slot phone-map__marker-slot--pickup"
          style={{
            left: `calc(50% + ${pickupScreen.x}px)`,
            top: `calc(50% + ${pickupScreen.y}px)`,
          }}
        >
          <PickupPin />
        </div>
        <div
          className="phone-map__marker-slot"
          style={{
            left: `calc(50% + ${destinationScreen.x}px)`,
            top: `calc(50% + ${destinationScreen.y}px)`,
          }}
        >
          <DestinationPin />
        </div>
        <div
          className="phone-map__vehicle"
          style={{
            left: `calc(50% + ${car.x}px)`,
            top: `calc(50% + ${car.y}px)`,
          }}
        >
          <TeslaMarker heading={car.heading} />
        </div>
      </div>
      <div className="phone-map__fade" />
    </div>
  );
}
