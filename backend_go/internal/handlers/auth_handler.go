package handlers

import (
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"firebase.google.com/go/v4/auth"
	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
	"os"
)

type AuthHandler struct {
	FirebaseSvc *services.FirebaseService
	AuditSvc    *services.AuditService
}

func NewAuthHandler(firebaseSvc *services.FirebaseService, auditSvc *services.AuditService) *AuthHandler {
	return &AuthHandler{FirebaseSvc: firebaseSvc, AuditSvc: auditSvc}
}

type SyncRequest struct {
	IDToken string `json:"idToken"`
	Name    string `json:"name"`
	Email   string `json:"email"`
}

func (h *AuthHandler) FirebaseSync(c *gin.Context) {
	h.handleSync(c)
}

func (h *AuthHandler) FirebaseLogin(c *gin.Context) {
	h.handleSync(c)
}

func (h *AuthHandler) FirebaseRegister(c *gin.Context) {
	h.handleSync(c)
}

func (h *AuthHandler) handleSync(c *gin.Context) {
	userIdVal, exists := c.Get("userId")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userId := userIdVal.(string)

	tokenVal, _ := c.Get("idToken")
	idToken := tokenVal.(string)

	claimsVal, _ := c.Get("claims")
	claims := claimsVal.(map[string]interface{})

	// Parse request body for registration details if necessary
	var req SyncRequest
	if err := c.ShouldBindJSON(&req); err != nil && err.Error() != "EOF" {
		// Ignore EOF (empty body) but log others
	}

	ctx := c.Request.Context()
	userRef := h.FirebaseSvc.Firestore.Collection("users").Doc(userId)

	doc, err := userRef.Get(ctx)
	var userData map[string]interface{}

	if err != nil {
		// Create new user (Registration Flow)
		email, _ := claims["email"].(string)
		if email == "" { email = req.Email }
		
		name, _ := claims["name"].(string)
		if name == "" { name = req.Name }
		if name == "" { name = "User" }

		photoUrl, _ := claims["picture"].(string)

		// Generate random 16-char recovery key
		recoveryKey := services.GenerateRandomString(16)

		userData = map[string]interface{}{
			"_id":                userId,
			"id":                 userId,
			"email":              email,
			"name":               name,
			"photoUrl":           photoUrl,
			"role":               "user",
			"subscriptionStatus": "free",
			"subscriptionExpiry": nil,
			"isSuspended":        false,
			"recoveryKey":        recoveryKey,
			"userKey":            nil, // Will be set later by mobile app
			"createdAt":          time.Now(),
			"updatedAt":          time.Now(),
		}

		_, err = userRef.Create(ctx, userData)
		if err != nil {
			// If user already exists due to a race condition, try to fetch it again
			doc, err = userRef.Get(ctx)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create or retrieve user profile"})
				return
			}
			userData = doc.Data()
		}
	} else {
		// Existing user (Login Sync Flow)
		userData = doc.Data()
		userData["_id"] = userId
		userData["updatedAt"] = time.Now()
		
		// Ensure token claim fields are present if missing
		if userData["name"] == "" || userData["name"] == nil {
			if claims["name"] != nil { userData["name"] = claims["name"] }
		}
		if userData["photoUrl"] == "" || userData["photoUrl"] == nil {
			if claims["picture"] != nil { userData["photoUrl"] = claims["picture"] }
		}

		_, _ = userRef.Update(ctx, []firestore.Update{
			{Path: "updatedAt", Value: time.Now()},
		})
	}

	// Add token for mobile app compatibility
	userData["token"] = idToken

	c.JSON(http.StatusOK, userData)
}

func (h *AuthHandler) SetKeyFlag(c *gin.Context) {
	userId, _ := c.Get("userId")
	ctx := c.Request.Context()

	_, err := h.FirebaseSvc.Firestore.Collection("users").Doc(userId.(string)).Update(ctx, []firestore.Update{
		{Path: "userKey", Value: "secured_managed"},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to set key flag"})
		return
	}

	h.AuditSvc.LogEvent(ctx, userId.(string), "auth_key_setup", "Setup device encryption key", nil)

	c.JSON(http.StatusOK, gin.H{"message": "Key flag set successfully"})
}
func (h *AuthHandler) ForgotPassword(c *gin.Context) {
	var req struct {
		Email string `json:"email"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email is required"})
		return
	}

	// Generate 6-digit OTP
	otp := services.GenerateRandomDigits(6)

	ctx := c.Request.Context()
	_, err := h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Set(ctx, map[string]interface{}{
		"email":          req.Email,
		"otp":            otp,
		"expiresAt":      time.Now().Add(15 * time.Minute),
		"failedAttempts": 0,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate reset code"})
		return
	}

	// Security Pass 851: Hide OTP in production
	resp := gin.H{"message": "Reset code sent to your email"}
	if os.Getenv("GIN_MODE") != "release" {
		resp["otp"] = otp
	}
	c.JSON(http.StatusOK, resp)
}

func (h *AuthHandler) VerifyOTP(c *gin.Context) {
	var req struct {
		Email string `json:"email"`
		OTP   string `json:"otp"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Email and OTP are required"})
		return
	}

	ctx := c.Request.Context()
	doc, err := h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Get(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Reset code not found or expired"})
		return
	}

	data := doc.Data()
	storedOTP, _ := data["otp"].(string)
	expiresAt, _ := data["expiresAt"].(time.Time)
	failedAttempts, _ := data["failedAttempts"].(int64)

	if time.Now().After(expiresAt) {
		_, _ = h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Delete(ctx)
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Reset code has expired"})
		return
	}

	if storedOTP != req.OTP {
		failedAttempts++
		if failedAttempts >= 5 {
			_, _ = h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Delete(ctx)
			c.JSON(http.StatusLocked, gin.H{"error": "Too many failed attempts. Please request a new code."})
			return
		}
		
		_, _ = h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Update(ctx, []firestore.Update{
			{Path: "failedAttempts", Value: failedAttempts},
		})
		
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid reset code", "remainingAttempts": 5 - failedAttempts})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Code verified successfully"})
}

func (h *AuthHandler) ResetPassword(c *gin.Context) {
	var req struct {
		Email    string `json:"email"`
		OTP      string `json:"otp"`
		Password string `json:"password"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "All fields are required"})
		return
	}

	ctx := c.Request.Context()
	doc, err := h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Get(ctx)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Session expired, please request a new code"})
		return
	}

	data := doc.Data()
	storedOTP, _ := data["otp"].(string)
	if storedOTP != req.OTP {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid code"})
		return
	}

	// Update password in Firebase Auth
	user, err := h.FirebaseSvc.Auth.GetUserByEmail(ctx, req.Email)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	params := (&auth.UserToUpdate{}).Password(req.Password)
	_, err = h.FirebaseSvc.Auth.UpdateUser(ctx, user.UID, params)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update password"})
		return
	}

	// Clean up the token
	_, _ = h.FirebaseSvc.Firestore.Collection("reset_tokens").Doc(req.Email).Delete(ctx)

	h.AuditSvc.LogEvent(ctx, user.UID, "auth_password_reset", "Password reset successful via OTP", map[string]interface{}{"email": req.Email})

	c.JSON(http.StatusOK, gin.H{"message": "Password reset successfully"})
}
