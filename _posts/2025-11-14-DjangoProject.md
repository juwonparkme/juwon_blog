---
layout: post
read_time: true
show_date: true
title: "Django 기반 AI 퀴즈 생성 플랫폼 프로젝트 구조 분석"
date: 2025-11-11 23:59:00 +0900
description: Django 5.1.6 기반의 AI 퀴즈 생성 플랫폼(Quizly) 프로젝트의 디렉터리 구조와 각 파일/폴더의 역할을 상세히 분석한 글입니다.
img: posts/20251114/Django.png
tags: [Django, Python, 프로젝트구조, AI, 웹개발]
author: Juwon
github: JuWunpark/juwon_blog
---



# Quizly 프로젝트 구조 분석

## 1. 프로젝트 개요

**Quizly**는 OpenAI API를 활용하여 사용자가 업로드한 학습 자료(PDF, DOCX, PPTX)를 분석하고, 자동으로 다양한 유형의 퀴즈 문제를 생성하는 AI 기반 학습 플랫폼입니다.

### 사용 기술 스택

- **Backend Framework**: Django 5.1.6
- **Programming Language**: Python 3.12
- **Database**: MySQL 8.0
- **AI Service**: OpenAI API (GPT 모델)
- **Authentication**: django-allauth (소셜 로그인: Google, Kakao, Naver)
- **File Processing**: 
  - PyMuPDF (PDF 처리)
  - python-docx (DOCX 처리)
  - python-pptx (PPTX 처리)
- **Frontend**: HTML5, CSS3, JavaScript (Vanilla)
- **Deployment**: Nginx, Cloudflare CDN
- **Environment Management**: python-dotenv

---

## 2. 디렉터리 구조 (Tree 형식 요약)

```
Quiz_AI/
├── testpro/                          # Django 프로젝트 루트
│   ├── accounts/                     # 사용자 인증 및 계정 관리 앱
│   │   ├── migrations/               # 데이터베이스 마이그레이션 파일
│   │   ├── static/                   # 앱별 정적 파일 (CSS, 이미지)
│   │   ├── templates/               # 인증 관련 템플릿
│   │   ├── models.py                # 커스텀 User 모델
│   │   ├── views.py                 # 인증 뷰 로직
│   │   ├── forms.py                 # 회원가입 폼
│   │   └── urls.py                  # URL 라우팅
│   │
│   ├── quiz_app/                     # 메인 퀴즈 생성 앱
│   │   ├── migrations/               # 데이터베이스 마이그레이션 파일
│   │   ├── sep_views/                # 분리된 뷰 모듈
│   │   │   ├── upload_view.py       # 파일 업로드 처리
│   │   │   ├── extract_files.py     # 파일 내용 추출
│   │   │   ├── prompt_builder.py    # AI 프롬프트 생성
│   │   │   ├── quiz_parser.py       # 퀴즈 응답 파싱
│   │   │   ├── quiz_view.py         # 퀴즈 생성 뷰
│   │   │   └── dboperations.py      # 데이터베이스 작업
│   │   ├── static/                   # 앱별 정적 파일
│   │   ├── templates/                # 퀴즈 관련 템플릿
│   │   ├── uploads/                  # 업로드된 학습 자료
│   │   ├── models.py                 # 퀴즈 데이터 모델
│   │   ├── views.py                  # 메인 뷰 로직
│   │   ├── forms.py                  # 파일 업로드 폼
│   │   └── urls.py                   # URL 라우팅
│   │
│   ├── community/                     # 커뮤니티 앱
│   │   ├── migrations/                # 데이터베이스 마이그레이션 파일
│   │   ├── static/                    # 앱별 정적 파일
│   │   ├── templates/                 # 커뮤니티 템플릿
│   │   ├── templatetags/              # 커스텀 템플릿 태그
│   │   ├── models.py                  # 게시글/댓글 모델
│   │   ├── views.py                   # 커뮤니티 뷰 로직
│   │   ├── forms.py                   # 게시글 작성 폼
│   │   └── urls.py                    # URL 라우팅
│   │
│   ├── history/                       # 학습 히스토리 앱
│   │   ├── migrations/                # 데이터베이스 마이그레이션 파일
│   │   ├── static/                    # 앱별 정적 파일
│   │   ├── templates/                 # 히스토리 템플릿
│   │   ├── models.py                  # 히스토리 모델
│   │   ├── views.py                   # 히스토리 뷰 로직
│   │   └── urls.py                    # URL 라우팅
│   │
│   ├── mysite/                        # Django 프로젝트 설정
│   │   ├── settings.py                # 프로젝트 설정 파일
│   │   ├── urls.py                    # 루트 URL 설정
│   │   ├── wsgi.py                    # WSGI 설정
│   │   └── asgi.py                    # ASGI 설정
│   │
│   ├── static/                        # 개발용 정적 파일 디렉터리
│   ├── staticfiles/                   # collectstatic으로 수집된 정적 파일
│   ├── media/                         # 업로드된 미디어 파일 (프로필 이미지 등)
│   ├── uploads/                       # 업로드된 학습 자료 (PDF, PPTX 등)
│   ├── templates/                     # 전역 템플릿 디렉터리
│   ├── manage.py                      # Django 관리 스크립트
│   ├── requirements.txt               # Python 패키지 의존성 목록
│   ├── README.md                      # 프로젝트 문서
│   ├── CACHE_CLEAR_GUIDE.md           # 캐시 클리어 가이드
│   └── FIREWALL_CHECK.md              # 방화벽 체크 가이드
│
└── requirements.txt                    # 루트 레벨 requirements.txt
```

