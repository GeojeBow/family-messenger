# 우리끼리

가족만 쓰는 폐쇄형 메신저 (Android, Flutter + Supabase).

- **고정 가족 계정**: 가입 기능이 없습니다. 관리자가 SQL로 만든 계정(기본 4개)으로만 로그인할 수 있고, 가족끼리는 모두 서로 대화할 수 있습니다. 가족이 아닌 계정은 아무것도 볼 수 없습니다.
- **종단간 암호화**: 메시지마다 새 키로 XChaCha20-Poly1305 암호화, 키는 X25519로 받는 사람·보낸 사람에게만 감싸 전달, Ed25519 서명으로 위조 방지. 서버에는 암호문만 저장됩니다.
- **보안 번호**: 만나서 숫자를 비교하면 중간자 공격이 없음을 확인할 수 있고, 상대 키가 바뀌면 경고합니다.
- **기기 보호**: 백업 제외. 개인 키는 Android Keystore에만 저장됩니다.

## 서버 설정 (한 번만)

1. Supabase 대시보드 → SQL Editor에서 `supabase/schema.sql` 전체를 실행합니다. (다시 실행하면 모든 메시지가 지워집니다.)
2. Authentication → Users → **Add user → Create new user**로 계정을 만듭니다.
   이메일은 `harry@users.urikkiri.app`, `family2@users.urikkiri.app`, `family3@…`, `family4@…` 형식이고, **Auto Confirm User**를 켭니다.
   이 네 아이디만 가족으로 등록되며, 다른 아이디는 만들어져도 아무것도 볼 수 없습니다.
3. Authentication → Sign In / Providers에서 **Allow new users to sign up**을 끕니다.

## 빌드와 배포

`main`에 push하면 GitHub Actions가 APK를 만들고, `v*` 태그를 push하면 Release에 APK를 올립니다.
가족용 고정 다운로드 링크: https://github.com/GeojeBow/family-messenger/releases/latest/download/urikkiri.apk

릴리스 서명 키는 저장소에 **암호화된 형태**(`android/app/upload-keystore.jks.enc`)로만 들어 있고,
암호는 저장소 Secret `KEYSTORE_PASSWORD`입니다. Secret을 처음 넣은 뒤 `main` 빌드가 키를 만들어 커밋합니다.
이 암호를 잃어버리면 기존 앱 위에 업데이트를 설치할 수 없으니 안전한 곳에 보관하세요.

## 한계

- 개인 키는 휴대폰에만 있어서, 앱을 지우거나 휴대폰을 바꾸면 이전 메시지는 그 기기에서 열 수 없습니다.
- 현재 1:1 대화만 지원하며, 앱이 꺼져 있을 때 푸시 알림은 아직 없습니다.
- 메시지별 임시 키를 쓰지만 Signal의 Double Ratchet처럼 완전한 전방 비밀성(forward secrecy)을 제공하지는 않습니다. 기기의 개인 키가 유출되면 서버에 남은 과거 메시지가 해독될 수 있습니다.
