FROM golang:1.19.3 as build

ARG VERSION=v1.25.3

WORKDIR /

# package install
RUN apt update && \
    apt install -y rsync

# kubemark build
RUN git clone https://github.com/kubernetes/kubernetes  && \
    cd /kubernetes && \
    git checkout ${VERSION} &&\
    make WHAT="cmd/kubemark"

FROM registry.k8s.io/build-image/go-runner:v2.3.1-go1.17.2-bullseye.0 as run

COPY --from=build /kubernetes/_output/bin/kubemark /kubemark

ENTRYPOINT [ "/kubemark" ]