---

## 3. 디렉터리/파일별 역할 설명

### 3.1 프로젝트 루트 (`testpro/`)

Django 프로젝트의 메인 디렉터리입니다. 모든 앱과 설정 파일이 이 디렉터리 하위에 위치합니다.

#### 주요 파일

- **`manage.py`**: Django 프로젝트 관리를 위한 명령줄 유틸리티입니다. 마이그레이션, 서버 실행, 슈퍼유저 생성 등의 작업을 수행합니다.
- **`requirements.txt`**: 프로젝트에 필요한 Python 패키지 목록입니다. 주요 패키지로는 Django 5.1.6, django-allauth, OpenAI, PyMuPDF 등이 포함됩니다.

### 3.2 Django 프로젝트 설정 (`mysite/`)

Django 프로젝트의 핵심 설정을 담당하는 디렉터리입니다.

#### `settings.py`
- **데이터베이스 설정**: MySQL 연결 정보 (환경 변수에서 로드)
- **인증 설정**: django-allauth를 통한 소셜 로그인 설정 (Google, Kakao, Naver)
- **정적 파일 설정**: `STATIC_URL`, `STATIC_ROOT`, `MEDIA_URL`, `MEDIA_ROOT`
- **앱 등록**: `INSTALLED_APPS`에 accounts, quiz_app, community, history 등 커스텀 앱 등록
- **커스텀 User 모델**: `AUTH_USER_MODEL = "accounts.User"`
- **이메일 설정**: SMTP를 통한 이메일 인증 설정

#### `urls.py`
루트 URL 설정 파일로, 각 앱의 URL을 포함(include)하여 라우팅합니다:
```python
urlpatterns = [
    path("admin/", admin.site.urls),
    path('', include('quiz_app.urls')),
    path('accounts/', include('accounts.urls')),
    path('accounts/', include('allauth.urls')),
    path('history/', include('history.urls')),
    path('community/', include('community.urls')),
]
```

### 3.3 사용자 인증 앱 (`accounts/`)

사용자 계정 관리 및 인증을 담당하는 앱입니다.

