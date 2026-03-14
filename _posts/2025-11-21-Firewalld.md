---
layout: post
read_time: true
show_date: true
title: "Firewalld"
date: 2025-11-19 
description: AWS Security Group + ufw로 이해하는 방화벽 흐름 정리
img:
tags: [devops, django, systemd, monitoring, ubuntu]
author: Juwon
---




오늘은 네트워크 도구가 아니라, **방화벽(Firewall)** 관점에서  
내 EC2 서버를 어떻게 보호하고, 어디까지 트래픽이 들어오는지 정리해봤다.

주요 키워드:
- AWS **Security Group**
- Ubuntu **ufw**
- 그리고 이 둘과 함께 보는 `ss`, `curl`, `dig` 같은 네트워크 도구들

---

## 1. Security Group vs ufw 한 줄 정리

### 🔒 Security Group (AWS 가상 방화벽)

- AWS에서 제공하는 **가상 방화벽**
- EC2 인스턴스 “앞단”에서 동작
- “**어떤 IP/포트/프로토콜을 이 인스턴스로 들여보낼지**” 결정
- 예시:
  - 22/tcp : 내 IP에서만 허용 (SSH)
  - 80/tcp, 443/tcp : 모든 곳(0.0.0.0/0)에서 허용 (웹서비스)

> 느낌: **건물 출입문에서 신분증 검사하는 보안 게이트**

---

### 🔐 ufw (Ubuntu 호스트 방화벽)

- Ubuntu OS에서 제공하는 **호스트 방화벽**
- EC2 안에서 동작 (리눅스 iptables를 쉽게 쓰게 해주는 래퍼)
- “**이 서버에 도달한 트래픽 중, 어떤 포트는 열고/닫을지**” 결정
- 예시:
  - `22/tcp` 허용 → SSH 유지
  - `80/tcp`, `443/tcp` 허용 → 웹서비스 허용
  - `8000/tcp` 허용/차단 → Django 개발 서버를 외부에 공개할지 말지 결정

> 느낌: **집 안에서 방 방문 잠그는 느낌**

---

## 2. 전체 요청 흐름 이해하기

`https://quizai.juwonpark.me` 로 접속할 때, 트래픽은 대략 이렇게 흐른다.

> **사용자 브라우저**  
> → **Cloudflare 엣지 서버** (104.21.x.x / 172.67.x.x)  
> → **AWS Security Group** (EC2 앞으로 들어오는지 필터링)  
> → **EC2 인스턴스** (Ubuntu)  
> → **ufw (포트 열림/차단)**  
> → **Nginx / Django 앱**

여기서 오늘 정리 포인트는:

- Security Group: **EC2 밖에서 1차 필터**
- ufw: **EC2 안에서 2차 필터**
- 둘 다 통과해야 실제 앱(Django)까지 도달할 수 있다.

---

## 3. 현재 포트 상태 확인 – `ss`

먼저, 이 서버에서 실제로 **어떤 포트가 열려 있는지** 확인:

```bash
sudo ss -tulnp
````

예시 출력:

```text
tcp   LISTEN 0 10   0.0.0.0:8000     0.0.0.0:*  users:(("python",pid=699700,fd=3))
tcp   LISTEN 0 80   127.0.0.1:3306   0.0.0.0:*  users:(("mariadbd",pid=476432,fd=22))
```

* `0.0.0.0:8000` + `python`

  * Django 개발 서버가 **모든 인터페이스에서 포트 8000을 리슨** 중
  * SG/ufw에서만 허용하면 외부에서도 접속 가능

* `127.0.0.1:3306` + `mariadbd`

  * MariaDB는 **로컬호스트(127.0.0.1)** 에서만 리슨
  * EC2 안에서만 접속 가능, 외부에서는 절대 접근 불가

👉 핵심:

* `0.0.0.0:포트` → “어디서 들어오든 다 받을 준비”
* `127.0.0.1:포트` → “이 서버 내부에서만 접속 허용”

---

## 4. DNS 레벨에서 흐름 확인 – `dig`

도메인이 **어디를 가리키는지** 확인:

```bash
dig +short quizai.juwonpark.me
```

예시:

```text
104.21.12.115
172.67.152.70
```

* A 레코드가 EC2 IP가 아니라 **Cloudflare IP**를 가리키고 있음

* 즉, `quizai.juwonpark.me` 요청은:

  > 사용자 → Cloudflare 엣지 서버 → (그 다음) EC2 로 전달

* Cloudflare 대시보드 기준으로 **주황 구름(프록시 ON)** 상태라는 뜻

> `dig` = “**도메인이 어떤 IP/레코드로 매핑되는지 보는 DNS 도구**”

---

## 5. HTTP 응답 확인 – `curl`

실제로 HTTP 요청을 보내서 **서버가 뭐라고 대답하는지** 확인:

```bash
curl -I https://quizai.juwonpark.me
```

예시 응답:

```text
HTTP/2 200
server: cloudflare
content-type: text/html; charset=utf-8
set-cookie: csrftoken=...
cf-cache-status: DYNAMIC
```

* `HTTP/2 200` → 웹서비스 응답 정상
* `server: cloudflare` → Cloudflare 엣지에서 응답
* `set-cookie: csrftoken=...` → 뒤에 Django 앱이 실제로 돌아가고 있다는 증거

> `curl -I` = “**상태 코드, 헤더만 빠르게 확인할 때 쓰는 HTTP 도구**”

---

## 6. ufw 기본 설정 흐름

### 6.1 ufw 설치/상태 확인

```bash
sudo apt update
sudo apt install ufw -y

