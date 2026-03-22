package services

import (
	"context"
	"log"
	"time"

	"cloud.google.com/go/firestore"
)

type AuditService struct {
	Firestore *firestore.Client
}

func NewAuditService(firestore *firestore.Client) *AuditService {
	return &AuditService{Firestore: firestore}
}

func (s *AuditService) LogEvent(ctx context.Context, userId, eventType, description string, metadata map[string]interface{}) {
	event := map[string]interface{}{
		"userId":      userId,
		"type":        eventType, // e.g., "auth_login", "vault_delete", "admin_user_suspend"
		"description": description,
		"metadata":    metadata,
		"timestamp":   time.Now(),
	}

	_, _, err := s.Firestore.Collection("audit_logs").Add(ctx, event)
	if err != nil {
		log.Printf("failed to log audit event: %v", err)
	}
}
