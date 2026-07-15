-- Live Driver Hub goal tiles: postgres changes on driver_earnings_targets.

ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_earnings_targets;
