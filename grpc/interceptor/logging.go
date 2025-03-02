package interceptor

import (
	"context"
	"fmt"
	"google.golang.org/grpc"
	"log"
	"strings"
	"time"
)

var (
	ignoredMethods = []string{
		"/grpc.health.v1.Health/Check",
		"/grpc.health.v1.Health/Watch",
		"/grpc.reflection.v1alpha.ServerReflection/ServerReflectionInfo",
	}
)

// LoggingUnaryInterceptor logs the unary request
func LoggingUnaryInterceptor(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	for _, m := range ignoredMethods {
		if strings.Contains(info.FullMethod, m) {
			return handler(ctx, req)
		}
	}
	
	start := time.Now()
	
	h, err := handler(ctx, req)
	
	// logging
	log.Printf(`
================== ⚡️ gRPC Unary Call ⚡️ ===================
⚙️Method: %v

☘️↙️Request: %+v
❄️↗️Response: %+v

⏰Duration: %v
======================================================
`, info.FullMethod, req, h, time.Since(start))
	//Request: %v
	return h, err
}

// LoggingStreamInterceptor logs the stream request
func LoggingStreamInterceptor(srv interface{}, ss grpc.ServerStream, info *grpc.StreamServerInfo, handler grpc.StreamHandler) error {
	for _, m := range ignoredMethods {
		if strings.Contains(info.FullMethod, m) {
			return handler(srv, ss)
		}
	}
	
	start := time.Now()
	
	// Create a wrapper around the ServerStream to log incoming messages
	wrappedStream := newWrappedStream(ss)
	err := handler(srv, wrappedStream)
	
	// logging
	log.Printf(`
================== ⚡️ gRPC Streaming Call ⚡️ ===================
⚙️Method: %v

%v

⏰Duration: %v
⛔️Error: %v
======================================================
`, info.FullMethod, wrappedStream.logMsg, time.Since(start), err)
	
	return err
}

// Ensure the wrappedStream struct implements the grpc.ServerStream interface
type wrappedStream struct {
	grpc.ServerStream
	logMsg string
}

// newWrappedStream creates a new wrappedStream instance
func newWrappedStream(stream grpc.ServerStream) *wrappedStream {
	return &wrappedStream{ServerStream: stream, logMsg: ""}
}

func (w *wrappedStream) RecvMsg(m any) error {
	err := w.ServerStream.RecvMsg(m)
	w.logMsg += fmt.Sprintf("☘️↙️Received message: %v\n", m)
	return err
}

func (w *wrappedStream) SendMsg(m any) error {
	err := w.ServerStream.SendMsg(m)
	w.logMsg += fmt.Sprintf("\n❄️↗️Sent message: %v", m)
	return err
}
