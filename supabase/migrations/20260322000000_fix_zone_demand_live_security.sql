-- Migration 047: Fix zone_demand_live view security_invoker
-- This fixes the 400 error when drivers query zone_demand_live
-- The view was using SECURITY DEFINER which caused permission issues

ALTER VIEW zone_demand_live SET (security_invoker = true);
