# syntax=docker/dockerfile:1.7

FROM golang:1.24-alpine AS builder
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY main.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /out/app ./main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /out/app /app
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app"]
