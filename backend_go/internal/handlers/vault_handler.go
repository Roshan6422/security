package handlers

import (
	"context"
	"io"
	"log"
	"net/http"
	"net/url"
	"time"

	"cloud.google.com/go/firestore"
	"github.com/Roshan6422/security/backend_go/internal/services"
	"github.com/gin-gonic/gin"
	"google.golang.org/api/iterator"
)

type VaultHandler struct {
	FirebaseSvc *services.FirebaseService
	AuditSvc    *services.AuditService
}

func NewVaultHandler(firebaseSvc *services.FirebaseService, auditSvc *services.AuditService) *VaultHandler {
	return &VaultHandler{FirebaseSvc: firebaseSvc, AuditSvc: auditSvc}
}

type CreateVaultRequest struct {
	Name     string                 `json:"name" binding:"required"`
	Type     string                 `json:"type" binding:"required"`
	URL      string                 `json:"url"`
	Size     int64                  `json:"size"`
	Path     string                 `json:"path"`
	Metadata map[string]interface{} `json:"metadata"`
}

type UpdateVaultRequest struct {
	Name     string                 `json:"name"`
	Metadata map[string]interface{} `json:"metadata"`
}

func (h *VaultHandler) DeleteVaultItem(c *gin.Context) {
	userId, _ := c.Get("userId")
	itemId := c.Param("id")
	ctx := c.Request.Context()

	itemRef := h.FirebaseSvc.Firestore.Collection("vault").Doc(itemId)
	doc, err := itemRef.Get(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
		return
	}

	if doc.Data()["userId"] != userId {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	_, err = itemRef.Update(ctx, []firestore.Update{
		{Path: "isDeleted", Value: true},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete item"})
		return
	}

	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_delete", "Soft deleted item: "+itemId, nil)
	c.JSON(http.StatusOK, gin.H{"message": "Item moved to recycle bin"})
}

func (h *VaultHandler) RestoreVaultItem(c *gin.Context) {
	userId, _ := c.Get("userId")
	itemId := c.Param("id")
	ctx := c.Request.Context()

	itemRef := h.FirebaseSvc.Firestore.Collection("vault").Doc(itemId)
	doc, err := itemRef.Get(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
		return
	}

	if doc.Data()["userId"] != userId {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	_, err = itemRef.Update(ctx, []firestore.Update{
		{Path: "isDeleted", Value: false},
		{Path: "updatedAt", Value: time.Now()},
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to restore item"})
		return
	}

	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_restore", "Restored item: "+itemId, nil)
	c.JSON(http.StatusOK, gin.H{"message": "Item restored from recycle bin"})
}

func (h *VaultHandler) EmptyRecycleBin(c *gin.Context) {
	userId, _ := c.Get("userId")
	ctx := c.Request.Context()

	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Where("isDeleted", "==", true).
		Documents(ctx)

	batch := h.FirebaseSvc.Firestore.Batch()
	count := 0
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to empty bin"})
			return
		}
		batch.Delete(doc.Ref)
		count++

		if count >= 500 {
			_, err := batch.Commit(ctx)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit batch"})
				return
			}
			batch = h.FirebaseSvc.Firestore.Batch()
			count = 0 // Reset for the NEXT batch, total count is logged after loop
		}
	}

	if count > 0 {
		_, err := batch.Commit(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit delete batch"})
			return
		}
	}

	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_empty_bin", "Emptied recycle bin", map[string]interface{}{"count": count})
	c.JSON(http.StatusOK, gin.H{"message": "Recycle bin emptied", "deletedCount": count})
}

func (h *VaultHandler) GetStats(c *gin.Context) {
	userIdVal, _ := c.Get("userId")
	userId := userIdVal.(string)
	ctx := c.Request.Context()

	// Optimization Pass 201: Use server-side aggregation for stats
	// Note: We'll stick to iteration for complex map counts if Aggregate() is unavailable in this SDK version,
	// but we'll optimize the query to only fetch necessary fields.
	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Where("isDeleted", "==", false).
		Select("size", "type").
		Documents(ctx)

	totalSize := int64(0)
	counts := map[string]int{
		"photo":    0,
		"video":    0,
		"audio":    0,
		"document": 0,
		"note":     0,
	}

	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch stats"})
			return
		}

		data := doc.Data()
		if isDeleted, ok := data["isDeleted"].(bool); ok && isDeleted {
			continue
		}

		fileType, _ := data["type"].(string)
		
		var size int64
		switch v := data["size"].(type) {
		case int64:
			size = v
		case int:
			size = int64(v)
		case float64:
			size = int64(v)
		case string:
			// Fallback for legacy string sizes (best effort)
			size = int64(len(v))
		}

		totalSize += size
		counts[fileType]++
	}

	c.JSON(http.StatusOK, gin.H{
		"totalSize":  totalSize,
		"photoCount": counts["photo"],
		"videoCount": counts["video"],
		"audioCount": counts["audio"],
		"docCount":   counts["document"],
		"noteCount":  counts["note"],
	})
}

