# Dockerfile
FROM otel/opentelemetry-collector-contrib:latest

# We don't need EXPOSE 13133 if we aren't using an HTTP reload
EXPOSE 4317 4318

ENTRYPOINT ["/otelcol-contrib"]
CMD ["--config=/etc/otelcol/config.yaml"]