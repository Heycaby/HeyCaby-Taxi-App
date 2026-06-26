.PHONY: run build tidy lint test

run:
	go run ./cmd/main.go

build:
	go build -o heycaby-backend ./cmd/main.go

tidy:
	go mod tidy

lint:
	golangci-lint run ./...

test:
	go test ./... -v

dev:
	air -c .air.toml
