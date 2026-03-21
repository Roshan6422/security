package services

import (
	"context"
	"log"

	"cloud.google.com/go/firestore"
	"firebase.google.com/go/v4"
	"firebase.google.com/go/v4/auth"
	"firebase.google.com/go/v4/storage"
	"google.golang.org/api/option"
	"encoding/base64"
	"strings"
)

type FirebaseService struct {
	App       *firebase.App
	Auth      *auth.Client
	Firestore *firestore.Client
	Storage   *storage.Client
	Config    *Config
}

func NewFirebaseService(cfg *Config) *FirebaseService {
	ctx := context.Background()

	// Load credentials
	log.Printf("Initializing Firebase...")
	var opt option.ClientOption
	if cfg.FirebaseServiceAccount != "" {
		// Attempt to decode as base64 first.
		// Koyeb UI may inject newlines or spaces into the env var value, so we strip ALL whitespace.
		cleanB64 := strings.ReplaceAll(strings.TrimSpace(cfg.FirebaseServiceAccount), "\n", "")
		cleanB64 = strings.ReplaceAll(cleanB64, "\r", "")
		cleanB64 = strings.ReplaceAll(cleanB64, " ", "")
		decoded, err := base64.StdEncoding.DecodeString(cleanB64)
		if err == nil {
			// If successful, use the decoded JSON
			opt = option.WithCredentialsJSON(decoded)
		} else {
			log.Printf("Using credentials from environment variable (FirebaseServiceAccount)")
			opt = option.WithCredentialsJSON([]byte(cfg.FirebaseServiceAccount))
		}
	} else {
		log.Printf("WARNING: No FIREBASE_SERVICE_ACCOUNT environment variable found, attempting to use firebase-credentials.json file")
		opt = option.WithCredentialsFile("firebase-credentials.json")
	}

	app, err := firebase.NewApp(ctx, nil, opt)
	if err != nil {
		log.Fatalf("error initializing firebase app: %v", err)
	}

	authClient, err := app.Auth(ctx)
	if err != nil {
		log.Fatalf("error getting Auth client: %v", err)
	}

	firestoreClient, err := app.Firestore(ctx)
	if err != nil {
		log.Fatalf("error getting Firestore client: %v", err)
	}

	storageClient, err := app.Storage(ctx)
	if err != nil {
		log.Fatalf("error getting Storage client: %v", err)
	}

	return &FirebaseService{
		App:       app,
		Auth:      authClient,
		Firestore: firestoreClient,
		Storage:   storageClient,
		Config:    cfg,
	}
}
