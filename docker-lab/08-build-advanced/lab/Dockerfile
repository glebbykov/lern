# syntax=docker/dockerfile:1.7

FROM golang:1.22-alpine AS builder
WORKDIR /src

COPY src/go.mod ./
RUN go mod download

COPY src/ ./
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/app ./main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/app /app

EXPOSE 8084
USER nonroot:nonroot
ENTRYPOINT ["/app"]
