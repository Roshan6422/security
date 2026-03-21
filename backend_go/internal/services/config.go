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
	BaseURL                string
	SupabaseURL            string
	SupabaseKey            string
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
		FirebaseAPIKey:         getEnvOrDefault("FIREBASE_API_KEY", "AIzaSyAl-vsd8l_4gYffEpo5XDNZE2oR8doLoH8"),
		StorageBucket:          getEnvOrDefault("FIREBASE_STORAGE_BUCKET", "sceruty-e5351.firebasestorage.app"),
		AdminSecret:            getEnvOrDefault("ADMIN_SECRET", "admin-secret-123"),
		BaseURL:                getEnvOrDefault("SERVER_URL", "https://fair-madelin-safeshellmobile-5ea64b9b.koyeb.app"),
		SupabaseURL:            getEnvOrDefault("SUPABASE_URL", "https://yvfzkemhwtywzbsiqdbs.supabase.co"),
		SupabaseKey:            getEnvOrDefault("SUPABASE_KEY", "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdWJhYmFzZSIsInJlZiI6Inl2ZnpreW1od3R5d3picyIsInJvbGUiOiJhbm9uIiwiaWF0IjoxNzc0MDkyNjAyLCJleHAiOjIwODk2Njg2MDJ9.V6e04rL-n_vsd8l_4gYffEpo5XDNZE2oR8doLoH8"),
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
