FROM golang:1.19-alpine as build

WORKDIR /go/src
COPY go.mod .
COPY go.sum .

RUN go mod download

COPY . .

RUN go build -o /go/bin/kube-scheduler cmd/scheduler/main.go

FROM alpine as run

COPY --from=build /go/bin/kube-scheduler /kube-scheduler
COPY config/scheduler.conf /etc/kubernetes/custom-scheduler.conf

ENTRYPOINT ["/kube-scheduler", "--config=/etc/kubernetes/custom-scheduler.conf"]