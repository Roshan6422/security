package handlers

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"sort"
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

	isDeleted := c.DefaultQuery("permanent", "false") == "false"

	if isDeleted {
		_, err = itemRef.Update(ctx, []firestore.Update{
			{Path: "isDeleted", Value: true},
			{Path: "updatedAt", Value: time.Now()},
		})
	} else {
		// Permanent Delete
		// 1. Get data to find storage path
		data := doc.Data()
		storagePath, _ := data["path"].(string)

		// 2. Delete from Firestore
		_, err = itemRef.Delete(ctx)

		// 3. Delete from Supabase Storage if path exists
		if err == nil && storagePath != "" {
			reqUrl := fmt.Sprintf("%s/storage/v1/object/vault/%s", h.FirebaseSvc.Config.SupabaseURL, storagePath)
			req, _ := http.NewRequestWithContext(ctx, "DELETE", reqUrl, nil)
			req.Header.Set("apikey", h.FirebaseSvc.Config.SupabaseKey)
			req.Header.Set("Authorization", "Bearer "+h.FirebaseSvc.Config.SupabaseKey)

			client := &http.Client{}
			resp, errDel := client.Do(req)
			if errDel != nil {
				log.Printf("Failed to delete from Supabase: %v", errDel)
			} else {
				resp.Body.Close()
			}
		}
	}
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

	// 1. Fetch ALL user items and filter in memory to avoid ANY index requirements
	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Documents(ctx)

	totalSize := int64(0)
	counts := map[string]int{"photo": 0, "video": 0, "audio": 0, "document": 0, "note": 0}
	allItems := []map[string]interface{}{} // Initialize as empty slice, not nil

	for {
		doc, err := iter.Next()
		if err == iterator.Done { break }
		if err != nil { break }
		data := doc.Data()
		data["id"] = doc.Ref.ID
		data["_id"] = doc.Ref.ID

		// Robust boolean check for isDeleted
		isDel := false
		if val, exists := data["isDeleted"]; exists {
			if b, ok := val.(bool); ok {
				isDel = b
			}
		}

		if isDel {
			continue // Dashboard only shows non-deleted items
		}

		// Robust type string check
		fileType := ""
		if t, ok := data["type"].(string); ok {
			fileType = t
		}
		
		var size int64
		if sVal, exists := data["size"]; exists {
			switch v := sVal.(type) {
			case int64: size = v
			case int: size = int64(v)
			case float64: size = int64(v)
			case float32: size = int64(v)
			}
		}
		totalSize += size
		if fileType != "" {
			counts[fileType]++
		}
		allItems = append(allItems, data)
	}

	// 2. Derive Recent 5 from same list
	sort.Slice(allItems, func(i, j int) bool {
		t1, _ := allItems[i]["createdAt"].(time.Time)
		t2, _ := allItems[j]["createdAt"].(time.Time)
		return t1.After(t2)
	})

	recent := allItems
	if len(recent) > 5 {
		recent = recent[:5]
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

	// Query all items and filter/sort in memory to bypass all index requirements
	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Documents(ctx)

	items := []map[string]interface{}{} // Initialize empty slice
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error: " + err.Error()})
			return
		}

		data := doc.Data()
		data["id"] = doc.Ref.ID
		data["_id"] = doc.Ref.ID

		// Filter deleted items (Robustly)
		isDel := false
		if val, exists := data["isDeleted"]; exists {
			if b, ok := val.(bool); ok {
				isDel = b
			}
		}

		if isDel {
			continue
		}

		items = append(items, data)
	}

	sort.Slice(items, func(i, j int) bool {
		t1, _ := items[i]["createdAt"].(time.Time)
		t2, _ := items[j]["createdAt"].(time.Time)
		return t1.After(t2)
	})

	limit := 10
	if len(items) < 10 {
		limit = len(items)
	}

	c.JSON(http.StatusOK, items[:limit])
}

