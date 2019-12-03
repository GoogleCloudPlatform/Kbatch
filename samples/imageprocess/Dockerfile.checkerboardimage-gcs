FROM golang:alpine as builder
RUN mkdir /build
ADD checkerboardimage /build/
ADD gcs-example.sh /build/
WORKDIR /build
RUN go build -o checkerboardimage .
FROM google/cloud-sdk
COPY --from=builder /build/checkerboardimage /app/
COPY --from=builder /build/gcs-example.sh /app/
RUN chmod 777 /app/gcs-example.sh
WORKDIR /app
CMD ["./gcs-example.sh"]