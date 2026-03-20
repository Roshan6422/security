# Build stage
FROM golang:1.23.1-alpine AS builder

WORKDIR /app

# Copy go mod and sum files
COPY backend_go/go.mod backend_go/go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY backend_go/ .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -o main ./cmd/server/main.go

# Run stage
FROM alpine:latest

# Copy binary from builder
WORKDIR /app
COPY --from=builder /app/main .

# Expose port (Cloud Run/Koyeb will override this with PORT env var)
EXPOSE 8000

# Command to run
CMD ["./main"]
