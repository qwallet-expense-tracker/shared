package kafka

import (
	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"log"
)

// BrokerMessageHandler is a function type that handles Kafka messages.
type BrokerMessageHandler func(*kafka.Message)

// NewConsumer creates a new Kafka consumer and subscribes to the given topics.
func NewConsumer(servers, groupId string, topics []string) (*kafka.Consumer, error) {
	// create a new consumer
	consumer, err := kafka.NewConsumer(&kafka.ConfigMap{
		"bootstrap.servers": servers,
		"group.id":          groupId,
		"auto.offset.reset": "earliest",
	})
	if err != nil {
		log.Fatalf("Failed to create consumer: %s\n", err)
	}

	// subscribe to topics
	go func(c *kafka.Consumer, topics []string) {
		if err = c.SubscribeTopics(topics, nil); err != nil {
			log.Fatalf("Failed to subscribe to topics %+v: %s\n", topics, err)
		}
	}(consumer, topics)

	return consumer, nil
}

// ConsumeMessages consumes messages from Kafka and calls the handler function for each message.
func ConsumeMessages(c *kafka.Consumer, handlers ...BrokerMessageHandler) {
	log.Printf("Starting the consumer with %d handler(s)..", len(handlers))
	for {
		msg, err := c.ReadMessage(-1)
		if err != nil {
			log.Printf("Consumer error: %v (%v)\n", err, msg)
		}
		for _, handler := range handlers {
			handler(msg)
		}
	}
}
