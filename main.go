package main

import (
	"context"
	"fmt"
	"os"

	"go.opentelemetry.io/contrib/bridges/otelzap"
	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploghttp"
	"go.opentelemetry.io/otel/sdk/log"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

func main() {
	otlpEndpoint := "localhost:4318"
	ctx := context.Background()

	// Create an exporter that will emit log records.
	exporter, err := otlploghttp.New(ctx,
		otlploghttp.WithEndpoint(otlpEndpoint),
		otlploghttp.WithInsecure(),
	)
	if err != nil {
		fmt.Println(err)
	}
	// Create a log record processor pipeline.
	processor := log.NewBatchProcessor(exporter)

	// Create a logger provider.
	// You can pass this instance directly when creating a log bridge.
	provider := log.NewLoggerProvider(
		log.WithProcessor(processor),
	)

	defer func() {
		err := provider.Shutdown(context.Background())
		if err != nil {
			fmt.Println(err)
		}
	}()

	core := zapcore.NewTee(
		zapcore.NewCore(zapcore.NewJSONEncoder(zap.NewProductionConfig().EncoderConfig), os.Stderr, zapcore.InfoLevel),
		otelzap.NewCore("my/pkg/name", otelzap.WithLoggerProvider(provider)),
	)

	logger := zap.New(core)

	// Initialize a zap logger with the otelzap bridge core.
	defer logger.Sync()

	// You can now use your logger in your code.
	logger.Info("something really cool")

	// You can set context for trace correlation using zap.Any or zap.Reflect
	logger.Info("setting context", zap.Any("context", ctx))

	logger.Info("Hello from Zap!")
}
