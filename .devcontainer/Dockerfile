FROM ubuntu:20.04
RUN apt-get -y update && apt-get -y upgrade && apt-get install -y software-properties-common
RUN add-apt-repository -y ppa:deadsnakes/ppa && apt-get -y update
RUN apt-get install -y python3.11 
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1
RUN apt-get install -y protobuf-compiler python3-dev python3-pip patchelf zip curl

# Install protoc
ENV PROTOC_VERSION=30.2
ENV PB_REL="https://github.com/protocolbuffers/protobuf/releases"
RUN curl -LO ${PB_REL}/download/v${PROTOC_VERSION}/protoc-${PROTOC_VERSION}-linux-x86_64.zip && \
    unzip protoc-${PROTOC_VERSION}-linux-x86_64.zip -d /usr/local && \
    rm protoc-${PROTOC_VERSION}-linux-x86_64.zip