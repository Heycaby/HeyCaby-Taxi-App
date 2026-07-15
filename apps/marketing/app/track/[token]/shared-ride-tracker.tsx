"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import {
  SHARED_RIDE_TOKEN_PATTERN,
  type Point,
  type SharedRideProjection,
} from "../../../lib/shared-ride";
import styles from "./tracker.module.css";

type Locale = "nl" | "en" | "ar";
type ViewState = "loading" | "ready" | "not_found" | "offline";

const copy = {
  nl: {
    live: "Live rit",
    loading: "Rit wordt geladen…",
    unavailable: "Deze ritlink is verlopen of niet meer beschikbaar.",
    retry: "Opnieuw proberen",
    connection: "Verbinding herstellen…",
    stale: "Locatie wordt bijgewerkt",
    updated: "Bijgewerkt",
    pickup: "Ophaallocatie",
    destination: "Bestemming",
    driver: "Jouw chauffeur",
    noLocation: "De live locatie verschijnt zodra de chauffeur onderweg is.",
    ended: "Deze rit is afgelopen. Live locatie wordt niet meer gedeeld.",
    privacy: "Alleen mensen met deze link kunnen deze rit bekijken.",
    statuses: {
      assigned: "Chauffeur gevonden",
      accepted: "Chauffeur gevonden",
      driver_found: "Chauffeur gevonden",
      driver_en_route: "Chauffeur is onderweg",
      driver_arrived: "Chauffeur is gearriveerd",
      arrived: "Chauffeur is gearriveerd",
      in_progress: "Onderweg naar de bestemming",
      completed: "Aangekomen op de bestemming",
      cancelled: "Rit geannuleerd",
      canceled: "Rit geannuleerd",
      rider_cancelled: "Rit geannuleerd",
      driver_cancelled: "Rit geannuleerd",
      expired: "Rit verlopen",
    },
  },
  en: {
    live: "Live trip",
    loading: "Loading trip…",
    unavailable: "This trip link has expired or is no longer available.",
    retry: "Try again",
    connection: "Reconnecting…",
    stale: "Updating location",
    updated: "Updated",
    pickup: "Pickup",
    destination: "Destination",
    driver: "Your driver",
    noLocation: "The live location appears when the driver is on the way.",
    ended: "This trip has ended. Live location is no longer shared.",
    privacy: "Only people with this link can view this trip.",
    statuses: {
      assigned: "Driver found",
      accepted: "Driver found",
      driver_found: "Driver found",
      driver_en_route: "Driver is on the way",
      driver_arrived: "Driver has arrived",
      arrived: "Driver has arrived",
      in_progress: "On the way to the destination",
      completed: "Arrived at the destination",
      cancelled: "Trip cancelled",
      canceled: "Trip cancelled",
      rider_cancelled: "Trip cancelled",
      driver_cancelled: "Trip cancelled",
      expired: "Trip expired",
    },
  },
  ar: {
    live: "رحلة مباشرة",
    loading: "جارٍ تحميل الرحلة…",
    unavailable: "انتهت صلاحية رابط الرحلة أو لم يعد متاحًا.",
    retry: "إعادة المحاولة",
    connection: "جارٍ استعادة الاتصال…",
    stale: "جارٍ تحديث الموقع",
    updated: "آخر تحديث",
    pickup: "موقع الانطلاق",
    destination: "الوجهة",
    driver: "السائق",
    noLocation: "سيظهر الموقع المباشر عندما يبدأ السائق بالتحرك.",
    ended: "انتهت الرحلة ولم يعد الموقع المباشر قيد المشاركة.",
    privacy: "يمكن فقط لمن يملك هذا الرابط مشاهدة الرحلة.",
    statuses: {
      assigned: "تم العثور على سائق",
      accepted: "تم العثور على سائق",
      driver_found: "تم العثور على سائق",
      driver_en_route: "السائق في الطريق",
      driver_arrived: "وصل السائق",
      arrived: "وصل السائق",
      in_progress: "في الطريق إلى الوجهة",
      completed: "تم الوصول إلى الوجهة",
      cancelled: "أُلغيت الرحلة",
      canceled: "أُلغيت الرحلة",
      rider_cancelled: "أُلغيت الرحلة",
      driver_cancelled: "أُلغيت الرحلة",
      expired: "انتهت صلاحية الرحلة",
    },
  },
} as const;

