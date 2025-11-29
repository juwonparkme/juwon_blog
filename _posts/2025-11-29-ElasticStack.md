---
layout: post
read_time: true
show_date: true
title: "DevOps 8  Elastic Stack"
date: 2025-11-24
description: Elastic Stack으로 Nginx 로그 모니터링 구축기 
tags: [devops, docker, django, filebeat, kibana, Elasticsearch, aws]
author: Juwon
---

## 1. 목표

- **내 EC2 서버(Nginx) 로그를 실시간으로 모니터링**하는 대시보드 만들기  
- 에러가 언제/어디서 많이 나는지 한눈에 보고 싶음  
- 블로그(`blog.juwonpark.me`) 트래픽과 기타 서비스 트래픽을 **분리해서** 보고 싶음  

최종 목표 파이프라인:

> **Nginx 로그 → Filebeat → Elasticsearch → Kibana 대시보드**

---

## 2. 전체 구조

- **EC2**
  - Nginx (access.log, error.log, blog_access.log …)
  - Filebeat 7.17.x
  - Docker
    - `es-test` : Elasticsearch 7.17.27
    - `kibana-test` : Kibana 7.17.27
- **Mac**
  - 브라우저에서 `http://localhost:5601` 접속  
  - SSH 터널: `localhost:5601 → EC2:5601`

아키텍처 흐름:

1. Nginx가 `/var/log/nginx/*.log`에 로그를 쓴다.
2. Filebeat가 해당 로그 파일을 tail 하면서 이벤트를 수집한다.
3. Filebeat가 수집한 이벤트를 **Elasticsearch**(도커 컨테이너)로 전송한다.
4. Kibana가 Elasticsearch 데이터를 읽어서 Discover / Dashboard에 시각화한다.

---

## 3. Elasticsearch & Kibana 도커로 띄우기

프로젝트 디렉터리 예시: `~/elastic-test`

### 3.1 docker-compose.yml 작성

(요약 형태)

```yaml
version: '3.7'
services:
  elasticsearch:
    image: docker.elastic.co/elasticsearch/elasticsearch:7.17.27
    container_name: es-test
    environment:
      - discovery.type=single-node
      - ES_JAVA_OPTS=-Xms512m -Xmx512m
    ports:
      - "9200:9200"
    # (볼륨, ulimits 등 생략)

  kibana:
    image: docker.elastic.co/kibana/kibana:7.17.27
    container_name: kibana-test
    ports:
      - "5601:5601"
    depends_on:
      - elasticsearch
````

실행:

```bash
cd ~/elastic-test
sudo docker compose up -d   # (또는 docker-compose up -d)
sudo docker ps              # es-test, kibana-test 떠있는지 확인
```

동작 확인:

```bash
curl -s localhost:9200
# Elasticsearch 버전/클러스터 정보 JSON 응답 확인
```

---

## 4. Mac ↔ EC2 SSH 터널 설정

로컬에서 Kibana에 접속하기 위해 **포트 포워딩** 사용:

```bash
ssh -L 5601:localhost:5601 ubuntu@<EC2_PUBLIC_IP>
```

* 브라우저에서 `http://localhost:5601` 접속하면 →
  SSH 터널을 통해 EC2의 `localhost:5601`(도커의 Kibana 컨테이너)로 연결된다.
* 터널이 끊기면 Kibana에서 `Failed to fetch`, `Error loading Discover` 같은 에러가 뜨므로,
  **에러 뜨면 먼저 SSH 접속이 살아있는지 확인**하는 습관 들이기.

---

## 5. Filebeat 설치 및 Elastic 저장소 추가

### 5.1 Elastic APT 저장소 등록

```bash
sudo apt update
sudo apt install apt-transport-https ca-certificates wget -y

wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

sudo apt update
```

### 5.2 Filebeat 설치 및 버전 확인

```bash
sudo apt install filebeat -y
filebeat version
# filebeat version 7.17.29 (amd64) ...
```

---

## 6. Filebeat에서 Nginx 로그 수집 설정

### 6.1 Nginx 모듈 활성화