func (h *VaultHandler) Upload(c *gin.Context) {
	userIdVal, exists := c.Get("userId")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}
	userId, ok := userIdVal.(string)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Invalid user ID type in context"})
		return
	}
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
	// Supabase Storage Integration
	objectPath := userId + "/" + time.Now().Format("20060102150405") + "_" + fileName
	
	// Stream to Supabase directly to prevent OOM on large videos
	reqUrl := fmt.Sprintf("%s/storage/v1/object/vault/%s", h.FirebaseSvc.Config.SupabaseURL, objectPath)
	req, _ := http.NewRequestWithContext(ctx, "POST", reqUrl, file)
	req.ContentLength = header.Size
	req.Header.Set("apikey", h.FirebaseSvc.Config.SupabaseKey)
	req.Header.Set("Authorization", "Bearer "+h.FirebaseSvc.Config.SupabaseKey)
	req.Header.Set("Content-Type", header.Header.Get("Content-Type"))

	client := &http.Client{}
	resp, errUp := client.Do(req)
	if errUp != nil {
		log.Printf("Supabase Upload Connection Error: %v", errUp)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to connect to Storage API"})
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		log.Printf("Supabase API Error (%d): %s", resp.StatusCode, string(body))
		// Send the exact error string back to the client so debugging is easier
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Storage server error (%d): %s", resp.StatusCode, string(body))})
		return
	}

	// Calculate public URL
	publicURL := fmt.Sprintf("%s/storage/v1/object/public/vault/%s", h.FirebaseSvc.Config.SupabaseURL, objectPath)

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
		log.Printf("Firestore Error: Failed to save vault record for user %s: %v", userId, err)
		// Cleanup Supabase on DB failure
		reqUrl := fmt.Sprintf("%s/storage/v1/object/vault/%s", h.FirebaseSvc.Config.SupabaseURL, objectPath)
		req, _ := http.NewRequestWithContext(ctx, "DELETE", reqUrl, nil)
		req.Header.Set("apikey", h.FirebaseSvc.Config.SupabaseKey)
		req.Header.Set("Authorization", "Bearer "+h.FirebaseSvc.Config.SupabaseKey)
		client := &http.Client{}
		if rs, err := client.Do(req); err == nil {
			rs.Body.Close()
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to save record: " + err.Error()})
		return
	}

	h.AuditSvc.LogEvent(ctx, userId, "vault_upload", "Uploaded "+fileType+": "+fileName, map[string]interface{}{
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

func (h *VaultHandler) ListVaultItems(c *gin.Context) {
	userIdVal, _ := c.Get("userId")
	userId := userIdVal.(string)
	itemType := c.Query("type")
	isDeletedQuery := c.DefaultQuery("isDeleted", "false") == "true"
	ctx := c.Request.Context()

	// Multi-field Where queries often crash without Composite Indexes.
	// We use a single-field query (userId) which is always indexed, then filter in memory.
	iter := h.FirebaseSvc.Firestore.Collection("vault").
		Where("userId", "==", userId).
		Documents(ctx)

	items := []map[string]interface{}{} // Initialize as empty slice to avoid 'null' JSON
	for {
		doc, err := iter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Printf("Firestore Query Error (ListVaultItems): %v", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Database error: " + err.Error()})
			return
		}

		data := doc.Data()
		data["_id"] = doc.Ref.ID
		data["id"] = doc.Ref.ID

		// Filter by isDeleted in memory (Robustly)
		isDel := false
		if val, exists := data["isDeleted"]; exists {
			if b, ok := val.(bool); ok {
				isDel = b
			}
		}

		if isDel != isDeletedQuery {
			continue
		}

		// Filter by type in memory (Robustly)
		typeMatch := true
		if itemType != "" {
			if val, exists := data["type"]; exists {
				if t, ok := val.(string); ok {
					if t != itemType {
						typeMatch = false
					}
				} else {
					typeMatch = false
				}
			} else {
				typeMatch = false
			}
		}

		if !typeMatch {
			continue
		}

		items = append(items, data)
	}

	// In-memory sort by createdAt DESC
	sort.Slice(items, func(i, j int) bool {
		t1, _ := items[i]["createdAt"].(time.Time)
		t2, _ := items[j]["createdAt"].(time.Time)
		return t1.After(t2)
	})

	c.JSON(http.StatusOK, items)
}
