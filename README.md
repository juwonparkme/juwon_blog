# Jekyll Blog – GitHub Actions 자동 배포

**main 브랜치에 푸시하면 자동으로 서버에 배포**되어 `https://blog.juwonpark.me` 에 반영됩니다.  
배포는 **서버에서 rbenv + bundler로 빌드** 후, 결과물(`_site/`)을 **Nginx 문서 루트**로 동기화합니다.

---

## 아키텍처 개요
```

개발자 → git push (main)
↓
GitHub Actions (Deploy workflow)
↓ (SSH)
Ubuntu 서버 /home/ubuntu/myblog (git reset --hard origin/main)
↓ (bundle install → jekyll build)
_site/ → rsync → /var/www/myblog
↓
Nginx (80/443) 서빙 → [https://blog.juwonpark.me](https://blog.juwonpark.me)

````

---

## 서버 & 경로 (확정값)
- 리포 경로: **/home/ubuntu/myblog**
- 배포 경로(Nginx 문서 루트): **/var/www/myblog**
- Ruby: **rbenv 3.3.4** (레포에 `.ruby-version` = `3.3.4` 권장)
- 도메인: **https://blog.juwonpark.me** (Nginx + Let's Encrypt/Cloudflare)

---

## 선행 준비

### 서버(1회만)
```bash
# rbenv 초기화 (비대화식에서도 PATH 잡히도록)
export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init - bash)"

# ruby 설치(없으면)
rbenv versions
ruby -v || rbenv install -s 3.3.4
rbenv global 3.3.4
gem install bundler jekyll --no-document

# 배포 디렉토리 준비 (nginx 문서 루트)
sudo mkdir -p /var/www/myblog
sudo chown -R ubuntu:ubuntu /var/www/myblog
````

### 방화벽(권장)

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw deny 4000/tcp
sudo ufw deny 8000/tcp
sudo ufw deny 3306/tcp
sudo ufw deny 25/tcp
sudo ufw status numbered
```

---

## GitHub Secrets 설정

리포지토리 → **Settings → Secrets and variables → Actions**

* `SERVER_HOST` = `blog.juwonpark.me` (또는 서버 공인 IP)
* `SERVER_USER` = `ubuntu`
* `SERVER_PORT` = `22`
* `SERVER_SSH_KEY` = **배포용 개인키 전체** (BEGIN/END 줄 포함)

> 서버의 `~/.ssh/authorized_keys`에는 위 개인키의 **공개키 짝**이 **한 줄**로 있어야 합니다.

---

## 워크플로 요약

`.github/workflows/deploy.yml` 핵심 단계:

1. Setup SSH (키 저장, known_hosts 등록)
2. Validate inputs (Secrets 확인)
3. 원격 배포

   * rbenv 초기화 + Ruby 3.3.4 사용
   * `git fetch && git reset --hard origin/main && git clean -fd`
   * `bundle install` → `bundle exec jekyll build`
   * `_site/` → `/var/www/myblog/` rsync

> 전체 파일은 리포의 `.github/workflows/deploy.yml` 참고.

---

## 수동 배포(점검용)

```bash
export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init - bash)"
rbenv shell 3.3.4
gem install bundler --no-document || true

cd ~/myblog
git fetch origin && git reset --hard origin/main && git clean -fd
bundle install
bundle exec jekyll build -s . -d _site
rsync -az --delete _site/ /var/www/myblog/
sudo systemctl reload nginx
```

---

## rbenv 초기화 안내 (비대화식 세션)

워크플로엔 포함되어 있으나, 서버에서 수동 작업 시 먼저 실행:

```bash
export RBENV_ROOT="$HOME/.rbenv"
export PATH="$RBENV_ROOT/bin:$PATH"
eval "$(rbenv init - bash)"
hash -r
```

영구 적용(선택): `~/.bashrc`에 동일 내용 추가 후 `exec -l $SHELL`

---

## 동작 확인

* **Actions 로그**
  `[deploy] sync to origin/main` → `[deploy] bundle install` → `[deploy] jekyll build` → `[deploy] rsync to web root` → `[deploy] done`
* **헤더 확인**

```bash
curl -I https://blog.juwonpark.me | sed -n '1p;/last-modified/Ip'
```

---

## 트러블슈팅

| 증상                                        | 원인                       | 해결                                                           |
| ----------------------------------------- | ------------------------ | ------------------------------------------------------------ |
| `Bad port ''`                             | `SERVER_PORT` 비어 있음      | Secret에 `22` 저장 또는 기본값 폴백                                    |
| `option requires an argument -- o`        | `SERVER_HOST/USER` 비어 있음 | Secrets 채우기 + Validate 스텝 확인                                 |
| `bundle: command not found`               | 비대화식에서 rbenv 미초기화        | `export RBENV_ROOT` + `eval "$(rbenv init - bash)"`          |
| `rbenv: version 'x.y.z' not installed`    | 버전 불일치                   | `.ruby-version=3.3.4` 또는 스크립트에서 3.3.4 지정                     |
| `Your local changes would be overwritten` | 서버 로컬 수정 잔존              | `git fetch && git reset --hard origin/main && git clean -fd` |
| Permission denied(배포 경로)                  | `/var/www/myblog` 권한 문제  | `sudo chown -R ubuntu:ubuntu /var/www/myblog` (1회)           |

---

## 보안 체크리스트

* UFW: `22,80,443`만 공개, `8000/3306/4000/25` 차단
* 워크플로: `StrictHostKeyChecking=yes` + `ssh-keyscan`
* 배포 경로는 `ubuntu` 소유로 유지
