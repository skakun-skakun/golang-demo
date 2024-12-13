#!/bin/bash

sudo apt-get update
sudo apt-get upgrade

git clone https://github.com/skakun-skakun/golang-demo.git /home/ubuntu/golang-demo

sudo apt-get -y install postgresql
sudo apt-get -y install golang-go
sudo apt-get -y install nginx

cd /home/ubuntu/golang-demo
sudo PGPASSWORD=12345678 psql -h ${rds_endpoint} -p 5432 -U postgres -f db_schema.sql
sudo GOOS=linux GOARCH=amd64 go build -o golang-demo
sudo chmod +x golang-demo

sudo touch /etc/systemd/system/golangdemo.service
sudo tee -a /etc/systemd/system/golangdemo.service <<EOF
[Unit]
Description = Golang Demo
After = network.target
[Service]
Type = simple
Restart = on-failure
User = ubuntu
ExecStart = /bin/bash -c 'DB_ENDPOINT=${rds_endpoint} DB_PORT=5432 DB_USER=postgres DB_PASS=12345678 DB_NAME=db /home/ubuntu/golang-demo/golang-demo'
WorkingDirectory = /home/ubuntu/golang-demo/
EOF

sudo tee /etc/nginx/nginx.conf <<EOF
http {
    server {
        listen 80;
        location / {
            proxy_pass http://localhost:8080;
        }
    }
}

events {}
EOF

sudo service nginx restart
sudo systemctl start golangdemo
sudo systemctl enable golangdemo

