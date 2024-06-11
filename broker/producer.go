package broker

import (
	"fmt"
	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

// NewProducer creates a new Kafka producer.
func NewProducer(brokers string) (*kafka.Producer, error) {
	p, err := kafka.NewProducer(&kafka.ConfigMap{"bootstrap.servers": brokers})
	if err != nil {
		return nil, fmt.Errorf("failed to create producer: %w", err)
	}
	return p, nil
}

// ProduceMessage produces a message to the given topic.
func ProduceMessage(p *kafka.Producer, topic string, key, value []byte) error {
	deliveryChan := make(chan kafka.Event)
	if err := p.Produce(&kafka.Message{
		TopicPartition: kafka.TopicPartition{Topic: &topic, Partition: kafka.PartitionAny},
		Key:            key,
		Value:          value,
	}, deliveryChan); err != nil {
		return fmt.Errorf("failed to produce message: %w", err)
	}
	
	e := <-deliveryChan
	m := e.(*kafka.Message)
	if m.TopicPartition.Error != nil {
		return fmt.Errorf("delivery failed: %w", m.TopicPartition.Error)
	}
	return nil
}