function localeForBrowser(): Locale {
  const language = navigator.language.toLowerCase();
  if (language.startsWith("ar")) return "ar";
  if (language.startsWith("nl")) return "nl";
  return "en";
}

function tileCoordinate(point: Point, zoom: number) {
  const scale = 2 ** zoom;
  const x = ((point.lng + 180) / 360) * scale;
  const latitude = Math.min(85.05112878, Math.max(-85.05112878, point.lat));
  const rad = (latitude * Math.PI) / 180;
  const y =
    (1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) /
    2 *
    scale;
  return { x, y };
}

function LiveMap({
  location,
  pickup,
  destination,
}: {
  location: Point & { heading: number | null };
  pickup: Point | null;
  destination: Point | null;
}) {
  const zoom = 15;
  const center = tileCoordinate(location, zoom);
  const baseX = Math.floor(center.x);
  const baseY = Math.floor(center.y);
  const offsetX = (center.x - baseX) * 256;
  const offsetY = (center.y - baseY) * 256;
  const tiles = [];

  for (let dy = -1; dy <= 1; dy += 1) {
    for (let dx = -1; dx <= 1; dx += 1) {
      const x = baseX + dx;
      const y = baseY + dy;
      tiles.push(
        <img
          alt=""
          aria-hidden="true"
          className={styles.tile}
          key={`${x}-${y}`}
          src={`https://a.basemaps.cartocdn.com/rastertiles/voyager/${zoom}/${x}/${y}@2x.png`}
          style={{
            left: `calc(50% + ${dx * 256 - offsetX}px)`,
            top: `calc(50% + ${dy * 256 - offsetY}px)`,
          }}
        />,
      );
    }
  }

  const markerStyle = (point: Point) => {
    const projected = tileCoordinate(point, zoom);
    return {
      left: `calc(50% + ${(projected.x - center.x) * 256}px)`,
      top: `calc(50% + ${(projected.y - center.y) * 256}px)`,
    };
  };

  return (
    <div className={styles.map} aria-label="Live driver location">
      <div className={styles.tiles}>{tiles}</div>
      {pickup ? (
        <span className={`${styles.routeMarker} ${styles.pickupMarker}`} style={markerStyle(pickup)} />
      ) : null}
      {destination ? (
        <span className={`${styles.routeMarker} ${styles.destinationMarker}`} style={markerStyle(destination)} />
      ) : null}
      <span
        className={styles.carMarker}
        style={{ transform: `translate(-50%, -50%) rotate(${location.heading ?? 0}deg)` }}
      >
        ↑
      </span>
      <div className={styles.attribution}>
        © <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> · © CARTO
      </div>
    </div>
  );
}