```bash
sudo filebeat modules enable nginx
ls /etc/filebeat/modules.d/ | grep nginx
# nginx.yml enabled 확인
```

`/etc/filebeat/modules.d/nginx.yml` 내용 (핵심 부분):

```yaml
- module: nginx
  access:
    enabled: true
    var.paths:
      - /var/log/nginx/access.log
      - /var/log/nginx/blog_access.log   # 블로그 전용 로그도 수집

  error:
    enabled: true
    # 기본 경로(/var/log/nginx/error.log)를 사용
```

> `var.paths` 들여쓰기 신경 쓸 것
> (탭 대신 스페이스, `-`는 `var.paths:`보다 한 단계 깊게 들여쓰기)

---

## 7. Filebeat → Elasticsearch 출력 설정

`/etc/filebeat/filebeat.yml`에서 **output.elasticsearch** 부분을 로컬 ES로 설정:

```yaml
output.elasticsearch:
  hosts: ["http://localhost:9200"]
```

(기본 로깅/모니터링 부분은 기본값 사용)

### 7.1 설정 테스트 및 서비스 재시작

```bash
sudo filebeat test config         # 설정 문법 체크
sudo filebeat test output         # ES 연결 확인
# version: 7.17.27 등 나오면 OK

sudo systemctl enable filebeat
sudo systemctl restart filebeat
sudo systemctl status filebeat
```

---

## 8. Kibana에서 데이터 확인 (Discover)

### 8.1 데이터 뷰 선택

1. Kibana → **Discover**
2. Data view: `filebeat-*` 선택
   (처음에는 Stack Management → Data views에서 `filebeat-*` 생성해 두면 더 깔끔)

### 8.2 필드/로고 읽는 법

* 각 이벤트는 JSON 형태로 저장되고, Discover에서는 “필드: 값”으로 표시
* 예시:

  * `event.dataset: nginx.access` → Nginx access 로그
  * `http.response.status_code` → HTTP 응답 코드(200, 404, 500 …)
  * `url.path` → 요청한 경로(`/`, `/devops_processmonitoring.html` 등)
  * `log.file.path` → 실제 로그 파일 경로(`/var/log/nginx/access.log`, `/var/log/nginx/blog_access.log`)
  * `source.ip` → 클라이언트 IP
* 상단 KQL 검색창으로 필터링:

  * 모든 Nginx access 로그:

    ```kql
    event.dataset: "nginx.access"
    ```
  * 에러(4xx/5xx)만:

    ```kql
    event.dataset: "nginx.access" and http.response.status_code >= 400
    ```
  * 블로그 에러만:

    ```kql
    event.dataset: "nginx.access"
    and http.response.status_code >= 400
    and log.file.path : "/var/log/nginx/blog_access.log"
    ```

> **주의:** 검색창(KQL) 조건과 위에 파란 필터 칩은 **AND**로 모두 묶인다.
> `blog_access.log`를 찾으면서 필터 칩에서 `access.log`를 또 걸면 → 결과 0건.

---

## 9. 대시보드 구성

### 9.1 기본 에러 테이블 (전체 Nginx)

1. Discover에서 필터:

   ```kql
   event.dataset: "nginx.access" and http.response.status_code >= 400
   ```
2. 테이블 컬럼:

   * `@timestamp`
   * `url.path`
   * `http.response.status_code`
   * `log.file.path`
3. **Save** → Saved search 이름:

   ```text
   [Nginx] Errors (4xx 5xx)
   ```
4. Dashboard → **Add from library** → 위 Saved search 추가

### 9.2 요청 수 시간 그래프 (전체 Nginx)

1. Dashboard → **Create visualization → Lens**
2. KQL:

   ```kql
   event.dataset: "nginx.access"
   ```
3. X축: `@timestamp` (Date histogram)
   Y축: `Count of records`
4. 시각화 타입: `Area` 혹은 `Line`
5. 저장:

   ```text
   [Nginx] Requests over time
   ```

### 9.3 KPI Metric – Unique IPs

