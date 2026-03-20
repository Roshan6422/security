package middleware

import (
	"net/http"
	"strings"

	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
)

func AuthMiddleware(firebaseSvc *services.FirebaseService) gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header is required"})
			c.Abort()
			return
		}

		parts := strings.Split(authHeader, " ")
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Authorization header must be Bearer token"})
			c.Abort()
			return
		}

		idToken := parts[1]
		ctx := c.Request.Context()
		token, err := firebaseSvc.Auth.VerifyIDToken(ctx, idToken)
		if err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid or expired token"})
			c.Abort()
			return
		}

		// Security Pass 1: Check if user is suspended in Firestore
		userDoc, err := firebaseSvc.Firestore.Collection("users").Doc(token.UID).Get(ctx)
		if err == nil && userDoc.Exists() {
			if suspended, ok := userDoc.Data()["isSuspended"].(bool); ok && suspended {
				c.JSON(http.StatusForbidden, gin.H{"error": "Your account has been suspended. Please contact support."})
				c.Abort()
				return
			}
		}

		// Set user ID and other claims in context
		c.Set("userId", token.UID)
		c.Set("idToken", idToken)
		c.Set("claims", token.Claims)

		c.Next()
	}
}
