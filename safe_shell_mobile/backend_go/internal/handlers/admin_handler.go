package handlers

import (
	"net/http"
	"sort"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
	"google.golang.org/api/iterator"
	firestorepb "google.golang.org/genproto/googleapis/firestore/v1"
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

	// 1. Total Users
	userCount := 0
	usersAggRes, err := h.FirebaseSvc.Firestore.Collection("users").NewAggregationQuery().WithCount("all").Get(ctx)
	if err == nil {
		if val, ok := usersAggRes["all"]; ok {
			if pbVal, ok := val.(*firestorepb.Value); ok {
				userCount = int(pbVal.GetIntegerValue())
			}
		}
	}

	// 2. Active Tickets (Status: open)
	activeTickets := 0
	ticketsAggRes, err := h.FirebaseSvc.Firestore.Collection("support_tickets").Where("status", "==", "open").NewAggregationQuery().WithCount("all").Get(ctx)
	if err == nil {
		if val, ok := ticketsAggRes["all"]; ok {
			if pbVal, ok := val.(*firestorepb.Value); ok {
				activeTickets = int(pbVal.GetIntegerValue())
			}
		}
	}

	// 3. Total Revenue & Payments List
	totalRevenue := float64(0)
	var payments []map[string]interface{}
	pIter := h.FirebaseSvc.Firestore.Collection("payments").OrderBy("date", firestore.Desc).Documents(ctx)
	for {
		doc, err := pIter.Next()
		if err == iterator.Done { break }
		if err != nil { break }
		data := doc.Data()
		if amt, ok := data["amount"].(float64); ok {
			totalRevenue += amt
		} else if amt, ok := data["amount"].(int64); ok {
			totalRevenue += float64(amt)
		}
		payments = append(payments, data)
	}

	// 4. Recent Activity (Mix of new users and payments)
	var recentActivity []map[string]interface{}
	
	// Get latest 5 users
	uIter := h.FirebaseSvc.Firestore.Collection("users").OrderBy("createdAt", firestore.Desc).Limit(5).Documents(ctx)
	for {
		doc, err := uIter.Next()
		if err == iterator.Done { break }
		if err != nil { break }
		data := doc.Data()
		recentActivity = append(recentActivity, map[string]interface{}{
			"type":  "user",
			"title": "New User: " + fmt.Sprintf("%v", data["name"]),
			"date":  data["createdAt"],
		})
	}

	// Fill with payments if needed, then sort
	for i := 0; i < len(payments) && i < 5; i++ {
		recentActivity = append(recentActivity, map[string]interface{}{
			"type":  "payment",
			"title": "Payment: " + fmt.Sprintf("%v", payments[i]["email"]),
			"date":  payments[i]["date"],
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"totalUsers":     userCount,
		"totalRevenue":   totalRevenue,
		"activeTickets":  activeTickets,
		"recentActivity": recentActivity,
		"payments":       payments,
		"timestamp":      time.Now(),
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
		data["_id"] = doc.Ref.ID
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
	
	// Return updated user data
	updatedDoc, _ := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Get(ctx)
	var updatedUser map[string]interface{}
	if updatedDoc != nil {
		updatedUser = updatedDoc.Data()
		updatedUser["_id"] = userId
		delete(updatedUser, "recoveryKey")
		delete(updatedUser, "userKey")
	}

	c.JSON(http.StatusOK, gin.H{"message": "User status updated", "user": updatedUser})
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
	var currentExpiry time.Time
	if expiryVal, ok := userData["subscriptionExpiry"].(time.Time); ok {
		currentExpiry = expiryVal
	}

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

	// Return updated user data
	updatedDoc, _ := h.FirebaseSvc.Firestore.Collection("users").Doc(userId).Get(ctx)
	var updatedUser map[string]interface{}
	if updatedDoc != nil {
		updatedUser = updatedDoc.Data()
		updatedUser["_id"] = userId
		delete(updatedUser, "recoveryKey")
		delete(updatedUser, "userKey")
	}

	c.JSON(http.StatusOK, gin.H{"message": "User subscription updated", "user": updatedUser})
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
		updatedUser["_id"] = userId
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

func (h *AdminHandler) GetTickets(c *gin.Context) {
	ctx := c.Request.Context()
	iter := h.FirebaseSvc.Firestore.Collection("support_tickets").Documents(ctx)

	var tickets []map[string]interface{}
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch tickets"})
			return
		}
		data := doc.Data()
		data["id"] = doc.Ref.ID
		tickets = append(tickets, data)
	}

	// Sort in memory by createdAt DESC
	sort.Slice(tickets, func(i, j int) bool {
		t1, _ := tickets[i]["createdAt"].(time.Time)
		t2, _ := tickets[j]["createdAt"].(time.Time)
		return t1.After(t2)
	})

	if tickets == nil {
		tickets = []map[string]interface{}{}
	}
	c.JSON(http.StatusOK, tickets)
}

func (h *AdminHandler) ReplyToTicket(c *gin.Context) {
	ticketId := c.Param("id")
	var req struct {
		Message string `json:"message"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	ctx := c.Request.Context()
	reply := map[string]interface{}{
		"sender": "admin",
		"message": req.Message,
		"date": time.Now().Format(time.RFC3339),
	}

	_, err := h.FirebaseSvc.Firestore.Collection("support_tickets").Doc(ticketId).Update(ctx, []firestore.Update{
		{Path: "replies", Value: firestore.ArrayUnion(reply)},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to add reply"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Reply added successfully"})
}

func (h *AdminHandler) UpdateTicketStatus(c *gin.Context) {
	ticketId := c.Param("id")
	var req struct {
		Status string `json:"status"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	ctx := c.Request.Context()
	_, err := h.FirebaseSvc.Firestore.Collection("support_tickets").Doc(ticketId).Update(ctx, []firestore.Update{
		{Path: "status", Value: req.Status},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update status"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Status updated successfully"})
}

func (h *AdminHandler) GetPayments(c *gin.Context) {
	ctx := c.Request.Context()
	iter := h.FirebaseSvc.Firestore.Collection("payments").Documents(ctx)

	var payments []map[string]interface{}
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch payments"})
			return
		}
		data := doc.Data()
		data["id"] = doc.Ref.ID
		payments = append(payments, data)
	}

	// Sort in memory by date DESC
	sort.Slice(payments, func(i, j int) bool {
		t1, _ := payments[i]["date"].(time.Time)
		t2, _ := payments[j]["date"].(time.Time)
		return t1.After(t2)
	})

	if payments == nil {
		payments = []map[string]interface{}{}
	}
	c.JSON(http.StatusOK, payments)
}

func (h *AdminHandler) GetBankSettings(c *gin.Context) {
	ctx := c.Request.Context()
	doc, err := h.FirebaseSvc.Firestore.Collection("settings").Doc("bank_account").Get(ctx)
	if err != nil {
		c.JSON(http.StatusOK, map[string]string{
			"bankName": "", "accountHolder": "", "accountNumber": "", "branch": "", "swiftCode": "",
		})
		return
	}
	c.JSON(http.StatusOK, doc.Data())
}

func (h *AdminHandler) UpdateBankSettings(c *gin.Context) {
	var req map[string]interface{}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}
	req["updatedAt"] = time.Now()

	ctx := c.Request.Context()
	_, err := h.FirebaseSvc.Firestore.Collection("settings").Doc("bank_account").Set(ctx, req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save bank settings"})
		return
	}
	c.JSON(http.StatusOK, req)
}
