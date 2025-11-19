---
layout: post
read_time: true
show_date: true
title: "DevOps3 Networking Tools"
date: 2025-11-19 
description: Networking Tools로 서비스 상태 빠르게 체크하기 (실습 기록)
tags: [devops, django, systemd, monitoring, ubuntu]
author: Juwon
---



## Networking Tools(실습 기록)

Ubuntu 서버에서 `quizai.juwonpark.me`를 운영하면서, 기본적인 **네트워크 진단 도구**들을 직접 찍어보며 정리한 내용이다. “사이트가 안 열릴 때 어디부터 봐야 하는지”를 감 잡는 게 목표였다.

---

### 1. ping – 제일 먼저 “살아는 있냐” 확인

```bash
ping -c 4 google.com
```

* `4 packets transmitted, 4 received, 0% packet loss`
* `avg ≈ 28ms`

→ **패킷 손실 0%, 평균 지연 28ms**로, 서버에서 인터넷(구글)까지 기본 연결은 정상.

---

### 2. traceroute – 어디를 거쳐 가는지 경로 확인

```bash
traceroute google.com
```

* 여러 개의 홉(hop)을 거쳐 마지막에 `142.250.xxx.xxx` (google 서버 IP)에 도달
* 중간에 타임아웃이나 `* * *` 없이 끝까지 도달

→ **내 서버 → 통신사/백본 → 구글 네트워크**로 이어지는 경로가 끊기지 않고 이어져 있다는 뜻.

---

### 3. curl -I – HTTP 응답 상태 코드/헤더 확인

#### 3-1. 구글 테스트

```bash
curl -I https://google.com
# HTTP/2 301 (www.google.com 으로 리다이렉트)

curl -I https://www.google.com
# HTTP/2 200
```

* `301` → “다른 URL로 영구 이동(리다이렉트)”
* `200` → “정상적으로 처리됨(OK)”

→ **네트워크 + HTTPS + HTTP 레벨까지 모두 정상**이라는 걸 확인.

#### 3-2. 내 서비스 테스트

```bash
curl -I https://quizai.juwonpark.me
```

결과:

* `HTTP/2 200`
* `server: cloudflare`
* `set-cookie: csrftoken=...` (Django CSRF 토큰)
* `cf-cache-status: DYNAMIC`

→ Cloudflare 엣지에서 응답을 주고 있고, 뒤에는 **Django 앱이 정상 동작** 중이라는 걸 알 수 있다.

> 정리:
> **`curl -I`는 “이 URL에 HTTP로 말 걸었을 때 서버가 뭐라고 대답하는지” 보는 도구**
> → 상태 코드 / 헤더만 빠르게 확인할 때 유용.

---

### 4. dig – 도메인이 어디를 가리키는지 (DNS)

```bash
dig quizai.juwonpark.me
```

결과 (핵심만):

```text
;; ANSWER SECTION:
quizai.juwonpark.me. 300 IN A 172.67.152.70
quizai.juwonpark.me. 300 IN A 104.21.12.115
```

* A 레코드가 EC2 IP가 아니라 **Cloudflare IP 대역**을 가리킴
* 즉, Cloudflare 대시보드에서 **주황색 구름(프록시 ON)** 상태

→ 실제 트래픽 흐름은
**사용자 → Cloudflare 엣지(IP 172.67.x.x / 104.21.x.x) → EC2(Django)** 구조.

> 정리:
> **`dig`는 “이 도메인이 DNS에서 어떤 IP/레코드를 가리키는지” 확인하는 도구**

---

### 5. ss – 서버에서 어떤 포트가 열려 있는지 확인

```bash
sudo ss -tulnp | head
```

일부 결과:

```text
tcp LISTEN 0 10      0.0.0.0:8000     0.0.0.0:* users:(("python",pid=...,fd=3))
tcp LISTEN 0 80      127.0.0.1:3306   0.0.0.0:* users:(("mariadbd",pid=...,fd=22))
```

* `0.0.0.0:8000` + `python`
  → Django 개발 서버가 **모든 인터페이스에서 포트 8000을 리슨** 중
  → 보안그룹/ufw만 열려 있으면 외부에서도 접속 가능

* `127.0.0.1:3306` + `mariadbd`
  → MariaDB는 **로컬호스트(127.0.0.1)에서만 리슨**
  → 같은 서버 안에서만 접속 가능, 외부 접근은 차단

> 핵심 정리:
>
> * `0.0.0.0:포트` → “어디서 들어오든 다 받아줄 준비 완료”
> * `127.0.0.1:포트` → “이 서버 내부에서만 접속 허용”

---

### 6. 장애 났을 때 쓸 수 있는 최소 체크리스트

서비스가 안 열릴 때, 감으로 찍지 말고 아래 순서로 보자:

1. **기본 네트워크**

   ```bash
   ping 8.8.8.8
   ping quizai.juwonpark.me
   ```
2. **DNS**

   ```bash
   dig quizai.juwonpark.me
   ```
3. **HTTP 상태**

   ```bash
   curl -I https://quizai.juwonpark.me
   ```
4. **서버 포트**

   ```bash
   sudo ss -tulnp | grep -E '80|443|8000'
   ```

이 네 가지만 익혀도
**“DNS 문제냐, Cloudflare 문제냐, Nginx/백엔드 문제냐”**
를 훨씬 빨리 좁혀갈 수 있겠단 생각이 든다.

---
## 결론 
* 뭐 기억이 그때그때 날진 모르겠지만 종종 개발한거 서버에 올리고 배포할때마다 사용할 것 같다.
