FROM golang:alpine as builder
RUN mkdir /build
ADD greyimage /build/
WORKDIR /build
RUN go build -o greyimage .
FROM alpine
COPY --from=builder /build/greyimage /app/
WORKDIR /app
CMD ["./greyimage"]