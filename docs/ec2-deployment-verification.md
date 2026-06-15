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

### 3. 작업 목록 API

```powershell
Invoke-WebRequest -Uri "http://ec2-100-48-61-106.compute-1.amazonaws.com/api/jobs" -UseBasicParsing
```

기대 결과:

- HTTP 200
- JSON 배열 응답
- 기존 작업이 있다면 `job_id`, `status`, `scene_type`, `face_count`, `pii_count` 필드 확인 가능

작업 목록이 서버 재시작 이후에도 유지된다면 DB 기반 저장소가 동작하고 있다는 강한 신호다.

### 4. 작업 삭제 라우트 확인

실제 사용자 작업을 삭제하지 않도록, 존재하지 않는 임의 ID로만 확인한다.

```powershell
Invoke-WebRequest `
  -Uri "http://ec2-100-48-61-106.compute-1.amazonaws.com/api/jobs/deployment-route-check" `
  -Method Delete `
  -UseBasicParsing
```

기대 결과:

- HTTP 204 또는 404: 삭제 라우트가 배포되어 있음
- HTTP 405: 삭제 라우트가 아직 배포되지 않았거나 백엔드가 이전 버전임

현재 구현에서는 존재하지 않는 작업 ID에 대해 내부 store 생성 흐름을 거친 뒤 204가 반환될 수 있다. 이 확인은 라우트 존재 여부만 보기 위한 smoke check이며 실제 작업 ID에는 사용하지 않는다.

### 5. 프론트엔드 삭제 UI 반영 확인

프론트엔드 index HTML에서 JS 번들 경로를 확인한다.

```powershell
$html = (Invoke-WebRequest -Uri "http://ec2-100-48-61-106.compute-1.amazonaws.com/" -UseBasicParsing).Content
$asset = [regex]::Match($html, 'src="([^"]*index-[^"]*\.js)"').Groups[1].Value
$bundle = (Invoke-WebRequest -Uri "http://ec2-100-48-61-106.compute-1.amazonaws.com$asset" -UseBasicParsing).Content
$bundle.Contains('delete(`/api/jobs/')
```

`True`이면 작업 삭제 API 호출이 프론트엔드 번들에 포함된 것이다. `False`이면 백엔드는 최신이어도 프론트엔드가 이전 빌드일 수 있으므로 `npm run build` 후 nginx 정적 파일 경로에 다시 배포해야 한다.
