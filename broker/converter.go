package broker

import (
	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
	"github.com/golang/protobuf/proto"
	"log"
)

// ConvertMessageToProto converts a message to a protobuf message
func ConvertMessageToProto(msg *kafka.Message, out proto.Message) {
	log.Printf("Consumed message from Kafka: %s\n", string(msg.Value))
	if err := proto.Unmarshal(msg.Value, out); err != nil {
		log.Printf("Failed to unmarshal message: %v", err)
	}
}

// ConvertProtoToMessage converts a protobuf message to a byte array
func ConvertProtoToMessage(in proto.Message) ([]byte, error) {
	log.Printf("Producing message to Kafka: %v\n", in)
	return proto.Marshal(in)
}
