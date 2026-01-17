---
layout: post
read_time: true
show_date: true
title: "promethus+grafana"
date: 2026-01-16 23:59:00 +0900
description: 로컬(macOS)에서 Prometheus 수집 → Grafana 대시보드 → Alertmanager(Gmail) 알림까지 end-to-end 모니터링 파이프라인을 구성한 과정과 장애 해결 로그.
img: 
tags: [devops, grafana, prometheus, Alertmanager]
author: Juwon
github: JuWunpark/juwon_blog
---



````bash
cat > README.md <<'MD'
# Monitoring Lab (Prometheus + Grafana + Alertmanager)

## 목표
- macOS에서 Docker Compose로 모니터링 스택을 구축한다.
- Node Exporter 메트릭을 Prometheus가 수집하고, Grafana에서 시각화한다.
- Prometheus Alert Rule → Alertmanager → Gmail(SMTP)로 이메일 알림을 전송한다.

---

## 아키텍처
- **node-exporter**: 시스템 메트릭(CPU/RAM/Network 등) 제공
- **prometheus**: 메트릭 수집(scrape) + 알림 규칙 평가
- **alertmanager**: 알림 라우팅/그룹핑/전송 (Gmail로 이메일)
- **grafana**: 대시보드 시각화

흐름:
`node-exporter → prometheus → (rules) → alertmanager → Gmail`

---

## 실행 방법

### 1) 시작
```bash
docker compose up -d
docker ps
````

### 2) 접속 주소

* Prometheus: [http://localhost:9090](http://localhost:9090)
* Prometheus Targets(수집 대상): [http://localhost:9090/targets](http://localhost:9090/targets)
* Prometheus Rules(규칙 로드): [http://localhost:9090/rules](http://localhost:9090/rules)
* Prometheus Alerts(발동 상태): [http://localhost:9090/alerts](http://localhost:9090/alerts)
* Alertmanager: [http://localhost:9093](http://localhost:9093)
* Grafana: [http://localhost:3000](http://localhost:3000)

### 3) Prometheus 수집 확인

* `/targets`에서 `prometheus`, `node-exporter`가 **UP**인지 확인

### 4) Grafana 설정

1. Grafana 로그인 (기본: admin / admin)
2. Data source 추가: Prometheus

   * URL: `http://prometheus:9090`
3. 대시보드 Import

   * Dashboard ID: `1860` (Node Exporter Full)

---

## 알림(이메일) 설정

### 1) Gmail 준비

* Google 계정에서 **2단계 인증 활성화**
* **앱 비밀번호(App Password)** 생성 (예: 이름 `alertmanager`)

> ⚠️ 보안: 앱 비밀번호는 절대 GitHub에 커밋하지 말 것.

### 2) Alertmanager 설정(`alertmanager.yml`)

* Gmail SMTP 사용: `smtp.gmail.com:587`
* `smtp_from`, `smtp_auth_username`, `smtp_auth_password`, `to`를 본인 정보로 설정

### 3) Prometheus 규칙(`rules.yml`)

* 예시: `HighCpuUsage` (CPU > 90% for 5m)
* 빠른 검증용: `TestAlert` (vector(1) for 1m)

### 4) 동작 검증

* Prometheus `/alerts`에서 `TestAlert`가 **FIRING**인지 확인
* Gmail 수신함에서 테스트 메일 도착 확인

---

## 트러블슈팅

### 1) `Cannot connect to the Docker daemon ... docker.sock`

* Docker Desktop이 실행 중이어도 Engine이 아직 준비되지 않았거나 멈춘 경우 발생
* 해결: Docker Desktop 강제 종료 후 재실행, `docker version`에서 Server 항목 확인

### 2) `docker-credential-... executable file not found in $PATH`

원인:

* `~/.docker/config.json`의 `credsStore`가 credential helper를 호출
* 그런데 helper가 `/Volumes/Docker/...` 같은 **깨진 심볼릭 링크**를 가리키면 실행 실패

해결:

* 실제 바이너리(`/Applications/Docker.app/...`)로 심볼릭 링크 재설정
* 예: `/usr/local/bin/docker-credential-osxkeychain` → `/Applications/Docker.app/.../docker-credential-osxkeychain`

---

## TODO (확장 아이디어)

* macOS 호스트 디스크 지표(Root FS)가 N/A로 뜨는 이유 정리 및 대안(호스트 마운트/다른 exporter) 조사
* Grafana Alerting과 Prometheus Alerting 비교 정리
* Discord/Slack 알림 채널 추가

