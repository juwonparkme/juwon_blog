---
layout: post
read_time: true
show_date: true
title: "DevOps1 ProcessMonitoring"
date: 2025-11-17 
description: Ubuntu에서 Django 서비스 process monitoring 설정하기 (systemd + cron)
img:
tags: [devops, django, systemd, monitoring, ubuntu]
author: Juwon
---


## 들어가기 전에

목표는 간단하다.

> `manage.py runserver`로 돌리던 Django 개발 서버를  
> **systemd 서비스**로 올리고,  
> **주기적으로 상태를 체크하는 process monitoring**을 붙이는 것.

이번에 한 작업은 크게 세 단계였다.

1. `manage.py runserver`를 systemd 서비스로 등록
2. 서비스 상태를 확인하는 **체크 스크립트** 작성
3. 그 스크립트를 **cron**에 올려서 주기적으로 실행

아래는 실제 서버 환경과 함께 정리한 기록이다.

---

## 환경 정리

- OS: Ubuntu (AWS EC2)
- 프로젝트 루트:  
  `/home/ubuntu/Q_park_final/Quiz_AI`
- Django 프로젝트 디렉토리 (manage.py 위치):  
  `/home/ubuntu/Q_park_final/Quiz_AI/testpro`
- 가상환경:  
  `/home/ubuntu/Q_park_final/Quiz_AI/.venv`
- 목표: `python manage.py runserver 0.0.0.0:8000`를 systemd 서비스로 실행

---

## 1. systemd 서비스로 Django 실행하기

### 1-1. 서비스 파일 생성

`quizai.service`라는 이름으로 systemd 유닛 파일을 만들었다.

```bash
sudo tee /etc/systemd/system/quizai.service > /dev/null << 'EOF'
[Unit]
Description=Quiz_AI Django Service
After=network.target

[Service]
User=ubuntu
Group=ubuntu
WorkingDirectory=/home/ubuntu/Q_park_final/Quiz_AI/testpro
Environment="DJANGO_SETTINGS_MODULE=mysite.settings"

ExecStart=/home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/python /home/ubuntu/Q_park_final/Quiz_AI/testpro/manage.py runserver 0.0.0.0:8000

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
````

핵심 포인트:

* `WorkingDirectory`

  * **반드시 절대 경로**여야 한다.
  * `home/ubuntu/...`(X) → `/home/ubuntu/...`(O)
* `ExecStart`

  * 가상환경 파이썬: `/home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/python`
  * `manage.py`도 절대 경로로 지정:
    `/home/ubuntu/Q_park_final/Quiz_AI/testpro/manage.py`
* `Restart=always`

  * 프로세스가 크래시로 죽었을 때 **자동 재시작** 되도록 설정

`DJANGO_SETTINGS_MODULE` 값은 `testpro/manage.py` 상단에 있는 값과 맞춰야 한다.
(예: `mysite.settings`, `config.settings` 등)

---

### 1-2. 서비스 등록 및 시작

서비스 파일을 만든 뒤 systemd에 반영하고 실행했다.

```bash
# 서비스 설정 다시 읽기
sudo systemctl daemon-reload

# 부팅 시 자동 시작
sudo systemctl enable quizai.service

# 서비스 시작
sudo systemctl start quizai.service

# 상태 확인
sudo systemctl status quizai.service
```

정상일 때 출력 예시는 다음과 같다.

```text
● quizai.service - Quiz_AI Django Service
     Loaded: loaded (/etc/systemd/system/quizai.service; enabled; preset: enabled)
     Active: active (running) since Mon 2025-11-17 13:36:13 UTC; 5s ago
   Main PID: 668801 (python)
      Tasks: 4 (limit: 2204)
     Memory: 149.8M (peak: 150.0M)
        CPU: 2.576s
     CGroup: /system.slice/quizai.service
             ├─668801 /home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/python /home/ubuntu/Q_park_final/Quiz_AI/testpro/manage.py runserver …
             └─668803 /home/ubuntu/Q_park_final/Quiz_AI/.venv/bin/python /home/ubuntu/Q_park_final/Quiz_AI/testpro/manage.py runserver …

Nov 17 13:36:14 ip-172-26-15-41 python[668803]: Watching for file changes with StatReloader
```

여기까지가:

* 개발 서버를 systemd 서비스로 올리고
* 백그라운드에서 돌아가게 만든 단계.

---

### 1-3. 크래시 자동 재시작 테스트

`Restart=always`가 실제로 동작하는지 확인하기 위해 일부러 프로세스를 죽여 봤다.

```bash
# PID 확인 (manage.py 기준으로)
pgrep -af manage.py

