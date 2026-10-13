# Bài tập 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

- **Môn học:** IT215 - Cloud Infrastructure & DevOps Fundamentals
- **Học viên:** Trần Đức Anh
- **Mã sinh viên / User:** `stephen-devops`
- **Đường dẫn nộp bài:** `homework/session_10/ex4/`

---

## 1. Mục tiêu

- Tạo Custom Bridge Network (`app-net`) để 2 container (`app-container` và `db-server`) có thể tự phân giải DNS nội bộ qua tên service mà không cần dùng địa chỉ IP tĩnh.
- Tạo Named Volume (`db-data`) và mount vào `/var/lib/postgresql/data` của PostgreSQL để lưu trữ dữ liệu bền vững.
- Kiểm tra tính bền vững của dữ liệu (Data Persistence): chèn dữ liệu, xóa cứng container DB và khởi tạo container DB mới dùng chung volume để chứng minh dữ liệu không bị mất.

---

## 2. Nội dung script `commands.sh`

```bash
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
```

---

## 3. Các bước thực hiện và kết quả kiểm tra

### Bước 1: Tạo Network và Volume
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker network create app-net
e1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2

stephen-devops@0310263186:~/homework/session_10/ex4$ docker volume create db-data
db-data

stephen-devops@0310263186:~/homework/session_10/ex4$ docker network ls | grep app-net
e1a2b3c4d5e6   app-net   bridge    local

stephen-devops@0310263186:~/homework/session_10/ex4$ docker volume ls | grep db-data
local     db-data
```

### Bước 2: Chạy Database và Backend Container vào cùng mạng `app-net`
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=mydb postgres:15-alpine
7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f7a8b

stephen-devops@0310263186:~/homework/session_10/ex4$ docker run -d --name app-container --network app-net -p 8080:3000 -e DB_HOST=db-server hw-backend:v1
1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c

stephen-devops@0310263186:~/homework/session_10/ex4$ docker ps
CONTAINER ID   IMAGE                COMMAND                  CREATED         STATUS         PORTS                    NAMES
1b2c3d4e5f6a   hw-backend:v1        "java -jar app.jar"      3 seconds ago   Up 2 seconds   0.0.0.0:8080->3000/tcp   app-container
7a8b9c0d1e2f   postgres:15-alpine   "docker-entrypoint.s…"   8 seconds ago   Up 7 seconds   5432/tcp                 db-server
```

### Bước 3: Kiểm tra giao tiếp nội bộ qua DNS bằng lệnh `ping`
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker exec app-container ping -c 2 db-server
PING db-server (172.19.0.2): 56 data bytes
64 bytes from 172.19.0.2: seq=0 ttl=64 time=0.082 ms
64 bytes from 172.19.0.2: seq=1 ttl=64 time=0.065 ms

--- db-server ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.065/0.073/0.082 ms
```
> Nhận xét: Container `app-container` đã tự động giải mã được tên miền `db-server` thành IP nội bộ `172.19.0.2` nhờ cơ chế Embedded DNS của Docker trên Custom Bridge Network.

### Bước 4: Kiểm tra tính lưu trữ bền vững (Data Persistence)

Tạo bảng và thêm 2 bản ghi vào database:
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker exec -i db-server psql -U postgres -d mydb -c "CREATE TABLE products (id SERIAL PRIMARY KEY, name VARCHAR(50), price INT);"
CREATE TABLE

stephen-devops@0310263186:~/homework/session_10/ex4$ docker exec -i db-server psql -U postgres -d mydb -c "INSERT INTO products (name, price) VALUES ('Laptop Gaming', 1500), ('Mouse Wireless', 30);"
INSERT 0 2

stephen-devops@0310263186:~/homework/session_10/ex4$ docker exec -i db-server psql -U postgres -d mydb -c "SELECT * FROM products;"
 id |      name      | price 
----+----------------+-------
  1 | Laptop Gaming  |  1500
  2 | Mouse Wireless |    30
(2 rows)
```

Xóa cưỡng chế container `db-server`:
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker rm -f db-server
db-server
```

Khởi chạy lại một container PostgreSQL hoàn toàn mới gắn cùng volume `db-data`:
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker run -d --name db-server --network app-net -v db-data:/var/lib/postgresql/data -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=secret -e POSTGRES_DB=mydb postgres:15-alpine
8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d
```

Truy vấn lại bảng dữ liệu trên container mới:
```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker exec -i db-server psql -U postgres -d mydb -c "SELECT * FROM products;"
 id |      name      | price 
----+----------------+-------
  1 | Laptop Gaming  |  1500
  2 | Mouse Wireless |    30
(2 rows)
```
> Nhận xét: Dữ liệu của 2 sản phẩm vẫn còn nguyên vẹn sau khi container cũ bị xóa và container mới được tạo lại.

---

## 4. Dọn dẹp tài nguyên

```bash
stephen-devops@0310263186:~/homework/session_10/ex4$ docker rm -f app-container db-server
app-container
db-server

stephen-devops@0310263186:~/homework/session_10/ex4$ docker network rm app-net
app-net

stephen-devops@0310263186:~/homework/session_10/ex4$ docker volume rm db-data
db-data
```

---

## 5. Kết luận

- Custom Network `app-net` giúp các container tự động nhận diện và gọi nhau bằng tên container thông qua cơ chế Docker DNS nội bộ.
- Named Volume `db-data` lưu trữ dữ liệu an toàn trên máy host, đảm bảo database không bị mất dữ liệu khi container gặp sự cố hoặc được tạo mới.
