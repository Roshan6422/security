package handlers

import (
	"net/http"
	"time"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/firestore/apiv1/firestorepb"
	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
	"google.golang.org/api/iterator"
)

type AdminHandler struct {
	FirebaseSvc *services.FirebaseService
	AuditSvc    *services.AuditService
}

func NewAdminHandler(firebaseSvc *services.FirebaseService, auditSvc *services.AuditService) *AdminHandler {
	return &AdminHandler{FirebaseSvc: firebaseSvc, AuditSvc: auditSvc}
}

func (h *AdminHandler) GetAdminStats(c *gin.Context) {
	ctx := c.Request.Context()

	// 1. Total Users using Aggregation Query
	userCount := 0
	usersAggRes, err := h.FirebaseSvc.Firestore.Collection("users").NewAggregationQuery().WithCount("all").Get(ctx)
	if err == nil {
		if val, ok := usersAggRes["all"]; ok {
			if pbVal, ok := val.(*firestorepb.Value); ok {
				userCount = int(pbVal.GetIntegerValue())
			}
		}
	}

	// 2. Total Files using Aggregation Query
	fileCount := 0
	filesAggRes, err := h.FirebaseSvc.Firestore.Collection("vault").NewAggregationQuery().WithCount("all").Get(ctx)
	if err == nil {
		if val, ok := filesAggRes["all"]; ok {
			if pbVal, ok := val.(*firestorepb.Value); ok {
				fileCount = int(pbVal.GetIntegerValue())
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"totalUsers": userCount,
		"totalFiles": fileCount,
		"timestamp":  time.Now(),
	})
}

func (h *AdminHandler) GetAllUsers(c *gin.Context) {
	ctx := c.Request.Context()
	iter := h.FirebaseSvc.Firestore.Collection("users").Documents(ctx)

	var users []map[string]interface{}
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch users"})
			return
		}
		data := doc.Data()
		// Security Pass 204: Strip sensitive keys from admin view
		delete(data, "recoveryKey")
		delete(data, "userKey")
		users = append(users, data)
	}

	c.JSON(http.StatusOK, users)
}

func (h *AdminHandler) UpdateUserStatus(c *gin.Context) {
	userId := c.Param("id")
	var req struct {
		IsSuspended bool `json:"isSuspended"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()
	_, err := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Update(ctx, []firestore.Update{
		{Path: "isSuspended", Value: req.IsSuspended},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user status"})
		return
	}

	adminId, _ := c.Get("userId")
	h.AuditSvc.LogEvent(ctx, adminId.(string), "admin_user_status", "Updated status for user: "+userId, map[string]interface{}{"isSuspended": req.IsSuspended})
	
	c.JSON(http.StatusOK, gin.H{"message": "User status updated"})
}

func (h *AdminHandler) UpdateUserSubscription(c *gin.Context) {
	userId := c.Param("id")
	var req struct {
		Status string `json:"status"` // "free" or "pro"
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()
	// Get current user to check for existing expiry
	doc, err := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Get(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	userData := doc.Data()
	currentExpiry, _ := userData["subscriptionExpiry"].(time.Time)

	updates := []firestore.Update{
		{Path: "subscriptionStatus", Value: req.Status},
		{Path: "updatedAt", Value: time.Now()},
	}

	if req.Status == "pro" {
		newExpiry := time.Now().AddDate(0, 1, 0)
		if !currentExpiry.IsZero() && currentExpiry.After(time.Now()) {
			newExpiry = currentExpiry.AddDate(0, 1, 0)
		}
		updates = append(updates, firestore.Update{Path: "subscriptionExpiry", Value: newExpiry})
	} else if req.Status == "free" {
		updates = append(updates, firestore.Update{Path: "subscriptionExpiry", Value: nil})
	}

	_, err = h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Update(ctx, updates)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update subscription"})
		return
	}

	adminId, _ := c.Get("userId")
	h.AuditSvc.LogEvent(ctx, adminId.(string), "admin_user_subscription", "Updated subscription for user: "+userId, map[string]interface{}{"status": req.Status})

	c.JSON(http.StatusOK, gin.H{"message": "User subscription updated"})
}

func (h *AdminHandler) UpdateUserRole(c *gin.Context) {
	userId := c.Param("id")
	var req struct {
		Role string `json:"role"` // "admin" or "user"
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Role != "admin" && req.Role != "user" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "role must be 'admin' or 'user'"})
		return
	}

	ctx := c.Request.Context()
	_, err := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Update(ctx, []firestore.Update{
		{Path: "role", Value: req.Role},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update user role"})
		return
	}

	adminId, _ := c.Get("userId")
	h.AuditSvc.LogEvent(ctx, adminId.(string), "admin_user_role", "Updated role for user: "+userId, map[string]interface{}{"role": req.Role})

	// Return updated user data
	doc, _ := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Get(ctx)
	var updatedUser map[string]interface{}
	if doc != nil {
		updatedUser = doc.Data()
		delete(updatedUser, "recoveryKey")
		delete(updatedUser, "userKey")
	}
	c.JSON(http.StatusOK, gin.H{"message": "User role updated", "user": updatedUser})
}

func (h *AdminHandler) DeleteUser(c *gin.Context) {
	userId := c.Param("id")
	ctx := c.Request.Context()

	// Delete from Firestore
	_, err := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Delete(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete user from database"})
		return
	}

	// Delete from Firebase Auth
	if authErr := h.FirebaseSvc.Auth.DeleteUser(ctx, userId); authErr != nil {
		// Log but don't fail — user doc is already gone
		c.JSON(http.StatusOK, gin.H{"message": "User data deleted (auth removal failed - may not exist)"})
		return
	}

	adminId, _ := c.Get("userId")
	h.AuditSvc.LogEvent(ctx, adminId.(string), "admin_user_delete", "Permanently deleted user: "+userId, nil)

	c.JSON(http.StatusOK, gin.H{"message": "User permanently deleted"})
}