export function SharedRideTracker({ token }: { token: string }) {
  const [locale, setLocale] = useState<Locale>("nl");
  const [viewState, setViewState] = useState<ViewState>("loading");
  const [ride, setRide] = useState<SharedRideProjection | null>(null);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const rideRef = useRef<SharedRideProjection | null>(null);
  const fetchingRef = useRef(false);
  const mountedRef = useRef(true);
  const t = copy[locale];

  useEffect(() => setLocale(localeForBrowser()), []);

  const refresh = useCallback(async () => {
    if (fetchingRef.current) return;
    fetchingRef.current = true;
    if (timerRef.current) clearTimeout(timerRef.current);

    if (!SHARED_RIDE_TOKEN_PATTERN.test(token)) {
      setViewState("not_found");
      fetchingRef.current = false;
      return;
    }

    try {
      const response = await fetch("/api/shared-ride", {
        method: "POST",
        cache: "no-store",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ token }),
      });
      if (!mountedRef.current) return;
      if (response.status === 404) {
        setRide(null);
        setViewState("not_found");
        return;
      }
      if (!response.ok) throw new Error(`shared_ride_${response.status}`);

      const nextRide = (await response.json()) as SharedRideProjection;
      rideRef.current = nextRide;
      setRide(nextRide);
      setViewState("ready");
    } catch {
      if (mountedRef.current) {
        setViewState(rideRef.current ? "ready" : "offline");
      }
    } finally {
      fetchingRef.current = false;
      if (
        mountedRef.current &&
        rideRef.current != null &&
        rideRef.current.terminal !== true
      ) {
        timerRef.current = setTimeout(refresh, 4000);
      }
    }
  }, [token]);

  useEffect(() => {
    mountedRef.current = true;
    void refresh();
    const resume = () => {
      if (document.visibilityState === "visible") void refresh();
    };
    window.addEventListener("online", resume);
    document.addEventListener("visibilitychange", resume);
    return () => {
      mountedRef.current = false;
      if (timerRef.current) clearTimeout(timerRef.current);
      window.removeEventListener("online", resume);
      document.removeEventListener("visibilitychange", resume);
    };
  }, [refresh]);

  const statusLabel = useMemo(() => {
    if (!ride) return "";
    return t.statuses[ride.status as keyof typeof t.statuses] ?? ride.status;
  }, [ride, t]);

  const updatedLabel = ride?.driver_location?.updated_at
    ? new Intl.DateTimeFormat(locale === "ar" ? "ar" : locale, {
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
      }).format(new Date(ride.driver_location.updated_at))
    : null;

  return (
    <main className={styles.shell} dir={locale === "ar" ? "rtl" : "ltr"}>
      <header className={styles.header}>
        <a className={styles.brand} href="/" aria-label="HeyCaby home">
          <span>Hey</span><b>Caby</b>
        </a>
        <span className={styles.liveBadge}><i />{t.live}</span>
      </header>

      {viewState === "loading" ? (
        <section className={styles.stateCard} aria-live="polite">
          <div className={styles.spinner} />
          <h1>{t.loading}</h1>
        </section>
      ) : viewState === "not_found" ? (
        <section className={styles.stateCard} aria-live="polite">
          <div className={styles.stateIcon}>×</div>
          <h1>{t.unavailable}</h1>
          <p>{t.privacy}</p>
        </section>
      ) : viewState === "offline" ? (
        <section className={styles.stateCard} aria-live="polite">
          <div className={styles.stateIcon}>↻</div>
          <h1>{t.connection}</h1>
          <button onClick={() => void refresh()} type="button">{t.retry}</button>
        </section>
      ) : ride ? (
        <div className={styles.content}>
          <section className={styles.heroCard}>
            <div>
              <p className={styles.eyebrow}>{t.live}</p>
              <h1>{statusLabel}</h1>
              <p className={styles.connectionLine} aria-live="polite">
                {ride.driver_location?.stale ? t.stale : updatedLabel ? `${t.updated} ${updatedLabel}` : t.noLocation}
              </p>
            </div>
            <div className={styles.statusPulse} aria-hidden="true"><i /></div>
          </section>

          {ride.terminal ? (
            <section className={styles.endedCard}>{t.ended}</section>
          ) : ride.driver_location ? (
            <LiveMap
              location={ride.driver_location}
              pickup={ride.pickup}
              destination={ride.destination}
            />
          ) : (
            <section className={styles.mapPlaceholder}>{t.noLocation}</section>
          )}

          <section className={styles.detailsGrid}>
            <article className={styles.routeCard}>
              <div className={styles.routeLine} aria-hidden="true"><i /><span /><b /></div>
              <div>
                <small>{t.pickup}</small>
                <p>{ride.pickup_address ?? "—"}</p>
                <small>{t.destination}</small>
                <p>{ride.destination_address ?? "—"}</p>
              </div>
            </article>

            <article className={styles.driverCard}>
              <small>{t.driver}</small>
              <div className={styles.driverRow}>
                <span className={styles.avatar}>{ride.driver?.first_name?.slice(0, 1) ?? "H"}</span>
                <div>
                  <h2>{ride.driver?.first_name ?? "HeyCaby"}</h2>
                  <p>{[ride.driver?.vehicle, ride.driver?.plate].filter(Boolean).join(" · ") || "—"}</p>
                </div>
                {ride.driver?.rating != null ? <strong>★ {Number(ride.driver.rating).toFixed(1)}</strong> : null}
              </div>
            </article>
          </section>

          <p className={styles.privacy}>{t.privacy}</p>
        </div>
      ) : null}
    </main>
  );
}
