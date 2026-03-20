package services

import (
	"log"
	"os"
)

type Config struct {
	Port                   string
	FirebaseServiceAccount string
	StorageMode            string // "local" or "firebase"
	FirebaseAPIKey         string
	StorageBucket          string
	AdminSecret            string
}

func NewConfig() *Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
		log.Printf("No PORT environment variable found, defaulting to 8000")
	} else {
		log.Printf("Detected PORT from environment: %s", port)
	}

	return &Config{
		Port:                   port,
		FirebaseServiceAccount: getFirebaseAccount(),
		StorageMode:            os.Getenv("STORAGE_MODE"),
		FirebaseAPIKey:         getEnvOrDefault("FIREBASE_API_KEY", "AIzaSyDbC1yBxLYJHa1SqlkrY1xK6lo-M7VhsoQ"),
		StorageBucket:          getEnvOrDefault("FIREBASE_STORAGE_BUCKET", "safeshell-app.firebasestorage.app"),
		AdminSecret:            getEnvOrDefault("ADMIN_SECRET", "admin-secret-123"),
	}
}

func getEnvOrDefault(key, defaultValue string) string {
	val := os.Getenv(key)
	if val == "" {
		return defaultValue
	}
	return val
}

func getFirebaseAccount() string {
	b64 := os.Getenv("FIREBASE_SERVICE_ACCOUNT_BASE64")
	if b64 != "" {
		return b64
	}
	return os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
}
