package broker

// AccountTopic represents the topic for account events.
type AccountTopic string

const (
	AccountCreated AccountTopic = "qwallet.account.created"
	AccountUpdated AccountTopic = "qwallet.account.updated"
	AccountDeleted AccountTopic = "qwallet.account.deleted"
)

// UserTopic represents the topic for user events.
type UserTopic string

const (
	UserCreated UserTopic = "qwallet.user.created"
	UserUpdated UserTopic = "qwallet.user.updated"
	UserDeleted UserTopic = "qwallet.user.deleted"
)

// NotificationTopic represents the topic for notification events.
type NotificationTopic string

const (
	NotificationUserCreated    NotificationTopic = "qwallet.notification.user.created"
	NotificationAccountCreated NotificationTopic = "qwallet.notification.account.created"
)
