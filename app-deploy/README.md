# 📦 KUmeong Store – K3s Deployment Package

본 폴더(`app-deploy/`)는 **K3s 클러스터에서 KUmeong Store 애플리케이션을 배포하기 위한 최종 패키지**입니다.
팀원은 저장소를 `git clone` 한 뒤 해당 디렉터리에서 바로 배포를 진행할 수 있습니다.

---

# 🚀 1. 패키지 구성

```
app-deploy/
├── chart/                    # Helm Chart (백엔드 + 프론트 + MySQL)
│    ├── templates/
│    │    ├── backend-deployment.yaml
│    │    ├── backend-service.yaml
│    │    ├── backend-ingress.yaml
│    │    ├── frontend-deployment.yaml
│    │    ├── frontend-service.yaml
│    │    ├── frontend-ingress.yaml
│    │    ├── mysql-service.yaml
│    │    ├── mysql-statefulset.yaml
│    ├── values.yaml
│    └── Chart.yaml
├── installation.yaml         # 단일 배포 파일 (테스트용)
└── README.md
```

---

# 🎯 2. 배포 방식

KUmeong Store는 아래 두 가지 배포 방식을 지원합니다.

---

## ✅ A. Helm Chart (정식 배포용)

프런트/백엔드/DB 모든 설정을 변수화해
**운영 환경에 맞게 커스터마이징 가능한 공식 구조**입니다.

---

### ✔ 1) Helm 설치

K3s 서버에서 1번만 실행:

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
```

---

### ✔ 2) values.yaml 설정

`app-deploy/chart/values.yaml`에서 필요한 부분을 수정합니다.

> ❗ **중요 — 프런트에서는 API_ORIGIN 반드시 입력 필요**

```yaml
backend:
  image:
    repository: gegujin/kumeong-api
    tag: "0.4.0"

frontend:
  image:
    repository: gegujin/kumeong-front
    tag: "0.4.0"

  env:
    API_ORIGIN: "http://<BACKEND-LOADBALANCER-IP>:3000"
```

---

### ✔ 3) Helm 설치

```bash
cd app-deploy/chart
helm install kumeong .
```

---

### ✔ 4) Helm 업데이트

```bash
helm upgrade kumeong .
```

---

### ✔ 5) Helm 삭제

```bash
helm uninstall kumeong
```

---

# ⚡ 3. installation.yaml (단일 YAML)

Helm 없이 빠르게 테스트하기 위한 통합 파일입니다.

* MySQL StatefulSet
* MySQL Service
* Backend Deployment/Service
* Frontend Deployment/Service

모두 포함되어 있으며 **순서대로 apply할 필요 없음** —
쿠버네티스가 자동으로 의존성을 맞춰 배포합니다.

### ✔ 적용

```bash
kubectl apply -f installation.yaml
```

### ✔ 삭제

```bash
kubectl delete -f installation.yaml
```

---

# 🔍 4. 배포 후 리소스 확인 명령어

팀원들이 가장 많이 묻는 “배포 후 확인” 명령어를 모았습니다.

```bash
# 모든 리소스 확인
kubectl get all

# Frontend LoadBalancer 외부 IP 확인
kubectl get svc kumeong-front

# Backend Pod 상태 확인
kubectl get pods -l app=kumeong-api

# 백엔드 로그 보기
kubectl logs -f deployment/kumeong-api

# MySQL Pod 로그 확인
kubectl logs -f statefulset/mysql
```

---

# 🔧 5. 이미지 태그 (고정 버전)

| 구성       | 이미지                     | 버전      |
| -------- | ----------------------- | ------- |
| Backend  | `gegujin/kumeong-api`   | `0.4.0` |
| Frontend | `gegujin/kumeong-front` | `0.4.0` |
| MySQL    | `mysql`                 | `8`     |

---

# 👨‍💻 6. 담당자 및 역할

**작성자: 김서진**

**담당 업무**

* 백엔드/프런트 Dockerfile 구성
* Docker 이미지 빌드 및 테스트
* Flutter Web 빌드(특히 API_ORIGIN) 적용
* Deployment/Service/Ingress 구조 작성
* Helm Chart 구축
* installation.yaml 제작
* 로컬/K3s 테스트 진행

DevOps 팀원(김주령)과 CI/CD 및 모니터링 스택 연동 예정.

---

# 📌 7. K3s 배포 전 체크리스트

| 항목                                        | 체크 |
| ----------------------------------------- | -- |
| Docker Hub 이미지 Pull 가능?                   | ☐  |
| MetalLB 설치 및 IP 풀 설정?                     | ☐  |
| K3s DNS에서 `mysql` resolving 정상?           | ☐  |
| storageClass 존재 여부 확인?                    | ☐  |
| 프론트의 `API_ORIGIN` 설정됨?                    | ☐  |
| CrashLoopBackOff 없음? (`kubectl get pods`) | ☐  |

---

# 📁 8. 배포 예시

```bash
cd ~/KUmeong_store/app-deploy

# Helm 설치 후
cd chart
helm install kumeong .
```

---

필요한 부분은 **김서진**에게 문의해주세요.
Helm 개선 및 CI/CD 자동화는 DevOps 팀원과 협업하여 진행합니다.

---