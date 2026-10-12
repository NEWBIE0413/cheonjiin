import CheonjiinCore
import SwiftUI

@main
struct CheonjiinApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

/// 설정을 바꾸는 즉시 App Group에 저장한다. 키보드는 다음에 뜰 때 읽는다.
@MainActor @Observable
final class SettingsStore {
    var settings: KeyboardSettings {
        didSet { settings.save() }
    }

    init() { settings = KeyboardSettings.load() }
}

struct ContentView: View {
    @State private var store = SettingsStore()
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
                    Text("설정 › 천지in › 키보드에서 '천지in'을 켜세요. '전체 접근 허용'은 진동·키 소리와 아래 설정을 키보드에 전하는 데만 쓰이고, 꺼도 기본 설정으로 모든 입력이 동작합니다.")
                }

                Section("써 보기") {
                    TextField("여기를 눌러 천지in으로 써 보세요", text: $sample, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                }

                Section {
                    NavigationLink {
                        LanguagesView(settings: $store.settings)
                    } label: {
                        LabeledContent("언어", value: store.settings.languages.map(\.shortTitle).joined(separator: ", "))
                    }
                    Toggle("가로 화면에서 두벌식", isOn: $store.settings.landscapeDubeolsik)
                } header: {
                    Text("언어")
                } footer: {
                    Text("지구본 키를 누르면 이 순서대로 바뀌고, 길게 누르면 다른 키보드로 넘어갑니다.")
                }

                Section("길게 누르기") {
                    Toggle("같은 글자 계속 입력", isOn: $store.settings.keyRepeat)
                    SliderRow(title: "시작까지", value: $store.settings.repeatDelay,
                              range: KeyboardSettings.ranges.repeatDelay, step: 0.01) { String(format: "%.2f초", $0) }
                    SliderRow(title: "빠르기", value: speed, range: speedRange, step: 1) { "초당 \(Int($0))자" }
                }

                Section {
                    Toggle("진동", isOn: $store.settings.haptics)
                    SliderRow(title: "세기", value: $store.settings.hapticStrength,
                              range: KeyboardSettings.ranges.hapticStrength, step: 0.05) { "\(Int($0 * 100))%" }
                        .disabled(!store.settings.haptics)
                    Toggle("키 소리", isOn: $store.settings.keySound)
                } header: {
                    Text("진동·소리")
                } footer: {
                    Text("진동과 키 소리는 '전체 접근 허용'이 켜져 있어야 납니다. 키 소리는 무음 모드에서 나지 않습니다.")
                }

                Section("키 크기") {
                    SliderRow(title: "세로 화면", value: $store.settings.portraitRowHeight,
                              range: KeyboardSettings.ranges.portraitRowHeight, step: 1) { "\(Int($0))pt" }
                    SliderRow(title: "가로 화면", value: $store.settings.landscapeRowHeight,
                              range: KeyboardSettings.ranges.landscapeRowHeight, step: 1) { "\(Int($0))pt" }
                }

                Section {
                    Toggle("글자 키를 밀어 커서 이동", isOn: $store.settings.swipeCursor)
                    SliderRow(title: "감도", value: sensitivity, range: 1...10, step: 1) { "\(Int($0))" }
                } header: {
                    Text("커서")
                } footer: {
                    Text("간격 키는 언제나 좌우로 밀어 커서를 옮길 수 있습니다.")
                }

                Section {
                    Button("기본값으로 되돌리기", role: .destructive) { store.settings = KeyboardSettings() }
                }

                Section("입력 방법") {
                    tip("모음", "ㅣ ㆍ ㅡ 세 획을 이어 누릅니다. ㅣㆍ = ㅏ, ㆍㅣ = ㅓ, ㆍㅡ = ㅗ, ㅡㆍ = ㅜ")
                    tip("자음", "같은 키를 이어 누르면 ㄱ → ㅋ → ㄲ. 같은 자음을 따로 쓰려면 사이에 간격 키를 누릅니다(안녕: ㄴ, 간격, ㄴ).")
                    tip("간격", "조합 중(→ 표시)이면 조합만 끝내고, 아니면 띄어씁니다.")
                    tip("지우기", "누른 순서를 거꾸로 되감습니다. 가기 → 각 → 가")
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
        }
    }

    // 사람이 읽기 쉬운 단위로 바꾼 슬라이더 값.

    private var speedRange: ClosedRange<Double> {
        let r = KeyboardSettings.ranges.repeatInterval
        return (1 / r.upperBound).rounded()...(1 / r.lowerBound).rounded()
    }

    /// 초당 글자 수 ↔ 반복 간격(초)
    private var speed: Binding<Double> {
        Binding(get: { (1 / store.settings.repeatInterval).rounded() },
                set: { store.settings.repeatInterval = 1 / $0 })
    }

    /// 감도 1~10 ↔ 커서 한 칸 거리(감도가 높을수록 짧다)
    private var sensitivity: Binding<Double> {
        let r = KeyboardSettings.ranges.cursorStep
        let span = r.upperBound - r.lowerBound
        return Binding(get: { (10 - (store.settings.cursorStep - r.lowerBound) / span * 9).rounded() },
                       set: { store.settings.cursorStep = r.lowerBound + (10 - $0) / 9 * span })
    }

    private func tip(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(body).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct SliderRow: View {
    var title: String
    @Binding var value: Double
    var range: ClosedRange<Double>
    var step: Double
    var label: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title, value: label(value))
            Slider(value: $value, in: range, step: step)
        }
    }
}

/// 지구본 키가 도는 언어 목록: 끌어서 순서 바꾸기, 지워서 빼기, 오른쪽 위 ＋로 더하기.
struct LanguagesView: View {
    @Binding var settings: KeyboardSettings

    private var missing: [InputLanguage] {
        InputLanguage.allCases.filter { !settings.languages.contains($0) }
    }

    var body: some View {
        List {
            Section {
                ForEach(settings.languages) { language in
                    Text(language.title)
                }
                .onMove { settings.languages.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { offsets in
                    // 언어가 하나도 없으면 키보드가 쓸모없으니 마지막 하나는 남긴다.
                    guard settings.languages.count > offsets.count else { return }
                    settings.languages.remove(atOffsets: offsets)
                }
                .deleteDisabled(settings.languages.count <= 1)
            } footer: {
                Text("지구본 키를 누를 때마다 이 순서대로 다음 언어로 바뀝니다. 끌어서 순서를 바꾸고, 지워서 뺄 수 있어요. 더하기는 오른쪽 위 ＋.")
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle("언어")
        .toolbar {
            Menu {
                ForEach(missing) { language in
                    Button(language.title) { settings.languages.append(language) }
                }
            } label: {
                Label("언어 추가", systemImage: "plus")
            }
            .disabled(missing.isEmpty)
        }
    }
}

extension InputLanguage {
    var shortTitle: String {
        switch self {
        case .cheonjiin: "천지인"
        case .dubeolsik: "두벌식"
        case .english: "English"
        }
    }
}
