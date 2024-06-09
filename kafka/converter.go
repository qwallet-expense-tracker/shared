package kafka

import (
	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"github.com/golang/protobuf/proto"
	"log"
)

// ConvertMessageToProto converts a message to a protobuf message
func ConvertMessageToProto(msg *kafka.Message, out proto.Message) {
	// convert to account payload
	log.Printf("Consumed message from Kafka: %s\n", string(msg.Value))
	
	// convert to account payload
	if err := proto.Unmarshal(msg.Value, out); err != nil {
		log.Printf("Failed to unmarshal message: %v", err)
	}
}
