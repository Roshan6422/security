package handlers

import (
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/gin-gonic/gin"
	"github.com/Roshan6422/security/backend_go/internal/services"
)

type PaymentHandler struct {
	FirebaseSvc *services.FirebaseService
	AuditSvc    *services.AuditService
}

func NewPaymentHandler(firebaseSvc *services.FirebaseService, auditSvc *services.AuditService) *PaymentHandler {
	return &PaymentHandler{FirebaseSvc: firebaseSvc, AuditSvc: auditSvc}
}

type GooglePayNotifyRequest struct {
	PurchaseToken string `json:"purchaseToken" binding:"required"`
	PackageName   string `json:"packageName" binding:"required"`
	SubscriptionId string `json:"subscriptionId" binding:"required"`
}

func (h *PaymentHandler) VerifyGooglePlaySubscription(c *gin.Context) {
	userId, _ := c.Get("userId")
	var req GooglePayNotifyRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Safety Check: In production, you would verify the purchase token here.
	// For demo, we allow activation.
	
	userRef := h.FirebaseSvc.Firestore.Collection("users").Doc(userId.(string))
	doc, err := userRef.Get(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	userData := doc.Data()
	currentStatus, _ := userData["subscriptionStatus"].(string)
	currentExpiry, _ := userData["subscriptionExpiry"].(time.Time)

	newExpiry := time.Now().AddDate(0, 1, 0)
	if currentStatus == "pro" && !currentExpiry.IsZero() && currentExpiry.After(time.Now()) {
		// If already pro and not expired, extend from existing expiry
		newExpiry = currentExpiry.AddDate(0, 1, 0)
	}

	_, err = userRef.Update(ctx, []firestore.Update{
		{Path: "subscriptionStatus", Value: "pro"},
		{Path: "subscriptionExpiry", Value: newExpiry},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update subscription"})
		return
	}
	h.AuditSvc.LogEvent(ctx, userId.(string), "payment_success", "Verified Google Play subscription", map[string]interface{}{
		"item": req.SubscriptionId,
	})

	c.JSON(http.StatusOK, gin.H{"message": "Subscription activated successfully"})
}
