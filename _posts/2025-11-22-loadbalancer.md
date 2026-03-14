---
layout: post
read_time: true
show_date: true
title: "Roadbalancer"
date: 2025-11-22
description:  Quiz_AI 서버에 Nginx 로드 밸런서 적용
tags: [devops, django, ubuntu]
author: Juwon
---
## 1. 목표: Django 서버를 두 개로 나눠 받고 Nginx로 분산하기

기존 구조는:

- Nginx  
- → Gunicorn (Django) 1개  
- → `127.0.0.1:8000` 으로만 연결

오늘 목표는:

- Gunicorn 프로세스 2개 (8000, 8001)  
- Nginx `upstream` 으로 두 포트에 로드 밸런싱

---

## 2. 기존 Nginx 설정 확인 (quizai.juwonpark.me)

원래 `quizai.juwonpark.me` Nginx 설정은 대략 이렇게 되어 있었다.

```nginx
server {
    listen 80;
    server_name quizai.juwonpark.me 3.38.116.255 127.0.0.1 localhost;

    client_max_body_size 100M;
    client_body_timeout 300s;
    client_body_buffer_size 512k;

    location = /favicon.ico {
        alias /home/ubuntu/Q_park_final/Quiz_AI/testpro/staticfiles/quiz_app/favicon.ico;
        access_log off;
        log_not_found off;
    }

    location /static/ {
        alias /home/ubuntu/Q_park_final/Quiz_AI/testpro/staticfiles/;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location /media/ {
        alias /home/ubuntu/Q_park_final/Quiz_AI/testpro/media/;
        add_header Cache-Control "public, max-age=604800";
        access_log off;
        expires 7d;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;  # 단일 포트
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
````

즉, **한 포트(8000)에만 프록시**하고 있었음.

---

## 3. Nginx에 `upstream` 추가해서 로드 밸런싱 적용

여기에 **로드 밸런서 역할**을 시키기 위해 `upstream` 블록을 추가하고,
`proxy_pass` 대상을 `127.0.0.1:8000` → `quiz_backend` 로 변경했다.

```nginx
# 1) server 블록 위에 upstream 추가
upstream quiz_backend {
    server 127.0.0.1:8000;
    server 127.0.0.1:8001;
}

# 2) server 블록의 location / 수정
server {
    listen 80;
    server_name quizai.juwonpark.me 3.38.116.255 127.0.0.1 localhost;

    client_max_body_size 100M;
    client_body_timeout 300s;
    client_body_buffer_size 512k;

    location = /favicon.ico {
        alias /home/ubuntu/Q_park_final/Quiz_AI/testpro/staticfiles/quiz_app/favicon.ico;
        access_log off;
        log_not_found off;
    }

    location /static/ {
        alias /home/ubuntu/Q_park_final/Quiz_AI/testpro/staticfiles/;
        add_header Cache-Control "public, max-age=31536000, immutable";
    }

    location /media/ {
        alias /home/ubuntu/Q_park_final/Quiz_AI/testpro/media/;
        add_header Cache-Control "public, max-age=604800";
        access_log off;
        expires 7d;
    }

    location / {
        proxy_pass http://quiz_backend;   # ← upstream 이름으로 변경

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_request_buffering off;
        proxy_read_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```

적용 순서:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

---

## 4. Gunicorn systemd 서비스 두 개로 분리

### 4.1 기존 `quizai.service` 오타 수정

기존 서비스 파일:

```ini
[Unit]
Description=Quiz_AI Django Service
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/Q_park_final/Quiz_AI/testpro
Environment="DJANGet_SETTINGS_MODULE=mysite.settings"
ExecStart=/home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/gunicorn \
          mysite.wsgi:application \
          --bind 127.0.0.1:8000 \
          --workers 3
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

여기서 `Environment` 부분에 **오타**가 있어서 수정:

```ini
Environment="DJANGO_SETTINGS_MODULE=mysite.settings"
```

그리고 Description만 살짝 바꿔서 정리:

```ini
[Unit]
Description=Quiz_AI Django Service (8000)
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/Q_park_final/Quiz_AI/testpro
Environment="DJANGO_SETTINGS_MODULE=mysite.settings"

ExecStart=/home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/gunicorn \
          mysite.wsgi:application \
          --bind 127.0.0.1:8000 \
          --workers 3

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 4.2 `quizai-2.service` 생성 (포트 8001)

서비스 파일을 그대로 복사해서 두 번째 인스턴스를 만들었다.

```bash
sudo cp /etc/systemd/system/quizai.service /etc/systemd/system/quizai-2.service
sudo vim /etc/systemd/system/quizai-2.service
```

내용에서 **포트만 8001로 변경**:

```ini
[Unit]
Description=Quiz_AI Django Service (8001)
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/Q_park_final/Quiz_AI/testpro
Environment="DJANGO_SETTINGS_MODULE=mysite.settings"

ExecStart=/home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/gunicorn \
          mysite.wsgi:application \
          --bind 127.0.0.1:8001 \
          --workers 3

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 4.3 systemd 리로드 + 서비스 시작

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now quizai.service quizai-2.service

sudo systemctl status quizai.service
sudo systemctl status quizai-2.service
```

정상일 때 `journalctl -u` 로그:

```text
[INFO] Listening at: http://127.0.0.1:8000 ...
[INFO] Listening at: http://127.0.0.1:8001 ...
```

그리고 `ss`로 포트 확인:

```bash
sudo ss -lntp | grep 800
```



## 7. 오늘 작업 요약

* Nginx에 `upstream quiz_backend` 추가해서
  `127.0.0.1:8000`, `127.0.0.1:8001` 두 포트로 로드 밸런싱 설정
* `quizai.service` 오타 수정 (`DJANGet_SETTINGS_MODULE` → `DJANGO_SETTINGS_MODULE`)
* `quizai-2.service` 생성해서 Gunicorn 두 번째 인스턴스를 8001 포트에 바인딩
* `systemctl`/`journalctl`/`ss` 명령으로 서비스와 포트 상태 확인

이번에 해본 셋업은 나중에 **EC2 여러 대로 확장하거나,
ALB 환경으로 넘어갈 때도 기본이 되는 패턴**이라,
오늘 작업은 “미니 로드밸런서 실습” 느낌으로 잘 정리된 하루였다.
