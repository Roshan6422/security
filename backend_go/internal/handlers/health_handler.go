package handlers

import (
	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
	"net/http"
)

type HealthHandler struct {
	FirebaseSvc *services.FirebaseService
}

func NewHealthHandler(firebaseSvc *services.FirebaseService) *HealthHandler {
	return &HealthHandler{FirebaseSvc: firebaseSvc}
}

func (h *HealthHandler) Check(c *gin.Context) {
	// Security Pass 104: Deep Dependency Check
	ctx := c.Request.Context()
	dbStatus := "connected"
	
	// Quick probe to Firestore
	_, err := h.FirebaseSvc.Firestore.Collection("vault").Limit(1).Documents(ctx).GetAll()
	if err != nil {
		dbStatus = "disconnected"
	}

	c.JSON(http.StatusOK, gin.H{
		"status":  "ok",
		"database": dbStatus,
		"message": "SafeShell Go Backend is running",
		"version": "1.0.0-legendary-2000",
	})
}
