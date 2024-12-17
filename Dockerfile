FROM golang:latest

RUN apt-get update
RUN apt-get upgrade

#ENV GO111MODULE=on \
#    CGO_ENABLED=0 \
ENV GOOS=linux \
    GOARCH=amd64

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download && go mod verify
RUN go install -mod=mod github.com/githubnemo/CompileDaemon
RUN go install -mod=mod github.com/gin-gonic/gin


COPY . .

ENTRYPOINT CompileDaemon --build="go build -o golang-demo" --command=./golang-demo -polling -directory="/app"
#CMD ["air", "-c", ".air.toml"]

#RUN go build -v -o /usr/local/bin/app ./...
##RUN chmod +x /urs/src/golang-demo
#
#CMD ["app"]
