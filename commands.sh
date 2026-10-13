#!/bin/bash

docker network create app-net

docker volume create db-data

docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  postgres:15-alpine

docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=mydb \
  -e DB_USER=postgres \
  -e DB_PASSWORD=secret \
  hw-backend:v1

sleep 3

docker exec app-container ping -c 2 db-server

docker exec -i db-server psql -U postgres -d mydb -c "CREATE TABLE products (id SERIAL PRIMARY KEY, name VARCHAR(50), price INT);"
docker exec -i db-server psql -U postgres -d mydb -c "INSERT INTO products (name, price) VALUES ('Laptop Gaming', 1500), ('Mouse Wireless', 30);"
docker exec -i db-server psql -U postgres -d mydb -c "SELECT * FROM products;"

docker rm -f db-server

docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  postgres:15-alpine

sleep 3

docker exec -i db-server psql -U postgres -d mydb -c "SELECT * FROM products;"
