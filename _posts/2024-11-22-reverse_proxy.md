


# Reverse Proxy 개념 간단 정리 (Nginx + Django 기준)

오늘은 **reverse proxy(역방향 프록시)**가 뭔지, 그리고 **Nginx + Django 배포에서 어떤 역할을 하는지**를 정리해본다.

---

## 1. Reverse Proxy란?

**정의 한 줄 요약**

> 클라이언트(사용자) 대신 앞에서 요청을 받아서,  
> 뒤에 숨겨진 서버들(앱 서버, gunicorn/Django 등)로 전달해 주는 서버

흐름은 이렇게 된다.

```text
브라우저(사용자)
    ↓
Nginx (Reverse Proxy)
    ↓
Gunicorn / Django (백엔드 서버)
````

* 브라우저 입장에서는 **Nginx만 보임**
* 뒤에 어떤 서버가 몇 개 있는지, 포트가 뭔지는 모름
* Nginx가 요청을 보고 적절한 서버로 **대신** 보내준다

---

## 2. Forward Proxy vs Reverse Proxy 차이

헷갈리기 쉬운 개념이라 간단히만 비교.

### Forward Proxy (정방향 프록시)

* **클라이언트 쪽에 붙어 있는 프록시**
* 회사/학교에서 쓰는 인터넷 프록시, VPN 같은 느낌
* 서버는 “프록시를 통해 오는 사용자”만 본다

```text
클라이언트 → Forward Proxy → 인터넷의 서버들
```

### Reverse Proxy (역방향 프록시)

* **서버 쪽 입구에 붙어 있는 프록시**
* 외부 요청을 대신 받아서 내부 서버로 전달
* 클라이언트는 뒤에 뭐가 있는지 모른다

```text
클라이언트 → Reverse Proxy(Nginx) → 내부 서버들(gunicorn, Node, etc)
```

---

## 3. Nginx + Django 배포 구조에서 Reverse Proxy

Django를 “정석 배포”할 때 자주 쓰는 구조:

```text
브라우저
  ↓
Nginx (80/443 포트, reverse proxy)
  ↓
Gunicorn (127.0.0.1:8000 같은 내부 포트)
  ↓
Django 앱
```

### Nginx 설정 예시

```nginx
upstream django_server {
    server 127.0.0.1:8000;  # gunicorn이 떠 있는 내부 주소
}

server {
    listen 80;
    server_name quizai.juwonpark.me;

    location / {
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_pass http://django_server;
    }
}
```

여기서 **reverse proxy 핵심**은 이 한 줄이다.

```nginx
proxy_pass http://django_server;
```

* Nginx가 받은 요청을 `django_server`(= 127.0.0.1:8000)로 대신 보내는 라인
* 클라이언트 → Nginx → gunicorn/Django 흐름이 여기서 연결된다

`proxy_set_header` 들은 “원래 요청 정보(Host, IP, 스킴)”를 Django 쪽에 넘겨주기 위한 헤더들이다.
Django 설정의 `SECURE_PROXY_SSL_HEADER`, `USE_X_FORWARDED_HOST` 같은 옵션과 연결된다.

---

## 4. 왜 Reverse Proxy를 쓰는가? (장점 정리)

1. **보안 / 은닉**

   * 실제 앱 서버(gunicorn)는 `127.0.0.1:8000` 같은 내부 주소에서만 열어두고
     외부에는 Nginx(80/443)만 공개 → 직접 접근을 막을 수 있다.

2. **HTTPS(SSL/TLS) 처리**

   * HTTPS 암·복호화를 Nginx에서 처리하고
     뒤의 gunicorn <–> Django는 HTTP로만 통신해서 설정이 단순해진다.

3. **정적/미디어 파일 분리**

   * `/static/`, `/media/` 요청은 Nginx가 파일 시스템에서 바로 서빙
   * Django가 직접 파일을 서빙하는 것보다 훨씬 빠르고 효율적이다.

4. **여러 서비스 라우팅**

   * 한 도메인에서 경로에 따라 다른 서비스로 라우팅 가능

     * `/` → Django
     * `/blog` → Jekyll
   * “입구는 하나, 안에서는 여러 서비스” 구조를 만들 수 있다.

5. **로드밸런싱(확장용)**

   * 같은 Django 서버를 여러 대 띄우고, Nginx가 요청을 분산시킬 수 있다.

---

## 5. 오늘 내용 한 줄 요약

* **Reverse Proxy** =
  *“사용자 대신 앞에서 요청을 받아서, 뒤에 있는 백엔드 서버로 전달해 주는 서버(Nginx)”*
* **Django 배포에서의 구조** =
  *브라우저 → Nginx(reverse proxy) → gunicorn → Django*
* 주소/포트는 보통 `gunicorn: 127.0.0.1:8000`, Nginx가 여기를 `proxy_pass`로 물어준다.

```text
결론: 장고를 “진짜 배포용”으로 올릴 때,
runserver가 아니라 gunicorn + Nginx(reverse proxy)를 조합해서 쓰는 게 기본 패턴이다.
```

```
```
