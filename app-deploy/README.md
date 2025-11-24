# ✅ **README.md**

```markdown
# 📦 KUmeong Store – K3s Deployment Package  
본 폴더(`app-deploy/`)는 **K3s 클러스터에서 KUmeong Store 애플리케이션을 배포하기 위한 완성된 배포 패키지**입니다.  
아래 두 가지 방식을 모두 지원합니다.

- **Helm Chart (정식 배포용)**
- **installation.yaml (단일 YAML — 빠른 테스트용)**

---

# 🚀 1. 배포 구성 요소

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
├── installation.yaml          # 단일 배포 파일 (프론트 + 백엔드 + MySQL)
└── README.md

````

---

# 🎯 2. 배포 방식 안내

## ✅ A. Helm Chart (정식 배포용)

프런트/백엔드/DB 설정을 모두 변수화하여  
**운영 환경에 맞춰 커스터마이징하기 좋은 구조**입니다.

### ✔ 1) Helm 설치 (K3s 서버에서 1번만)

```bash
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
````

### ✔ 2) values.yaml 수정

팀 환경에 맞게 필요 시 이미지 태그/포트 수정:

```yaml
backend:
  image:
    repository: gegujin/kumeong-api
    tag: "0.4.0"

frontend:
  image:
    repository: gegujin/kumeong-front
    tag: "0.4.0"
```

### ✔ 3) Helm Chart 설치

```bash
cd app-deploy/chart
helm install kumeong .
```

### ✔ 4) 업데이트(Upgrade)

```bash
helm upgrade kumeong .
```

### ✔ 5) 삭제

```bash
helm uninstall kumeong
```

---

# ⚡ 3. 단일 배포 파일 (installation.yaml)

Helm Chart 사용 없이 **K3s에 즉시 올릴 수 있는 통합 YAML 파일**입니다.

* MySQL StatefulSet
* MySQL Service
* Backend Deployment/Service
* Frontend Deployment/Service

모두 포함합니다.

### ✔ 적용

```bash
kubectl apply -f installation.yaml
```

### ✔ 삭제

```bash
kubectl delete -f installation.yaml
```

### ✔ 이 파일이 필요한 이유

* 네트워크/Ingress/NLB 테스트할 때 빠르게 전체 서비스 올리기 좋음
* Terraform/Ansible 인프라 테스트 시 API/FRONT를 즉시 띄워 검증 가능
* Helm Chart 사용 전에 기능 점검할 때 유용함

---

# 🔧 4. 이미지 태그 (고정)

현재 패키지에서 사용하는 Docker 이미지 버전:

| 구성       | 이미지                     | 버전      |
| -------- | ----------------------- | ------- |
| Backend  | `gegujin/kumeong-api`   | `0.4.0` |
| Frontend | `gegujin/kumeong-front` | `0.4.0` |
| MySQL    | `mysql`                 | `8`     |

---

# 👨‍💻 5. 역할 분담 (Team A – ACasia)

이 패키지의 작성자: **김서진**

**담당 업무**

* 백엔드/프런트 Dockerfile 구성 및 이미지 빌드
* Flutter Web API_ORIGIN 빌드 파이프라인 구성
* K3s용 Deployment/Service/Ingress 템플릿 작성
* Helm Chart(정식 배포) 구축
* installation.yaml(단일 배포 파일) 작성
* 로컬/클러스터 테스트 환경 구축

---

# 📌 6. 비고

* 설치 전 K3s에 MetalLB가 준비되어 있어야 외부 IP가 정상 할당됩니다.
* installation.yaml은 "테스트용"이며, 실제 운영/시연은 Helm Chart 사용을 권장합니다.
* backend는 K3s 내부 DNS `mysql:3306` 기준으로 통신하도록 구성되어 있습니다.

---

📎 7. K3s 배포 전 체크리스트 (필수)
1. Docker Hub 이미지 Pull 가능 여부 확인
   - gegujin/kumeong-api:0.4.0
   - gegujin/kumeong-front:0.4.0

2. MetalLB 설치 여부 및 LoadBalancer IP 풀 설정 완료 여부 확인

3. K3s 내 DNS 확인
   - backend Deployment에서 DB_HOST=mysql 정상 resolving 여부

4. storageclass(default) 존재 여부
   - mysql.persistence.enabled=true 시 필요

5. Flutter 프론트 웹 `API_ORIGIN` 환경 변수가 helm/values.yaml에서 반영되어 있는지

6. `kubectl get pods` 로 CrashLoopBackOff 없는지 확인

---

# ✔ 문의

필요한 부분은 김서진에게 문의하세요.
Helm Chart 개선 혹은 CI/CD 연동은 DevOps 팀원(김주령)과 협업 예정.