package main

import (
	"context"
	"log"
	"time"

	"go.opentelemetry.io/otel/exporters/otlp/otlplog/otlploggrpc"
	log2 "go.opentelemetry.io/otel/log"
	"go.opentelemetry.io/otel/log/global"
	otellog "go.opentelemetry.io/otel/sdk/log"
	"go.opentelemetry.io/otel/sdk/resource"
	semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func main() {
	ctx := context.Background()

	// 1. Configure the Exporter
	// Replace with your SigNoz URL and Ingestion Key
	exporter, err := otlploggrpc.New(ctx,
		otlploggrpc.WithEndpoint("localhost:4317"),
		otlploggrpc.WithInsecure(),
	)
	if err != nil {
		log.Fatal(err)
	}

	// 2. Setup the Logger Provider with Resource Information
	res, _ := resource.Merge(
		resource.Default(),
		resource.NewWithAttributes(
			semconv.SchemaURL,
			semconv.ServiceNameKey.String("my-go-app"),
		),
	)

	lp := otellog.NewLoggerProvider(
		otellog.WithProcessor(otellog.NewBatchProcessor(exporter)),
		otellog.WithResource(res),
	)
	defer func(lp *otellog.LoggerProvider, ctx context.Context) {
		err = lp.Shutdown(ctx)
		if err != nil {
			log.Fatal(err)
		}
	}(lp, ctx)

	// Set as global so you can use it anywhere
	global.SetLoggerProvider(lp)

	// 3. Emit a log
	logger := global.Logger("main-logger")

	record := log2.Record{}
	record.SetTimestamp(time.Now())
	record.SetBody(log2.StringValue("Hello SigNoz! This is a test log from Go."))
	record.SetSeverity(log2.SeverityInfo)

	logger.Emit(ctx, record)

	log.Println("Log sent successfully!")
}
