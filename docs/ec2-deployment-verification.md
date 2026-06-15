# EC2 Deployment Verification

이 문서는 AWS EC2에 배포된 SafeVlog3 서비스가 정상 동작하는지 확인하는 절차를 정리한다. 배포 담당자나 리뷰어가 같은 기준으로 백엔드 API, 프론트엔드 정적 파일, 작업 목록, 삭제 라우트 반영 여부를 점검하는 것이 목적이다.

현재 확인 대상 예시는 다음 주소를 기준으로 한다.

```text
http://ec2-100-48-61-106.compute-1.amazonaws.com
```

## 확인 범위

- nginx가 프론트엔드 정적 파일을 서빙하는지 확인
- FastAPI `/health`가 정상 응답하는지 확인
- `/api/jobs` 작업 목록 API가 JSON으로 응답하는지 확인
- `DELETE /api/jobs/{job_id}` 라우트가 배포되어 있는지 확인
- 프론트엔드 번들에 작업 삭제 UI/API 호출이 포함됐는지 확인

## 수동 확인

### 1. 프론트엔드 응답

```powershell
Invoke-WebRequest -Uri "http://ec2-100-48-61-106.compute-1.amazonaws.com/" -UseBasicParsing
```

기대 결과:

- HTTP 200
- HTML 안에 `/assets/index-*.js`와 `/assets/index-*.css`가 포함됨

### 2. 백엔드 헬스체크

```powershell
Invoke-WebRequest -Uri "http://ec2-100-48-61-106.compute-1.amazonaws.com/health" -UseBasicParsing
```

기대 결과:

```json
{"status":"ok","sam3":"loaded","sam3_error":null}
```

`sam3` 값은 서버 환경에 따라 `loaded`가 아닐 수 있지만, API 자체는 HTTP 200으로 응답해야 한다.