#### `models.py`
- **커스텀 User 모델**: Django의 `AbstractUser`를 상속받아 확장한 사용자 모델
  - 추가 필드: `age`, `phone_number`, `profile_image`, `status` (대학생/중고등학생/기타)

#### `forms.py`
- **CustomSignupForm**: django-allauth의 회원가입 폼을 커스터마이징한 폼

#### `views.py`
- 사용자 인증 관련 뷰 로직 (로그인, 로그아웃, 프로필 관리 등)

#### `templates/`
- 인증 관련 HTML 템플릿 (로그인, 회원가입, 프로필 페이지 등)

### 3.4 퀴즈 생성 앱 (`quiz_app/`)

프로젝트의 핵심 기능인 AI 기반 퀴즈 생성을 담당하는 앱입니다.

#### `models.py`
- **User_Quiz_Data 모델**: 생성된 퀴즈 데이터를 저장하는 모델
  - `user`: ForeignKey로 사용자와 연결
  - `file_name`: 업로드된 파일 이름
  - `quiz_data`: JSONField로 퀴즈 데이터 저장
  - `question_type`: 문제 유형 (MCQ/객관식, OX/OX, Short/단답형)
  - `score`: 사용자의 최종 점수
  - `explanation`: JSONField로 해설 데이터 저장
  - `created_at`: 생성 시간

#### `sep_views/` (분리된 뷰 모듈)
코드의 가독성과 유지보수성을 높이기 위해 뷰 로직을 모듈별로 분리했습니다:

- **`upload_view.py`**: 파일 업로드 처리 로직
- **`extract_files.py`**: 업로드된 파일(PDF, DOCX, PPTX)에서 텍스트 추출
- **`prompt_builder.py`**: OpenAI API에 전송할 프롬프트 생성
- **`quiz_parser.py`**: OpenAI API 응답을 파싱하여 퀴즈 데이터로 변환
- **`quiz_view.py`**: 퀴즈 생성 및 표시 뷰
- **`dboperations.py`**: 데이터베이스 CRUD 작업

#### `views.py`
메인 뷰 로직으로, `sep_views/`의 모듈들을 조합하여 사용합니다.

#### `forms.py`
파일 업로드를 위한 폼 정의 (PDF, DOCX, PPTX 파일 지원)

#### `uploads/`
사용자가 업로드한 학습 자료 파일들이 저장되는 디렉터리입니다.

### 3.5 커뮤니티 앱 (`community/`)

사용자 간 학습 자료 및 문제 공유를 위한 커뮤니티 기능을 제공하는 앱입니다.

#### `models.py`
- 게시글(Post) 및 댓글(Comment) 모델 정의

#### `views.py`
- 게시글 작성, 수정, 삭제, 조회 뷰
- 댓글 작성, 삭제 뷰

#### `templatetags/`
- 커스텀 템플릿 태그 정의 (예: 날짜 포맷팅, 사용자 정보 표시 등)

### 3.6 학습 히스토리 앱 (`history/`)

사용자가 생성한 퀴즈 문제 목록과 풀이 기록을 관리하는 앱입니다.

#### `models.py`
- 학습 히스토리 관련 모델 정의

#### `views.py`
- 생성한 퀴즈 목록 조회 뷰
- 문제 유형별, 과목별 필터링 기능

### 3.7 정적 파일 및 미디어

#### `static/`
개발 중 사용하는 정적 파일(CSS, JavaScript, 이미지 등)이 저장되는 디렉터리입니다. Django의 `STATICFILES_DIRS` 설정에 포함됩니다.

#### `staticfiles/`
`python manage.py collectstatic` 명령으로 수집된 정적 파일들이 저장되는 디렉터리입니다. 프로덕션 환경에서 Nginx가 이 디렉터리를 서빙합니다.

#### `media/`
사용자가 업로드한 미디어 파일(프로필 이미지 등)이 저장되는 디렉터리입니다. `MEDIA_ROOT` 설정에 지정됩니다.

