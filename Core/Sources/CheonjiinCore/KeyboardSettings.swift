import Foundation

/// 지구본 키로 오가는 입력 언어(자판).
public enum InputLanguage: String, Codable, CaseIterable, Sendable, Identifiable {
    case cheonjiin, dubeolsik, english

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cheonjiin: "한국어 · 천지인"
        case .dubeolsik: "한국어 · 두벌식"
        case .english: "English · QWERTY"
        }
    }

    public var isKorean: Bool { self != .english }
}

/// 컨테이너 앱에서 고르고 키보드가 읽는 설정. App Group의 UserDefaults에 JSON으로 둔다.
/// 새 항목이 생겨도 예전에 저장한 값이 깨지지 않게, 없는 항목은 기본값으로 읽는다.
public struct KeyboardSettings: Codable, Equatable, Sendable {
    /// 지구본 키를 누를 때 도는 순서. 비어 있을 수 없다.
    public var languages: [InputLanguage] = [.cheonjiin, .english]
    /// 가로 화면에서는 천지인 대신 두벌식으로.
    public var landscapeDubeolsik = true

    /// 글자 키를 길게 누르면 같은 글자를 계속 넣는다.
    public var keyRepeat = true
    /// 반복이 시작되기까지(초)와 반복 간격(초). 지우기 키도 같은 값을 쓴다.
    public var repeatDelay = 0.32
    public var repeatInterval = 0.05

    public var haptics = true
    /// 0.2 ~ 1.0
    public var hapticStrength = 1.0
    public var keySound = true

    /// 줄 높이(pt). 키 높이는 여기서 위아래 3pt씩 뺀 값이다.
    public var portraitRowHeight = 48.0
    public var landscapeRowHeight = 34.0

    /// 글자 키를 누른 채 좌우로 밀어 커서 이동(간격 키는 항상 된다).
    public var swipeCursor = true
    /// 커서 한 칸에 해당하는 손가락 이동 거리(pt). 작을수록 민감하다.
    public var cursorStep = 9.0

    public init() {}

    public static let ranges = (
        repeatDelay: 0.15...0.8,
        repeatInterval: 0.02...0.15,
        hapticStrength: 0.2...1.0,
        portraitRowHeight: 40.0...60.0,
        landscapeRowHeight: 28.0...44.0,
        cursorStep: 5.0...18.0
    )

    /// 범위를 벗어난 값과 빈·중복 언어 목록을 바로잡는다.
    public func sanitized() -> KeyboardSettings {
        var s = self
        var seen = Set<InputLanguage>()
        s.languages = languages.filter { seen.insert($0).inserted }
        if s.languages.isEmpty { s.languages = [.cheonjiin] }
        let r = Self.ranges
        s.repeatDelay = repeatDelay.clamped(to: r.repeatDelay)
        s.repeatInterval = repeatInterval.clamped(to: r.repeatInterval)
        s.hapticStrength = hapticStrength.clamped(to: r.hapticStrength)
        s.portraitRowHeight = portraitRowHeight.clamped(to: r.portraitRowHeight)
        s.landscapeRowHeight = landscapeRowHeight.clamped(to: r.landscapeRowHeight)
        s.cursorStep = cursorStep.clamped(to: r.cursorStep)
        return s
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        // 모르는 언어 값(다음 버전에서 추가된 자판 등)은 건너뛴다.
        let rawLanguages = try c.decodeIfPresent([String].self, forKey: .languages)
        languages = rawLanguages?.compactMap(InputLanguage.init(rawValue:)) ?? d.languages
        landscapeDubeolsik = try c.decodeIfPresent(Bool.self, forKey: .landscapeDubeolsik) ?? d.landscapeDubeolsik
        keyRepeat = try c.decodeIfPresent(Bool.self, forKey: .keyRepeat) ?? d.keyRepeat
        repeatDelay = try c.decodeIfPresent(Double.self, forKey: .repeatDelay) ?? d.repeatDelay
        repeatInterval = try c.decodeIfPresent(Double.self, forKey: .repeatInterval) ?? d.repeatInterval
        haptics = try c.decodeIfPresent(Bool.self, forKey: .haptics) ?? d.haptics
        hapticStrength = try c.decodeIfPresent(Double.self, forKey: .hapticStrength) ?? d.hapticStrength
        keySound = try c.decodeIfPresent(Bool.self, forKey: .keySound) ?? d.keySound
        portraitRowHeight = try c.decodeIfPresent(Double.self, forKey: .portraitRowHeight) ?? d.portraitRowHeight
        landscapeRowHeight = try c.decodeIfPresent(Double.self, forKey: .landscapeRowHeight) ?? d.landscapeRowHeight
        swipeCursor = try c.decodeIfPresent(Bool.self, forKey: .swipeCursor) ?? d.swipeCursor
        cursorStep = try c.decodeIfPresent(Double.self, forKey: .cursorStep) ?? d.cursorStep
    }

    // MARK: 저장

    static let storageKey = "keyboardSettings.v1"

    /// 앱과 키보드가 함께 쓰는 저장소. App Group ID는 각 타깃 Info.plist의 `CheonjiinAppGroup`에 있다.
    /// 키보드는 '전체 접근 허용'이 꺼져 있으면 이 저장소를 못 읽을 수 있어서, 그때는 기본값을 쓴다.
    public static var sharedDefaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "CheonjiinAppGroup") as? String else { return nil }
        return UserDefaults(suiteName: group)
    }

    public static func load(from defaults: UserDefaults? = sharedDefaults) -> KeyboardSettings {
        guard let data = defaults?.data(forKey: storageKey),
              let settings = try? JSONDecoder().decode(KeyboardSettings.self, from: data) else {
            return KeyboardSettings()
        }
        return settings.sanitized()
    }

    public func save(to defaults: UserDefaults? = sharedDefaults) {
        guard let data = try? JSONEncoder().encode(sanitized()) else { return }
        defaults?.set(data, forKey: Self.storageKey)
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
