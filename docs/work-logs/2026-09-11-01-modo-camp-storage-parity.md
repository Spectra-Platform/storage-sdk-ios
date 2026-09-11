# 2026-09-11 — Modo Camp Storage parity draft

## 작업 목적과 이해한 내용

Modo Camp iOS가 React 웹 Storage SDK와 같은 파일 중심 API를 사용할 수 있도록
Swift public API 목표, 경로 규칙, visibility와 diagnostics 경계를 문서화했다.

## 문제 진단 또는 기존 동작

기존 `storage-sdk-ios`는 user-root API와 데이터 업로드 convenience를 구현했지만
JS SDK의 `listFiles`, `uploadFile`, `uploadImage`, `getDownloadUrl`,
`downloadData/downloadFile`, `deleteFile` 같은 앱-facing 이름과
progress/cancel public contract는 아직 고정되지 않았다.

## 적용한 내용과 주요 변경 파일

- `docs/guides/modo-camp-ios-storage-parity.md`
  - Swift Storage API 초안, Modo path guide, `public_read` visibility, checksum,
    progress/cancel 구현 방향, redaction 규칙과 JS parity checklist를 추가했다.
- `README.md`, `HANDOFF.md`, `WORKLOG.md`
  - Modo Camp parity guide와 미구현 경계를 연결했다.

## 실행한 검증과 결과

- 문서 변경만 수행했다. Swift code와 Package manifest는 변경하지 않았다.
- `git diff --check`로 whitespace 검증이 필요하다.

## 남은 작업, 미검증 항목 또는 주의사항

- JS-parity alias와 upload input 타입을 코드로 추가해야 한다.
- byte-level progress/cancel은 URLSession upload transport 설계가 필요하다.
- 실제 `storage.spectra.kr` upload/download/delete live smoke는 수행하지 않았다.
