package services

import (
	"os"
)

type Config struct {
	Port                   string
	FirebaseServiceAccount string
	StorageMode            string // "local" or "firebase"
}

func NewConfig() *Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	return &Config{
		Port:                   port,
		FirebaseServiceAccount: getFirebaseAccount(),
		StorageMode:            os.Getenv("STORAGE_MODE"),
	}
}

func getFirebaseAccount() string {
	b64 := os.Getenv("FIREBASE_SERVICE_ACCOUNT_BASE64")
	if b64 != "" {
		return b64
	}
	return os.Getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
}
