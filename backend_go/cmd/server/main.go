package main

import (
	"context"
	"log"
	"time"

	"github.com/Roshan6422/security/backend_go/internal/handlers"
	"github.com/Roshan6422/security/backend_go/internal/middleware"
	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
	"net/http"
)

func main() {
	// Initialize config
	cfg := services.NewConfig()

	// Initialize services
	firebaseSvc := services.NewFirebaseService(cfg)
	auditSvc := services.NewAuditService(firebaseSvc.Firestore)

	// Initialize router
	r := gin.Default()

	// Middleware
	r.Use(gin.Logger())
	r.Use(gin.Recovery())

	// Custom CORS & Security Headers Middleware
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, PATCH, DELETE")
		
		// Security Pass 102: Production Headers
		c.Writer.Header().Set("X-Content-Type-Options", "nosniff")
		c.Writer.Header().Set("X-Frame-Options", "DENY")
		c.Writer.Header().Set("X-XSS-Protection", "1; mode=block")
		c.Writer.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Initialize handlers
	healthHandler := handlers.NewHealthHandler(firebaseSvc)
	authHandler := handlers.NewAuthHandler(firebaseSvc, auditSvc)
	vaultHandler := handlers.NewVaultHandler(firebaseSvc, auditSvc)
	adminHandler := handlers.NewAdminHandler(firebaseSvc, auditSvc)
	paymentHandler := handlers.NewPaymentHandler(firebaseSvc, auditSvc)
	
	// Public Routes
	r.GET("/health", healthHandler.Check)

	// Auth Public Endpoints (Rate Limited - Pass 101)
	authPublic := r.Group("/api/auth")
	authPublic.Use(middleware.AuthRateLimiter())
	{
		authPublic.POST("/forgot-password", authHandler.ForgotPassword)
		authPublic.POST("/verify-otp", authHandler.VerifyOTP)
		authPublic.POST("/reset-password", authHandler.ResetPassword)
		authPublic.POST("/login", authHandler.Login)
		authPublic.POST("/register", authHandler.Register)
		authPublic.POST("/make-admin", authHandler.MakeAdmin)
	}

	// Auth Protected Routes
	api := r.Group("/api")
	api.Use(middleware.AuthMiddleware(firebaseSvc))
	{
		// Auth Sync & Compatible Endpoints
		api.POST("/auth/sync", authHandler.FirebaseSync)
		api.POST("/auth/firebase-login", authHandler.FirebaseSync)
		api.POST("/auth/firebase-register", authHandler.FirebaseSync)
		api.POST("/auth/set-key-flag", authHandler.SetKeyFlag)

		// Vault
		api.GET("/vault", vaultHandler.ListVaultItems)
		api.GET("/vault/stats", vaultHandler.GetStats)
		api.GET("/vault/dashboard", vaultHandler.GetDashboard)
		api.GET("/vault/recent", vaultHandler.GetRecent)
		api.POST("/vault/upload", vaultHandler.Upload)
		api.POST("/vault", vaultHandler.UploadMetadata)
		api.POST("/vault/metadata", vaultHandler.UploadMetadata)
		api.PUT("/vault/:id", vaultHandler.UpdateMetadata)
		api.POST("/vault/delete-batch", vaultHandler.DeleteBatch)
		api.DELETE("/vault/:id", vaultHandler.DeleteVaultItem)
		api.POST("/vault/restore/:id", vaultHandler.RestoreVaultItem)
		api.POST("/vault/:id/restore", vaultHandler.RestoreVaultItem)
		api.DELETE("/vault/empty-bin", vaultHandler.EmptyRecycleBin)

		// Payment
		api.POST("/payment/google-play/verify", paymentHandler.VerifyGooglePlaySubscription)

		// Admin Routes
		admin := api.Group("/admin")
		admin.Use(middleware.AdminMiddleware(firebaseSvc))
		{
			admin.GET("/stats", adminHandler.GetAdminStats)
			admin.GET("/users", adminHandler.GetAllUsers)
			admin.PATCH("/users/:id/status", adminHandler.UpdateUserStatus)
			admin.PATCH("/users/:id/subscription", adminHandler.UpdateUserSubscription)
			admin.PATCH("/users/:id/role", adminHandler.UpdateUserRole)
			admin.DELETE("/users/:id", adminHandler.DeleteUser)
		}
	}

	// Get port from config
	port := cfg.Port

	// Background task for recycle bin cleanup (every 24 hours)
	go func() {
		log.Printf("Background cleanup task started")
		for {
			count, err := vaultHandler.CleanupOldDeletedItems(context.Background())
			if err != nil {
				log.Printf("Background Cleanup Error: %v", err)
			} else if count > 0 {
				log.Printf("Background Cleanup: Purged %d old recycle bin items", count)
			}
			time.Sleep(24 * time.Hour)
		}
	}()

	log.Printf("SafeShell Go Backend Starting - Version: 1.0.1 (Auth Fix Integrated)")
	log.Printf("Server starting on port %s", port)
	
	// Security Pass 103: Standard Server with Timeouts
	srv := &http.Server{
		Addr:         ":" + port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatalf("failed to run server: %v", err)
	}
}