1. Dashboard → Create visualization → Lens → **Metric**
2. 집계:

   * Aggregation: `Unique count`
   * Field: `source.ip` (또는 `client.ip`)
   * Label: `Unique IPs`
3. KQL:

   ```kql
   event.dataset: "nginx.access"
   ```
4. 저장:

   ```text
   [Nginx] Unique IPs
   ```

(원하면 Error rate도 Formula로 만들 수 있음)

```text
100 * count(kql='http.response.status_code >= 400') / count()
```

---

## 10. 블로그 트래픽 vs 나머지 트래픽 분리

### 10.1 Requests over time 복제

1. `[Nginx] Requests over time` 패널에서 ⚙️ → **Duplicate panel**
2. 복제된 패널 ⚙️ → **Edit**

#### 블로그 전용 그래프

KQL:

```kql
event.dataset: "nginx.access"
and log.file.path : "/var/log/nginx/blog_access.log"
```

저장 이름:

```text
[Nginx] Blog requests over time
```

#### 기본 access.log 전용 그래프

다른 복제본에서 KQL:

```kql
event.dataset: "nginx.access"
and log.file.path : "/var/log/nginx/access.log"
```

저장 이름:

```text
[Nginx] Access.log requests over time
```

대시보드에서 두 그래프를 나란히 배치하면
**블로그 vs 다른 서비스 트래픽 비교**가 한눈에 들어온다.

### 10.2 블로그 에러 테이블

1. Discover에서 KQL:

```kql
event.dataset: "nginx.access"
and log.file.path : "/var/log/nginx/blog_access.log"
and http.response.status_code >= 400
```

2. 필요한 컬럼 선택 후 Saved search:

```text
[Nginx] Blog Errors (4xx 5xx)
```

3. Dashboard → Add from library → 위 패널 추가

---

## 11. 트러블슈팅 기록

### 11.1 Kibana – `Error loading Discover / Failed to fetch`

* 원인: **Mac ↔ EC2 SSH 터널 끊김**
* 증상:

  * 도커 `es-test`, `kibana-test`는 `Up`
  * `curl localhost:9200`는 정상
  * Kibana에서만 Discover/쿼리가 전부 실패
* 해결:

  * SSH 포트 포워딩 재접속

    ```bash
    ssh -L 5601:localhost:5601 ubuntu@<EC2_PUBLIC_IP>
    ```
  * (필요 시) `sudo docker restart kibana-test`

### 11.2 blog_access.log 데이터가 안 보이던 문제

* 원인 1: `nginx.yml`의 `var.paths`에 `blog_access.log`가 없었음

* 원인 2: Kibana 쪽에서 KQL은 `blog_access.log`를 찾는데
  필터 칩은 `access.log`를 걸어둔 상태라 **조건이 서로 모순**

* 해결:

  1. `/etc/filebeat/modules.d/nginx.yml`에 `blog_access.log` 추가
  2. Filebeat 재시작

     ```bash
     sudo systemctl restart filebeat
     ```
  3. Discover에서 불필요한 필터 칩 삭제 후 다시 검색

---

## 12. 정리

현재까지 구축한 **Elastic Stack 모니터링 1차 버전**:

* Nginx access/error 로그를 Filebeat로 수집
* Elasticsearch + Kibana를 Docker로 올려서 손쉽게 운영
* SSH 터널을 통해 로컬 브라우저에서 Kibana 접근
* 다음과 같은 대시보드를 구성

  * 전체 Nginx 요청 수 시간 그래프
  * 전체 4xx/5xx 에러 테이블
  * Unique IP Metric
  * 블로그 전용 Requests 그래프
  * 블로그 전용 에러 테이블

앞으로 할 수 있는 확장:

* Error rate(%) Metric 추가
* 특정 URL 기준으로 에러 Top N 테이블 만들기
* 알람(Watch/Alerting)으로 에러율이 급상승할 때 Slack/메일 알림

지금 단계까지만 봐도,

> “로그 파일만 보던 운영 → **시각적인 관제 대시보드** 기반 모니터링”

으로 한 단계 올라온 상태라고 정리할 수 있다.
