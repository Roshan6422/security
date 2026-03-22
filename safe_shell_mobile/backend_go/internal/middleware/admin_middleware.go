package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/Roshan6422/security/backend_go/internal/services"
)

func AdminMiddleware(firebaseSvc *services.FirebaseService) gin.HandlerFunc {
	return func(c *gin.Context) {
		userIdVal, exists := c.Get("userId")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
			c.Abort()
			return
		}
		userId := userIdVal.(string)

		ctx := c.Request.Context()
		userRef := firebaseSvc.Firestore.Collection("users").Doc(userId)
		doc, err := userRef.Get(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user role"})
			c.Abort()
			return
		}

		role, _ := doc.Data()["role"].(string)
		if role != "admin" {
			c.JSON(http.StatusForbidden, gin.H{"error": "Admin access required"})
			c.Abort()
			return
		}

		c.Next()
	}
}