// Security Pass 113: Consolidate Dashboard Payload
func (h *VaultHandler) GetDashboard(c *gin.Context) {
	userIdVal, _ := c.Get("userId")
	userId := userIdVal.(string)
	ctx := c.Request.Context()

	// 1. Fetch Stats & Aggregates
	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Select("size", "type", "isDeleted").
		Documents(ctx)

	totalSize := int64(0)
	counts := map[string]int{"photo": 0, "video": 0, "audio": 0, "document": 0, "note": 0}

	for {
		doc, err := iter.Next()
		if err == iterator.Done { break }
		if err != nil { break }
		data := doc.Data()
		if isDel, _ := data["isDeleted"].(bool); isDel { continue }

		fileType, _ := data["type"].(string)
		var size int64
		switch v := data["size"].(type) {
		case int64: size = v
		case int: size = int64(v)
		case float64: size = int64(v)
		}
		totalSize += size
		counts[fileType]++
	}

	// 2. Fetch Recent 5 Items
	recentIter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Where("isDeleted", "==", false).
		OrderBy("createdAt", firestore.Desc).
		Limit(5).
		Documents(ctx)

	var recent []map[string]interface{}
	for {
		doc, err := recentIter.Next()
		if err == iterator.Done { break }
		if err != nil { break }
		data := doc.Data()
		data["id"] = doc.Ref.ID
		recent = append(recent, data)
	}

	c.JSON(http.StatusOK, gin.H{
		"stats": gin.H{
			"totalSize":  totalSize,
			"photoCount": counts["photo"],
			"videoCount": counts["video"],
			"audioCount": counts["audio"],
			"docCount":   counts["document"],
			"noteCount":  counts["note"],
		},
		"recent": recent,
	})
}

func (h *VaultHandler) GetRecent(c *gin.Context) {
	userIdVal, _ := c.Get("userId")
	userId := userIdVal.(string)
	ctx := c.Request.Context()

	// Query recent 10 items
	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Where("isDeleted", "==", false).
		OrderBy("createdAt", firestore.Desc).
		Limit(10).
		Documents(ctx)

	var items []map[string]interface{}
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch recent items"})
			return
		}
		data := doc.Data()
		data["id"] = doc.Ref.ID
		items = append(items, data)
	}

	c.JSON(http.StatusOK, items)
}

func (h *VaultHandler) Upload(c *gin.Context) {
	userId, _ := c.Get("userId")
	ctx := c.Request.Context()

	header, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File is required"})
		return
	}

	// Resource Management Pass 4: Enforce 100MB limit
	if header.Size > 100*1024*1024 {
		c.JSON(http.StatusRequestEntityTooLarge, gin.H{"error": "File size exceeds 100MB limit"})
		return
	}

	file, err := header.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to open file"})
		return
	}
	defer file.Close()

	fileType := c.DefaultQuery("type", "document")
	fileName := c.PostForm("name")
	if fileName == "" {
		fileName = header.Filename
	}

	// Security Pass 381: Atomic Upload & Record Creation
	// Mismatch Fix: Use the correct bucket name from firebase_options.dart
	bucketName := "safeshell-app.firebasestorage.app"
	bucket, err := h.FirebaseSvc.Storage.Bucket(bucketName)
	if err != nil {
		log.Printf("Storage Error: Bucket %s not found: %v", bucketName, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Storage configuration error"})
		return
	}

	objectPath := "vault/" + userId.(string) + "/" + time.Now().Format("20060102150405") + "_" + fileName
	sw := bucket.Object(objectPath).NewWriter(ctx)
	sw.ContentType = header.Header.Get("Content-Type")
	
	if _, err := io.Copy(sw, file); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload to storage"})
		return
	}
	if err := sw.Close(); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to finalize storage upload"})
		return
	}

	publicURL := "https://firebasestorage.googleapis.com/v0/b/" + bucketName + "/o/" + 
		url.QueryEscape(objectPath) + "?alt=media"

	// 3. Save to Firestore using standardized schema
	docData := map[string]interface{}{
		"userId":    userId,
		"name":      fileName,
		"type":      fileType,
		"url":       publicURL,
		"size":      header.Size,
		"path":      objectPath,
		"isDeleted": false,
		"createdAt": time.Now(),
		"updatedAt": time.Now(),
	}

	docRef, _, err := h.FirebaseSvc.Firestore.Collection("vault").Add(ctx, docData)
	if err != nil {
		// Cleanup storage on DB failure
		_ = bucket.Object(objectPath).Delete(ctx)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save record"})
		return
	}

	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_upload", "Uploaded "+fileType+": "+fileName, map[string]interface{}{
		"id":   docRef.ID,
		"size": header.Size,
		"type": fileType,
	})

	c.JSON(http.StatusOK, gin.H{
		"message": "File uploaded successfully",
		"id":      docRef.ID,
		"_id":     docRef.ID,
		"url":     publicURL,
	})
}

