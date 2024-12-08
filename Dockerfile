FROM golang

RUN apt-get update
RUN apt-get upgrade

WORKDIR /usr/src/app

ENV GOOS=linux
ENV GOARCH=amd64

#ARG DB_ENDPOINT
#ARG DB_PORT
#ARG DB_USER
#ARG DB_PASS
#ARG DB_NAME
#
#RUN apt install postgresql

COPY go.mod go.sum ./
RUN go mod download && go mod verify

COPY . .
#RUN psql
RUN go build -v -o /usr/local/bin/app ./...
#RUN chmod +x /urs/src/golang-demo

CMD ["app"]
