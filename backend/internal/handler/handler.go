package handler

import (
	"log"

	"github.com/gofiber/fiber/v2"
)

// ErrorHandler is the global Fiber error handler. Returns structured JSON errors.
func ErrorHandler(c *fiber.Ctx, err error) error {
	code := fiber.StatusInternalServerError
	message := "internal server error"

	if e, ok := err.(*fiber.Error); ok {
		code = e.Code
		message = e.Message
	}

	if code >= 500 {
		log.Printf("ERROR %s %s: %v", c.Method(), c.Path(), err)
	}

	return c.Status(code).JSON(fiber.Map{
		"error": message,
	})
}

// ok sends a 200 JSON response.
func ok(c *fiber.Ctx, data any) error {
	return c.Status(fiber.StatusOK).JSON(data)
}
