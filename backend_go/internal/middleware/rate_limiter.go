package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

type clientLimit struct {
	lastSeen time.Time
	count    int
}

var (
	clients = make(map[string]*clientLimit)
	mu      sync.Mutex
)

func init() {
	// Cleanup old entries every 5 minutes
	go func() {
		for {
			time.Sleep(5 * time.Minute)
			mu.Lock()
			for ip, limit := range clients {
				if time.Since(limit.lastSeen) > 5*time.Minute {
					delete(clients, ip)
				}
			}
			mu.Unlock()
		}
	}()
}

// AuthRateLimiter limits sensitive auth requests to 5 per minute per IP
func AuthRateLimiter() gin.HandlerFunc {

	return func(c *gin.Context) {
		ip := c.ClientIP()
		mu.Lock()
		defer mu.Unlock()

		limit, exists := clients[ip]
		if !exists {
			// Security Pass 503: Cap map size to 10,000 entries to prevent OOM
			if len(clients) >= 10000 {
				c.JSON(http.StatusServiceUnavailable, gin.H{"error": "Server busy, please try again later"})
				c.Abort()
				return
			}
			clients[ip] = &clientLimit{lastSeen: time.Now(), count: 1}
			c.Next()
			return
		}

		// Reset count if a minute has passed
		if time.Since(limit.lastSeen) > time.Minute {
			limit.count = 1
			limit.lastSeen = time.Now()
			c.Next()
			return
		}

		if limit.count >= 5 {
			c.JSON(http.StatusTooManyRequests, gin.H{
				"error": "Too many requests. Please wait a minute before trying again.",
			})
			c.Abort()
			return
		}

		limit.count++
		limit.lastSeen = time.Now()
		c.Next()
	}
}