---

## 4. 프로젝트 셋업 및 실행 방법

### 4.1 필수 요구사항

- Python 3.12 이상
- MySQL 8.0 이상
- OpenAI API 키
- (선택) 소셜 로그인을 위한 OAuth 앱 설정 (Google, Kakao, Naver)

### 4.2 설치 단계

#### 1) 저장소 클론 및 디렉터리 이동
```bash
cd /home/ubuntu/Q_park_final/Quiz_AI/testpro
```

#### 2) 가상환경 생성 및 활성화
```bash
python3 -m venv .venv
source .venv/bin/activate  # Linux/Mac
```

#### 3) 의존성 설치
```bash
pip install -r requirements.txt
```

#### 4) 환경 변수 설정
프로젝트 루트(`testpro/`)에 `.env` 파일을 생성하고 다음 변수들을 설정합니다:

```env
# 데이터베이스 설정
DATABASE_NAME=quizly_db
DATABASE_USER=your_db_user
DATABASE_PASSWORD=your_db_password
DATABASE_HOST=localhost
DATABASE_PORT=3306

# OpenAI API
OPENAI_API_KEY=sk-your-openai-api-key

# 소셜 로그인 - Google
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_SECRET=your-google-secret

# 소셜 로그인 - Kakao
KAKAO_CLIENT_ID=your-kakao-client-id

# 소셜 로그인 - Naver
NAVER_CLIENT_ID=your-naver-client-id
NAVER_SECRET=your-naver-secret

# 이메일 설정 (SMTP)
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
DEFAULT_FROM_EMAIL=Quizly <your-email@gmail.com>
```

#### 5) 데이터베이스 설정
```bash
# MySQL 데이터베이스 생성
mysql -u root -p
CREATE DATABASE quizly_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'your_db_user'@'localhost' IDENTIFIED BY 'your_db_password';
GRANT ALL PRIVILEGES ON quizly_db.* TO 'your_db_user'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

#### 6) 마이그레이션 실행
```bash
python manage.py makemigrations
python manage.py migrate
```

#### 7) 슈퍼유저 생성
```bash
python manage.py createsuperuser
```

#### 8) 정적 파일 수집
```bash
python manage.py collectstatic
```

### 4.3 개발 서버 실행

```bash
python manage.py runserver
```

브라우저에서 `http://localhost:8000`으로 접속하여 애플리케이션을 확인할 수 있습니다.

### 4.4 프로덕션 배포

프로덕션 환경에서는 다음과 같이 설정합니다:

1. **settings.py 수정**: `DEBUG = False`로 변경
2. **Nginx 설정**: 정적 파일 서빙 및 리버스 프록시 설정
3. **Gunicorn 실행**: WSGI 서버로 Django 애플리케이션 실행
4. **Cloudflare 설정**: CDN 및 SSL 인증서 설정

자세한 배포 가이드는 `README.md` 파일을 참조하세요.

---

## 5. 마무리 코멘트

이 프로젝트는 Django의 모듈화된 구조를 잘 활용하여 각 기능을 독립적인 앱으로 분리했습니다. 특히 `quiz_app/sep_views/` 디렉터리를 통해 뷰 로직을 기능별로 모듈화하여 코드의 가독성과 유지보수성을 높였습니다.

주요 특징:
- **모듈화된 구조**: 각 앱이 독립적으로 동작하며, 명확한 책임 분리
- **확장 가능한 설계**: 새로운 문제 유형이나 기능 추가가 용이한 구조
- **보안 고려**: 환경 변수를 통한 민감 정보 관리, django-allauth를 통한 안전한 인증
- **사용자 경험**: 소셜 로그인 지원, 다양한 파일 형식 지원, 커뮤니티 기능

이 구조는 Django의 Best Practice를 따르며, 향후 기능 확장이나 유지보수에 유리한 구조로 설계되었습니다.