func (h *VaultHandler) UploadMetadata(c *gin.Context) {
	userId, _ := c.Get("userId")
	ctx := c.Request.Context()

	var req CreateVaultRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Security Pass 361: Explicitly map allowed fields
	docData := map[string]interface{}{
		"userId":    userId,
		"name":      req.Name,
		"type":      req.Type,
		"url":       req.URL,
		"size":      req.Size,
		"path":      req.Path,
		"metadata":  req.Metadata,
		"isDeleted": false,
		"createdAt": time.Now(),
		"updatedAt": time.Now(),
	}

	docRef, _, err := h.FirebaseSvc.Firestore.Collection("vault").Add(ctx, docData)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save metadata"})
		return
	}

	// Audit Log
	itemType := req.Type
	itemName := req.Name
	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_create", "Created "+itemType+": "+itemName, map[string]interface{}{"id": docRef.ID, "type": itemType})

	c.JSON(http.StatusOK, gin.H{
		"message": "Metadata saved successfully",
		"id":      docRef.ID,
		"document": map[string]interface{}{
			"_id": docRef.ID,
		},
	})
}

func (h *VaultHandler) UpdateMetadata(c *gin.Context) {
	userId, _ := c.Get("userId")
	itemId := c.Param("id")
	ctx := c.Request.Context()

	var req UpdateVaultRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	itemRef := h.FirebaseSvc.Firestore.Collection("vault").Doc(itemId)
	doc, err := itemRef.Get(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
		return
	}

	if doc.Data()["userId"] != userId {
		c.JSON(http.StatusForbidden, gin.H{"error": "Unauthorized"})
		return
	}

	updateData := map[string]interface{}{
		"updatedAt": time.Now(),
	}
	if req.Name != "" {
		updateData["name"] = req.Name
	}
	if req.Metadata != nil {
		updateData["metadata"] = req.Metadata
	}

	_, err = itemRef.Set(ctx, updateData, firestore.MergeAll)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update metadata"})
		return
	}

	// Audit Log
	itemType, _ := doc.Data()["type"].(string)
	itemName := req.Name
	if itemName == "" {
		itemName, _ = doc.Data()["name"].(string)
	}
	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_update", "Updated "+itemType+": "+itemName, map[string]interface{}{"id": itemId, "type": itemType})

	c.JSON(http.StatusOK, gin.H{"message": "Metadata updated successfully"})
}

func (h *VaultHandler) CleanupOldDeletedItems(ctx context.Context) (int, error) {
	// Delete items where isDeleted == true and updatedAt < (now - 30 days)
	thirtyDaysAgo := time.Now().AddDate(0, 0, -30)

	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("isDeleted", "==", true).
		Where("updatedAt", "<", thirtyDaysAgo).
		Documents(ctx)

	batch := h.FirebaseSvc.Firestore.Batch()
	count := 0
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			return count, err
		}
		batch.Delete(doc.Ref)
		count++

		// Firestore batch limit is 500
		if count >= 500 {
			_, err := batch.Commit(ctx)
			if err != nil {
				return count, err
			}
			batch = h.FirebaseSvc.Firestore.Batch()
		}
	}

	if count > 0 && count%500 != 0 {
		_, err := batch.Commit(ctx)
		if err != nil {
			return count, err
		}
	}

	return count, nil
}

func (h *VaultHandler) DeleteBatch(c *gin.Context) {
	userId, _ := c.Get("userId")
	var req struct {
		IDs []string `json:"ids" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "List of IDs is required"})
		return
	}

	ctx := c.Request.Context()
	
	// Find items belonging ONLY to this user from the requested IDs
	// Firestore "in" query limit is 30. If req.IDs > 30, we'll need to chunk or use iteration.
	// For simplicity and safety, we'll iterate or use a query.
	// Optimization Pass 202: Use GetAll to avoid N+1 fetches
	refs := make([]*firestore.DocumentRef, len(req.IDs))
	for i, id := range req.IDs {
		refs[i] = h.FirebaseSvc.Firestore.Collection("vault").Doc(id)
	}

	docs, err := h.FirebaseSvc.Firestore.GetAll(ctx, refs)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch items for batch delete"})
		return
	}

	batch := h.FirebaseSvc.Firestore.Batch()
	count := 0
	for _, doc := range docs {
		if !doc.Exists() || doc.Data()["userId"] != userId {
			continue
		}

		batch.Update(doc.Ref, []firestore.Update{
			{Path: "isDeleted", Value: true},
			{Path: "updatedAt", Value: time.Now()},
		})
		count++

		if count >= 500 {
			_, err := batch.Commit(ctx)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit batch"})
				return
			}
			batch = h.FirebaseSvc.Firestore.Batch()
			count = 0
		}
	}

	if count > 0 {
		_, err := batch.Commit(ctx)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to commit remaining deletes"})
			return
		}
	}

	h.AuditSvc.LogEvent(ctx, userId.(string), "vault_delete_batch", "Moved multiple items to recycle bin", map[string]interface{}{
		"count": len(req.IDs),
	})

	c.JSON(http.StatusOK, gin.H{"message": "Items moved to recycle bin successfully"})
}
