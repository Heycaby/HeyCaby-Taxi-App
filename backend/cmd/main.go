package main

import (
	"context"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	fiberlogger "github.com/gofiber/fiber/v2/middleware/logger"
	"github.com/gofiber/fiber/v2/middleware/recover"

	"github.com/heycaby/backend/internal/cache"
	"github.com/heycaby/backend/internal/config"
	"github.com/heycaby/backend/internal/handler"
	authmw "github.com/heycaby/backend/internal/middleware/auth"
	flagsmw "github.com/heycaby/backend/internal/middleware/flags"
	regionmw "github.com/heycaby/backend/internal/middleware/region"
	"github.com/heycaby/backend/internal/repository"
	driversvc "github.com/heycaby/backend/internal/service/driver_service"
	emailservice "github.com/heycaby/backend/internal/service/email_service"
	matchingsvc "github.com/heycaby/backend/internal/service/matching_service"
	ridesvc "github.com/heycaby/backend/internal/service/ride_service"
)

func main() {
	// --- Environment ---
	supabaseURL := mustEnv("SUPABASE_URL")
	supabaseKey := mustEnv("SUPABASE_SERVICE_KEY")
	jwtSecret := mustEnv("SUPABASE_JWT_SECRET")
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	// Production must have reachable Redis (driver GEO, ride accept locks, fast status).
	// Local/dev without Redis: set REDIS_OPTIONAL=true (never use in ECS/production).
	redisOptional := strings.EqualFold(getEnv("REDIS_OPTIONAL", ""), "true")
	port := getEnv("PORT", "8080")

	// --- Infrastructure ---
	db := repository.NewSupabaseClient(supabaseURL, supabaseKey)

	var rdb *cache.RedisClient
	if r, err := cache.NewRedisClient(redisURL); err != nil {
		if redisOptional {
			log.Printf("WARN: Redis unavailable (%v) — continuing with REDIS_OPTIONAL=true (development only)", err)
		} else {
			log.Fatalf(
				"FATAL: Redis required — driver locations (GEO), ride locks, and matching depend on it. "+
					"Set REDIS_URL to your live instance (e.g. AWS ElastiCache rediss://... in the same VPC as ECS). "+
					"See backend/docs/REDIS.md. Error: %v",
				err,
			)
		}
	} else {
		rdb = r
		log.Println("Redis connected")
	}

	cfgService := config.NewCountryConfigService(db)
	if err := cfgService.Load(); err != nil {
		log.Fatalf("FATAL: failed to load country config: %v", err)
	}
	log.Println("Country config loaded successfully")

	// --- Repositories ---
	cityRepo := repository.NewCityRepository(db)
	driverRepo := repository.NewDriverRepository(db)
	rideRepo := repository.NewRideRepository(db)

	emailEnabled := strings.EqualFold(getEnv("EMAIL_SES_ENABLED", "false"), "true")
	emailMaxAttempts, err := strconv.Atoi(getEnv("EMAIL_SES_MAX_ATTEMPTS", "3"))
	if err != nil || emailMaxAttempts <= 0 {
		emailMaxAttempts = 3
	}
	emailSvc, err := emailservice.NewSESService(context.Background(), emailservice.Config{
		Enabled:          emailEnabled,
		Region:           getEnv("EMAIL_SES_REGION", ""),
		FromAddress:      getEnv("EMAIL_FROM_ADDRESS", ""),
		ReplyToAddress:   getEnv("EMAIL_REPLY_TO_ADDRESS", ""),
		ConfigurationSet: getEnv("EMAIL_SES_CONFIGURATION_SET", ""),
		MaxAttempts:      emailMaxAttempts,
	})
	if err != nil {
		log.Fatalf("FATAL: failed to initialize email service: %v", err)
	}

	// --- Services ---
	matchingService := matchingsvc.New(rdb, driverRepo, cfgService)
	skipGates := driverSkipGoOnlineGatesFromEnv()
	if skipGates {
		log.Println("WARN: E2E go-online test mode — document and billing gates bypassed")
	}
	driverService := driversvc.NewWithBilling(rdb, driverRepo, cfgService, emailSvc, driversvc.BillingConfig{
		Mollie: driversvc.MollieConfig{
			APIKey:      getEnv("MOLLIE_API_KEY", ""),
			RedirectURL: getEnv("MOLLIE_REDIRECT_URL", "https://api.heycaby.nl/driver/payment/return"),
		},
		Provider:          getEnv("DRIVER_BILLING_PROVIDER", ""),
		AppleSharedSecret: getEnv("APPLE_APPSTORE_SHARED_SECRET", ""),
		SkipGoOnlineGates: skipGates,
	})
	rideService := ridesvc.New(rideRepo, rdb)

	// --- Handlers ---
	// Guard against nil Redis causing a non-nil interface panic in the health check.
	var redisPinger handler.Pinger
	if rdb != nil {
		redisPinger = rdb
	}
	healthH := handler.NewHealthHandler(redisPinger, cfgService)
	configH := handler.NewConfigHandler(cfgService, driverService.SkipGoOnlineGates())
	driverH := handler.NewDriverHandler(driverService)
	rideH := handler.NewRideHandler(rideService)
	riderH := handler.NewRiderHandler(matchingService)

	// --- Fiber App ---
	app := fiber.New(fiber.Config{
		AppName:      "HeyCaby API v1",
		ErrorHandler: handler.ErrorHandler,
	})

	app.Use(recover.New())
	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Country-Code, X-City-Id",
	}))
	app.Use(fiberlogger.New(fiberlogger.Config{
		Format: "[${time}] ${status} ${latency} ${method} ${path} cc=${locals:country_code} uid=${locals:user_id} role=${locals:user_role}\n",
	}))

	// --- Public routes (no auth required) ---
	app.Get("/health", healthH.Health)
	app.Get("/health/ready", healthH.Readiness)

	// --- API v1 (all routes require a valid Supabase JWT) ---
	// v1 contract is frozen. New capability ships behind feature flags.
	v1 := app.Group("/api/v1",
		authmw.New(jwtSecret, supabaseURL),
		regionmw.NewWithCityResolver(cityRepo),
		flagsmw.New(cfgService),
	)

	// Boot config — called by Flutter app on startup to get tuneable behaviour
	v1.Get("/config", configH.GetConfig)

	// Driver endpoints — active from day 1, feature-flagged internally
	v1.Post("/driver/heartbeat", driverH.Heartbeat)
	v1.Get("/driver/readiness", driverH.Readiness)
	v1.Post("/driver/document/validate", driverH.ValidateDocument)
	v1.Post("/driver/status", driverH.SetStatus)
	v1.Post("/driver/ride/:rideId/accept", rideH.Accept)
	v1.Post("/driver/ride/manual", rideH.CreateManualRide)
	v1.Post("/driver/ride/:rideId/start", rideH.Start)
	v1.Post("/driver/ride/:rideId/complete", rideH.Complete)
	v1.Post("/driver/ride/:rideId/cancel", rideH.Cancel)

	// Rider endpoints — nearby supply (use_redis_locations flag controls data source)
	v1.Get("/rider/nearby-supply", riderH.NearbySupply)

	// Legacy driver billing endpoints still used by Flutter billing screens.
	legacy := app.Group("/api",
		authmw.New(jwtSecret, supabaseURL),
		regionmw.NewWithCityResolver(cityRepo),
		flagsmw.New(cfgService),
	)
	legacy.Get("/driver/status", driverH.BillingStatus)
	legacy.Post("/driver/payment/create", driverH.CreatePlatformPayment)
	legacy.Post("/driver/billing/apple/verify", driverH.AppleVerifyReceipt)
	legacy.Get("/driver/payments", driverH.BillingHistory)
	legacy.Post("/driver/subscription/pause", driverH.PauseSubscription)
	legacy.Post("/driver/subscription/resume", driverH.ResumeSubscription)
	legacy.Post("/driver/subscription/cancel", driverH.CancelSubscription)
	legacy.Get("/driver/payment/methods-portal", driverH.PaymentMethodsPortal)

	log.Printf("HeyCaby API starting on :%s", port)
	log.Fatal(app.Listen(":" + port))
}

// driverSkipGoOnlineGatesFromEnv enables E2E test mode (no document or billing block for going available).
// Set DRIVER_SKIP_GO_ONLINE_GATES=true or DRIVER_REQUIRE_DOCUMENTS_FOR_ONLINE=false (legacy alias).
func driverSkipGoOnlineGatesFromEnv() bool {
	explicit := strings.TrimSpace(strings.ToLower(os.Getenv("DRIVER_SKIP_GO_ONLINE_GATES")))
	if explicit == "true" || explicit == "1" || explicit == "yes" || explicit == "on" {
		return true
	}
	legacy := strings.TrimSpace(strings.ToLower(os.Getenv("DRIVER_REQUIRE_DOCUMENTS_FOR_ONLINE")))
	if legacy == "false" || legacy == "0" || legacy == "no" || legacy == "off" {
		return true
	}
	return false
}

func mustEnv(key string) string {
	v := os.Getenv(key)
	if v == "" {
		log.Fatalf("FATAL: required env var %s is not set", key)
	}
	return v
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
