FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/daylink-api ./cmd/daylink-api

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/daylink-api /daylink-api
VOLUME ["/var/lib/daylink/assets"]
EXPOSE 8080
ENTRYPOINT ["/daylink-api"]
