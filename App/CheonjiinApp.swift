import SwiftUI

@main
struct CheonjiinApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var sample = ""
    @FocusState private var focused: Bool
    @Environment(\.openURL) private var openURL

    private static let repository = URL(string: "https://github.com/oesoll/cheonjiin")!

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("설정 열기") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                } header: {
                    Text("켜기")
                } footer: {
                    Text("설정 › 천지in › 키보드에서 '천지in'을 켜세요. '전체 접근 허용'은 진동에만 쓰이고, 꺼도 모든 입력이 동작합니다.")
                }

                Section("써 보기") {
                    TextField("여기를 눌러 지구본 키로 천지in을 고르세요", text: $sample, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                }

                Section("입력 방법") {
                    tip("모음", "ㅣ ㆍ ㅡ 세 획을 이어 누릅니다. ㅣㆍ = ㅏ, ㆍㅣ = ㅓ, ㆍㅡ = ㅗ, ㅡㆍ = ㅜ")
                    tip("자음", "같은 키를 이어 누르면 ㄱ → ㅋ → ㄲ. 같은 자음을 따로 쓰려면 사이에 간격 키를 누릅니다(안녕: ㄴ, 간격, ㄴ).")
                    tip("간격", "조합 중(→ 표시)이면 조합만 끝내고, 아니면 띄어씁니다. 좌우로 끌면 커서가 움직입니다.")
                    tip("지우기", "누른 순서를 거꾸로 되감습니다. 가기 → 각 → 가")
                    tip("한/A", "탭하면 한글과 영문을 오가고, 길게 누르면 다음 키보드로 넘어갑니다.")
                }

                Section {
                    Link(destination: Self.repository) {
                        Label("GitHub에서 소스 보기", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } header: {
                    Text("오픈소스")
                } footer: {
                    Text("광고·추적·구독이 없고 네트워크를 쓰지 않습니다. 모든 코드는 MIT 라이선스로 공개돼 있습니다.")
                }
            }
            .navigationTitle("천지in")
            .task {
                // 앱을 열면 바로 키보드가 뜨게 — 키보드를 써 보기 편하다.
                try? await Task.sleep(for: .milliseconds(400))
                focused = true
            }
        }
    }

    private func tip(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
