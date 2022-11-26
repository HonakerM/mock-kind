FROM golang:1.19-alpine as build

ARG VERSION=v1.25.3

WORKDIR /

# Clone Kubernetes
RUN apk update && \
    apk add git
RUN git clone https://github.com/kubernetes/kubernetes 

# Install Packages for build
RUN apk update && \
    apk add rsync git make bash gcc musl-dev coreutils

# kubemark build
RUN cd /kubernetes && \
    git checkout ${VERSION} &&\
    make WHAT="cmd/kubemark"

FROM alpine as run

COPY --from=build /kubernetes/_output/bin/kubemark /kubemark

ENTRYPOINT [ "/kubemark" ]