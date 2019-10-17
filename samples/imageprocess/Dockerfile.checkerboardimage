FROM golang:alpine as builder
RUN mkdir /build
ADD checkerboardimage /build/
WORKDIR /build
RUN go build -o checkerboardimage .
FROM alpine
COPY --from=builder /build/checkerboardimage /app/
WORKDIR /app
CMD ["./checkerboardimage"]