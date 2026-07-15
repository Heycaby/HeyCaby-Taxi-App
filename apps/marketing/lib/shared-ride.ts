export const SHARED_RIDE_TOKEN_PATTERN = /^[a-f0-9]{24}$/i;

export type Point = { lat: number; lng: number };

export type SharedRideProjection = {
  ride_id: string;
  status: string;
  tracking_active: boolean;
  terminal: boolean;
  expires_at: string;
  server_time: string;
  pickup_address: string | null;
  destination_address: string | null;
  pickup: Point | null;
  destination: Point | null;
  stops: Array<{ address?: string; lat?: number; lng?: number }>;
  route_revision: number;
  scheduled_pickup_at: string | null;
  driver: {
    first_name: string | null;
    vehicle: string | null;
    plate: string | null;
    rating: number | null;
  } | null;
  driver_location: (Point & {
    heading: number | null;
    updated_at: string;
    stale: boolean;
    age_seconds: number;
  }) | null;
};