# 확인한 PID로 강제 종료
sudo kill -9 <PID>
```

이후 `status`를 다시 보면, 잠깐 실패했다가 다시 `active (running)` 상태로 돌아온다.
`journalctl`로 보면 이런 로그가 찍힌다.

```bash
sudo journalctl -u quizai.service -n 10 --no-pager
```

* Main process exited (status 9)
* 곧바로 "Started quizai.service..." 로그 출력

반대로, `sudo systemctl stop quizai.service`로 직접 중지시킨 경우에는
“관리자가 의도적으로 끈 것”으로 간주해서 자동 재시작되지 않는다.
이 차이가 실제 운영에서 중요한 포인트.

---

## 2. 서비스 상태 체크 스크립트 작성

자동 재시작 설정만으로 끝내지 않고,
**주기적으로 서비스 상태를 확인하는 체크 스크립트**를 추가했다.

### 2-1. 스크립트 생성

```bash
sudo vim /usr/local/bin/check_quizai.sh
```

내용:

```bash
#!/bin/bash

SERVICE="quizai.service"
LOGFILE="/var/log/quizai_monitor.log"

if ! systemctl is-active --quiet "$SERVICE"; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') $SERVICE is NOT active" >> "$LOGFILE"
fi
```

* `systemctl is-active quizai.service`

  * `active`가 아니면 로그에 한 줄 남기도록 했다.
* 나중에는 여기서 `systemctl start`나 Slack Webhook 호출 등을 추가해서
  “자동 복구 + 알림” 기능으로 확장할 수 있다.

실행 권한 부여:

```bash
sudo chmod +x /usr/local/bin/check_quizai.sh
```

수동 테스트:

```bash
sudo /usr/local/bin/check_quizai.sh
sudo cat /var/log/quizai_monitor.log
```

이 시점에 서비스가 정상이라면 로그가 비어 있거나,
이전 테스트에서 찍힌 기록만 보인다.

---

## 3. cron으로 주기적인 process monitoring

이제 체크 스크립트를 **정해진 주기마다 자동 실행**하기 위해 cron에 등록했다.

### 3-1. root의 crontab 수정

서비스 상태를 보려면 `systemctl`을 써야 하므로,
root의 crontab에 등록했다.

```bash
sudo crontab -e
```

파일 맨 아래에 다음 한 줄 추가:

```cron
* * * * * /usr/local/bin/check_quizai.sh
```

* 의미: 1분마다 `check_quizai.sh` 실행
* 서비스가 active가 아니면 `/var/log/quizai_monitor.log`에 기록 남김

---

### 3-2. 동작 확인

1분 정도 기다린 뒤:

```bash
sudo cat /var/log/quizai_monitor.log
```

예시:

```text
2025-11-17 13:46:01 quizai.service is NOT active
```

이 줄은 그 시점에 `quizai.service`가 active가 아니었다는 의미다.
(설정 중이거나, 중지 테스트 직후에 찍힌 로그)

서비스를 의도적으로 꺼놓고 테스트할 수도 있다.

```bash
# 서비스 중지
sudo systemctl stop quizai.service

# 1~2분 후 로그 확인
sudo cat /var/log/quizai_monitor.log
```

추가로 한 줄 이상 찍혀 있다면 cron + 스크립트가 정상적으로 동작하는 것.

다시 서비스는 수동으로 시작해준다.

```bash
sudo systemctl start quizai.service
```

---

## 4. 정리: 지금 상태에서의 process monitoring 수준

현재 구성된 구조는 다음과 같다.

1. **systemd 서비스 (`quizai.service`)**

   * 서버 부팅 시 자동 시작
   * 프로세스가 크래시로 죽으면 자동 재시작 (`Restart=always`)
   * `systemctl status`, `journalctl -u`로 상태와 로그 확인 가능

2. **체크 스크립트 (`/usr/local/bin/check_quizai.sh`)**

   * `systemctl is-active`로 서비스 상태 확인
   * active가 아닐 때만 `/var/log/quizai_monitor.log`에 기록

3. **cron**

   * 1분마다 체크 스크립트 실행
   * 서비스가 죽어 있던 시간대를 로그로 남김

여기까지가 DevOps 관점에서의 **기본적인 process monitoring** 세팅이다.
여기에 추가로,

* 체크 스크립트에서 `systemctl start`까지 해버려서 자동 복구
* Slack / 이메일 알림 붙이기
* Prometheus + Grafana 연동으로 시각화

같은 것들을 얹으면 보다 “운영다운” 모니터링 시스템으로 확장할 수 있다.

## 결론 
다음에 할 작업으로는 Performance Monitoring과 Networking Tools, Text Manipulations 을 좀 공부해봐야 할 것 같다. 