sudo ufw status verbose
# Status: inactive (처음엔 보통 꺼져 있음)
```

### 6.2 SSH 먼저 허용 (중요)

ufw 켜기 전에 **SSH 포트(22/tcp)** 를 먼저 허용하지 않으면,
자기 자신을 서버 밖으로 내보내는 참사가 일어날 수 있다.

```bash
sudo ufw allow 22/tcp        # 또는 sudo ufw allow OpenSSH
```

웹서비스도 있다면:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### 6.3 ufw 활성화

```bash
sudo ufw enable
sudo ufw status verbose
```

이제:

* `Status: active`
* `22`, `80`, `443` 규칙들이 `ALLOW IN` 으로 뜨는지 확인

---

## 7. ufw로 특정 포트(8000) 열었다/닫았다 해보기

### 7.1 8000 포트 허용

```bash
sudo ufw allow 8000/tcp
sudo ufw status numbered
```

이 상태에서 로컬 PC에서:

```bash
curl -I http://서버공인IP:8000
```

* Django dev 서버가 떠 있다면, 응답이 오거나 최소 연결 시도는 된다.

### 7.2 8000 포트 차단

```bash
sudo ufw delete allow 8000/tcp
sudo ufw status numbered
```

다시 로컬 PC에서:

```bash
curl -I http://서버공인IP:8000
```

* 이제는 `Connection refused` 또는 타임아웃 등으로 실패할 수 있다.
* **같은 EC2/같은 앱인데도, ufw 설정에 따라 접근이 되기도 하고 안 되기도 한다는 것**을 체감할 수 있음.

---

## 8. Security Group vs ufw + 네트워크 도구 연결

정리하면, 실제 트래픽 흐름은 이렇게 단계별로 필터링된다.

1. **DNS** (`dig`)

   * `quizai.juwonpark.me` → Cloudflare IP (104.21.x.x / 172.67.x.x)

2. **클라우드 앞단 방화벽** – Security Group (AWS)

   * 이 인스턴스로 들어오는 IP/포트 허용 여부

3. **호스트 방화벽** – ufw (Ubuntu)

   * 서버 안에서 포트별로 허용/차단

4. **포트 상태** – `ss`

   * 실제로 해당 포트에 리슨 중인 프로세스가 있는지 확인

5. **HTTP 레벨** – `curl -I`

   * 최종적으로 앱이 정상 응답하는지 (200/301/403/500…)

---

## 9. 장애 터졌을 때 최소 체크리스트

서비스가 안 열릴 때, 감으로 찍지 말고 아래 순서대로 보자.

1. **DNS**

   ```bash
   dig +short quizai.juwonpark.me
   ```

   * 도메인이 예상한 IP(Cloudflare or EC2)를 가리키는지

2. **포트/프로세스**

   ```bash
   sudo ss -tulnp | grep -E '80|443|8000'
   ```

   * 해당 포트에 실제로 서비스가 떠 있는지

3. **Security Group**

   * AWS 콘솔에서 인바운드 규칙 확인 (22/80/443/8000 등)

4. **ufw**

   ```bash
   sudo ufw status verbose
   ```

   * 해당 포트가 `ALLOW IN` 인지, 막혀 있는지 확인

5. **HTTP 응답**

   ```bash
   curl -I https://quizai.juwonpark.me
   ```

   * 200인지, 403/502/500인지에 따라 원인 후보 좁히기

---

## 마무리

오늘 정리한 포인트를 한 줄로 요약하면:

> **Security Group은 “클라우드 레벨 문지기”, aws 등에서 제공하는 가상 방화벽
> ufw는 “서버 OS 레벨 문지기”, os에서 제공하는 방화벽 
> dig/ss/curl은 “이 문들이 어떻게 열리고 막혀 있는지 관찰하는 도구들”이다.**
> 사용자 → cloudflare 엣지 서버→ aws 보안그룹 → EC2 → Django 대략 이런 희름 


