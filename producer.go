package tactify_kafka

import (
	"context"
	"fmt"
	"time"

	kafkaConfig "github.com/imadeddine-belkat/tactify-kafka/config"
	"github.com/segmentio/kafka-go"
	"google.golang.org/protobuf/encoding/protojson"
	"google.golang.org/protobuf/proto"
)

type Producer struct {
	writer *kafka.Writer
}

func NewProducer() *Producer {
	cfg := kafkaConfig.LoadConfig()

	var acks kafka.RequiredAcks
	switch cfg.KafkaAcks {
	case "0":
		acks = kafka.RequireNone
	case "1":
		acks = kafka.RequireOne
	default:
		acks = kafka.RequireAll
	}

	return &Producer{
		writer: &kafka.Writer{
			Addr:         kafka.TCP(cfg.KafkaBroker),
			Balancer:     &kafka.LeastBytes{},
			RequiredAcks: acks,
			BatchSize:    cfg.KafkaBatchSize,
			BatchTimeout: time.Duration(cfg.KafkaLingerMs) * time.Millisecond,
		},
	}
}

func (p *Producer) Publish(ctx context.Context, topic string, key, value []byte) error {
	return p.writer.WriteMessages(ctx, kafka.Message{
		Topic: topic,
		Key:   key,
		Value: value,
		Time:  time.Now(),
	})
}

func (p *Producer) Close() error {
	return p.writer.Close()
}

func (p *Producer) PublishWithProcess(ctx context.Context, model any, topic string, key []byte) error {

	m, ok := model.(proto.Message)
	if !ok {
		return fmt.Errorf("model does not implement proto.Message")
	}

	out, err := protojson.Marshal(m)
	if err != nil {
		return fmt.Errorf("failed to marshal model: %v for topic: %s", err, topic)
	}

	err = p.Publish(ctx, topic, key, out)
	if err != nil {
		fmt.Errorf("failed to publish with delete: %v", err)
	} else {
		fmt.Printf("Published message to topic %s with key %s\n", topic, string(key))
	}

	return nil
}
