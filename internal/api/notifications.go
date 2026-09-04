package api

import (
	"log"
	"os/exec"
	"sync"
	"time"
)

// Notification represents a TETHER notification.
type Notification struct {
	ID        string    `json:"id"`
	Title     string    `json:"title"`
	Message   string    `json:"message"`
	Severity  string    `json:"severity"` // "info", "warning", "error"
	Timestamp time.Time `json:"timestamp"`
	Read      bool      `json:"read"`
}

// NotificationManager manages TETHER notifications.
type NotificationManager struct {
	mu            sync.RWMutex
	notifications []Notification
	maxSize       int
}

// NewNotificationManager creates a new notification manager.
func NewNotificationManager(maxSize int) *NotificationManager {
	if maxSize <= 0 {
		maxSize = 100
	}
	return &NotificationManager{
		notifications: make([]Notification, 0),
		maxSize:       maxSize,
	}
}

// Notify creates and optionally sends a notification.
func (nm *NotificationManager) Notify(title, message, severity string) Notification {
	nm.mu.Lock()
	defer nm.mu.Unlock()

	n := Notification{
		ID:        generateID(),
		Title:     title,
		Message:   message,
		Severity:  severity,
		Timestamp: time.Now(),
		Read:      false,
	}

	nm.notifications = append(nm.notifications, n)

	// Trim old notifications
	if len(nm.notifications) > nm.maxSize {
		nm.notifications = nm.notifications[len(nm.notifications)-nm.maxSize:]
	}

	// Send desktop notification if available
	go sendDesktopNotification(title, message, severity)

	log.Printf("notification [%s]: %s - %s", severity, title, message)
	return n
}

// GetNotifications returns all notifications.
func (nm *NotificationManager) GetNotifications() []Notification {
	nm.mu.RLock()
	defer nm.mu.RUnlock()

	result := make([]Notification, len(nm.notifications))
	copy(result, nm.notifications)
	return result
}

// GetUnreadCount returns the number of unread notifications.
func (nm *NotificationManager) GetUnreadCount() int {
	nm.mu.RLock()
	defer nm.mu.RUnlock()

	count := 0
	for _, n := range nm.notifications {
		if !n.Read {
			count++
		}
	}
	return count
}

// MarkAllRead marks all notifications as read.
func (nm *NotificationManager) MarkAllRead() {
	nm.mu.Lock()
	defer nm.mu.Unlock()

	for i := range nm.notifications {
		nm.notifications[i].Read = true
	}
}

// Clear removes all notifications.
func (nm *NotificationManager) Clear() {
	nm.mu.Lock()
	defer nm.mu.Unlock()
	nm.notifications = nm.notifications[:0]
}

// sendDesktopNotification sends a desktop notification using notify-send.
func sendDesktopNotification(title, message, severity string) {
	// Try notify-send (Linux)
	icon := "information"
	switch severity {
	case "warning":
		icon = "warning"
	case "error":
		icon = "error"
	}

	cmd := exec.Command("notify-send",
		"--app-name=TETHER",
		"--icon="+icon,
		"--urgency="+severityToUrgency(severity),
		title,
		message,
	)

	// Ignore errors - notification system is best-effort
	_ = cmd.Run()
}

// severityToUrgency maps severity to notify-send urgency levels.
func severityToUrgency(severity string) string {
	switch severity {
	case "error":
		return "critical"
	case "warning":
		return "normal"
	default:
		return "low"
	}
}

// generateID generates a simple unique ID for notifications.
func generateID() string {
	return time.Now().Format("20060102150405.000")
}

// Global notification manager instance.
var notifications = NewNotificationManager(100)
