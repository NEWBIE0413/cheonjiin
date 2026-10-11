# 천지in — Codex 브랜딩

## 최종 파일

| 파일 | 규격 | 역할 |
| --- | --- | --- |
| `icon-1024.png` | 1024×1024 RGB PNG | ㅣ·ㆍ·ㅡ를 비대칭 정사각 구도로 묶은 심벌 |
| `screenshots/01.png` | 1290×2796 RGB PNG | “매일 쓰니까, 가볍고 단정하게.” — 브랜드와 실제 한글 배열 |
| `screenshots/02.png` | 1290×2796 RGB PNG | “없는 게 마음에 들어요.” — 광고·추적·구독 없음 |
| `screenshots/03.png` | 1290×2796 RGB PNG | “숫자도 기호도, 흐름은 그대로.” — 기호 1/2·2/2 두 페이지 |
| `screenshots/04.png` | 1290×2796 RGB PNG | “안까지 투명한 천지인 키보드.” — MIT 및 GitHub 저장소 |

`contact-sheet.png`는 검토용 모아보기다. 업로드 대상은 위 다섯 PNG만이다.
`icon-source.png`는 이미지 생성 원본이며 재생성 스크립트의 입력이다.
`build.py`는 조판/내보내기/검증 스크립트, `audit.json`은 텍스트 영역과 키보드 위치·해시 기록이다.

## 디자인 의도

초안의 크림과 먹색은 유지하되, 가로로 흩어진 세 획을 하나의 응축된 표식으로 바꿨다.
작은 크기에서도 읽히도록 세로획과 가로획을 두껍게 잡고, 점만 코랄로 남겼다.
스크린샷에는 Pretendard, 일정한 좌측 정렬, 얇은 구분선, 여유 있는 행간을 사용했다.
첫 장의 비어 있던 중앙에는 심벌을 넣었고, 각 장의 정보량과 목적을 다르게 구성했다.
둘째 장의 먹색은 마케팅 배경일 뿐, 앱의 다크 키보드 기능을 표현하지 않는다.
기기 목업이나 Slyder의 설정 UI를 복제하지 않았다. 입력란은 입력 예시를 위한 조판 요소다.

## 직접 확인한 스타일 레퍼런스

공식 사이트의 제품 이미지와 설명을 확인했다. 이 목록은 앱스토어 스크린샷의 객관적인 순위가 아니라 디자인 참고 출처다.
아래의 ‘적용’은 원본 UI를 복제한 것이 아니라, 이번 결과에 해석해 적용한 원칙이다.

- **Things / Cultured Code**: 제품 화면을 크게 드러내는 정돈된 정보 위계. 적용: 헤드라인 → 짧은 설명 → 실제 키보드의 순서와 공통 정렬선.
  출처: `https://culturedcode.com/things/`
  확인 이미지: `https://culturedcode.com/things/2024-01-20/images/whatsnew-collage-io60.png`
- **Bear**: 조용한 중성 바탕, 가독성 높은 문서 같은 화면, 제한된 강조색. 적용: 크림색 바탕과 단정한 한글 조판, 코랄을 심벌의 점에만 사용.
  출처: `https://bear.app/`
  확인 이미지: `https://bear.app/images/home/hero_iphone.jpg`
- **Halide**: 어두운 여백 위에서 제품을 선명하게 제시하는 대비. 적용: 둘째 장의 먹색 바탕과 밝은 실제 키보드. 사진·렌즈 효과·브랜드 색은 가져오지 않았다.
  출처: `https://halide.cam/`
  확인 이미지: `https://halide.cam/static/media/ui_portrait.jpg`

## 재생성

Python 3, Pillow, fontTools 및 `~/Library/Fonts/Pretendard-*.otf`가 필요하다.

```sh
cd ~/cld/cheonjiin/branding/codex
python3 build.py
python3 build.py verify-specs
python3 build.py verify-type
python3 build.py verify-keyboards
```

스크립트는 `../../tools/branding.py`를 읽기 전용으로 import하고 `keyboard()`만 재사용한다.
원본의 `main()`은 실행하지 않으며, `App/Assets.xcassets`에는 쓰지 않는다.
원본 렌더러가 바뀌면 키보드 검증이 실패하므로, 다시 빌드한 후 결과를 확인한다.

## 검증 결과

- 아이콘 1024×1024, 스크린샷 네 장 1290×2796 확인.
- 다섯 장 모두 RGB PNG, 알파/투명색 메타데이터 없음, sRGB ICC 프로필 포함.
- 제목·설명·키 라벨에 사용한 Pretendard 글리프가 모두 존재함을 cmap으로 확인.
- 44개 조판 텍스트 영역이 캔버스 안에 있고 가격 표현이 없음을 확인.
- 한글 키보드 세 개, 기호 키보드 두 개를 원본 `keyboard()` 출력과 비교하여 픽셀 차이 0 확인.
- 최종 아이콘 및 스크린샷 네 장을 각각 직접 열어 한글, 받침, 자모, 기호, 잘림 여부를 육안 확인.
- 오른쪽 열 ⌫ / .,?! / 두 줄 높이 ↵, 아래 줄 123 / 한/A / ㅇㅁ / 간격 아이콘 유지.
- 원래 초안과 앱 코드·에셋은 수정하지 않았다. 이 작업의 결과/원장은 모두 `branding/codex/` 내부에 있다.

현재 Apple 공식 규격에서도 1290×2796은 허용되는 세로 해상도로 확인했다.
공식 페이지는 현재 해당 그룹을 “iPhone with Dynamic Island (large display)”로 표기한다.
이 작업은 요청받은 크기의 제작·로컬 검증이며, App Store Connect 업로드나 심사 승인을 수행한 것은 아니다.
규격 출처: `https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/`

미감의 최종 선택은 사용자의 판단으로 남는다. 기술적인 검증과 미감의 우열을 혼동하지 않는다.
