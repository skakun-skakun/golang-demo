FROM golang

RUN apt-get update
RUN apt-get upgrade

ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64

WORKDIR /app

RUN go install github.com/air-verse/air@latest
COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY . .

EXPOSE 8080

CMD ["air", "-c", ".air.toml"]

#RUN go build -v -o /usr/local/bin/app ./...
##RUN chmod +x /urs/src/golang-demo
#
#CMD ["app"]
