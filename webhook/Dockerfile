FROM golang:1.19-alpine as build
WORKDIR /app
COPY go.mod .
COPY go.sum .

RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags '-extldflags "-static"' -o serverd cmd/serverd/main.go

FROM alpine
COPY --from=build /app/serverd /
EXPOSE 8443

CMD ["/serverd"]