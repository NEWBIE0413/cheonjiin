/// 천지인 모음 획.
public enum Stroke: Character, Sendable, CaseIterable {
    case i = "ㅣ"
    case dot = "ㆍ"
    case eu = "ㅡ"
}

/// 천지인 자음 키. 같은 키를 연달아 누르면 `cycle` 순서로 바뀐다.
public enum ConsonantKey: Sendable, CaseIterable {
    case giyeok, nieun, digeut, bieup, siot, jieut, ieung

    public var cycle: [Character] {
        switch self {
        case .giyeok: ["ㄱ", "ㅋ", "ㄲ"]
        case .nieun: ["ㄴ", "ㄹ"]
        case .digeut: ["ㄷ", "ㅌ", "ㄸ"]
        case .bieup: ["ㅂ", "ㅍ", "ㅃ"]
        case .siot: ["ㅅ", "ㅎ", "ㅆ"]
        case .jieut: ["ㅈ", "ㅊ", "ㅉ"]
        case .ieung: ["ㅇ", "ㅁ"]
        }
    }

    /// 키 캡에 쓰는 글자(쌍자음은 빼고 앞의 둘).
    public var label: String { String(cycle.prefix(2)) }
}

public enum CheonjiinInput: Sendable, Equatable {
    case consonant(ConsonantKey)
    case vowel(Stroke)
}

/// 문서에 반영할 편집: 커서 앞 `deleteCount`자를 지우고 `insert`를 넣는다.
public struct TextEdit: Equatable, Sendable {
    public var deleteCount: Int
    public var insert: String

    public init(deleteCount: Int = 0, insert: String = "") {
        self.deleteCount = deleteCount
        self.insert = insert
    }

    public var isEmpty: Bool { deleteCount == 0 && insert.isEmpty }

    static func diff(from old: String, to new: String) -> TextEdit {
        let common = zip(old, new).prefix { $0 == $1 }.count
        return TextEdit(deleteCount: old.count - common, insert: String(new.dropFirst(common)))
    }
}

enum Vowels {
    static let table: [String: Character] = [
        "ㅣ": "ㅣ", "ㅣㆍ": "ㅏ", "ㅣㆍㆍ": "ㅑ", "ㅣㆍㅣ": "ㅐ", "ㅣㆍㆍㅣ": "ㅒ",
        "ㆍㅣ": "ㅓ", "ㆍㆍㅣ": "ㅕ", "ㆍㅣㅣ": "ㅔ", "ㆍㆍㅣㅣ": "ㅖ",
        "ㆍㅡ": "ㅗ", "ㆍㆍㅡ": "ㅛ", "ㆍㅡㅣ": "ㅚ", "ㆍㅡㅣㆍ": "ㅘ", "ㆍㅡㅣㆍㅣ": "ㅙ",
        "ㅡㆍ": "ㅜ", "ㅡㆍㆍ": "ㅠ", "ㅡㆍㅣ": "ㅟ", "ㅡㆍㆍㅣ": "ㅝ", "ㅡㆍㆍㅣㅣ": "ㅞ",
        "ㅡ": "ㅡ", "ㅡㅣ": "ㅢ",
    ]
    /// 아직 모음이 되지 않은 중간 상태와 화면 표시.
    static let pending: [String: String] = ["ㆍ": "ㆍ", "ㆍㆍ": "‥"]

    static func key(_ strokes: [Stroke]) -> String { String(strokes.map(\.rawValue)) }
    static func vowel(_ strokes: [Stroke]) -> Character? { table[key(strokes)] }
    static func isValid(_ strokes: [Stroke]) -> Bool {
        vowel(strokes) != nil || pending[key(strokes)] != nil
    }
}

struct Syllable: Equatable {
    var initial: Character?
    var strokes: [Stroke] = []
    /// 받침 자모(겹받침이면 두 개).
    var finals: [Character] = []

    var isEmpty: Bool { initial == nil && strokes.isEmpty }
    var vowel: Character? { Vowels.vowel(strokes) }

    var rendered: String {
        if let initial, let vowel,
           let syllable = Hangul.compose(initial: initial, vowel: vowel, final: Hangul.finalCharacter(finals)) {
            return String(syllable)
        }
        let vowelText = vowel.map(String.init) ?? Vowels.pending[Vowels.key(strokes)] ?? ""
        return (initial.map(String.init) ?? "") + vowelText
    }
}

/// 조합 중인 구간: 끝난 음절들(`done`) + 지금 만드는 음절.
/// 구간 전체를 들고 있는 이유는 백스페이스가 키 입력을 거꾸로 되감게 하기 위해서다
/// ("각" + ㅣ = "가기" → ⌫ → "각").
struct Composition: Equatable {
    var done = ""
    var current = Syllable()

    var text: String { done + current.rendered }

    func adding(consonant c: Character) -> Composition {
        var next = self
        if current.isEmpty {
            next.current.initial = c
        } else if current.initial != nil, current.vowel != nil,
                  Hangul.finalCharacter(current.finals + [c]) != nil {
            next.current.finals.append(c)
        } else {
            next.done += current.rendered
            next.current = Syllable(initial: c)
        }
        return next
    }

    func adding(stroke s: Stroke) -> Composition {
        var next = self
        if !current.finals.isEmpty {
            // 받침 뒤에 모음이 오면 마지막 받침이 다음 음절의 초성으로 넘어간다.
            var head = current
            let moved = head.finals.removeLast()
            next.done += head.rendered
            next.current = Syllable(initial: moved, strokes: [s])
        } else if current.strokes.isEmpty {
            next.current.strokes = [s]
        } else if Vowels.isValid(current.strokes + [s]) {
            next.current.strokes.append(s)
        } else if current.strokes == [.dot, .dot], s == .dot {
            next.current.strokes = [.dot]
        } else {
            next.done += current.rendered
            next.current = Syllable(strokes: [s])
        }
        return next
    }
}

/// 천지인 입력 상태 기계. 키 입력을 받아 문서에 적용할 `TextEdit`을 돌려준다.
/// UI·UIKit에 의존하지 않으므로 단위 테스트로 조합 규칙 전체를 검증할 수 있다.
public struct CheonjiinEngine: Sendable {
    /// 같은 자음 키를 이 시간(초) 안에 다시 누르면 다음 자음으로 바뀌고,
    /// 넘기면 새 자음으로 들어간다("학교"의 ㄱ·ㄱ).
    public var cycleWindow: Double

    private var composition = Composition()
    private var history: [(composition: Composition, group: Int)] = []
    private var nextGroup = 0
    private var cycle: (key: ConsonantKey, index: Int, base: Composition, time: Double, group: Int)?

    /// 되감기 기록 상한 — 넘치면 오래된 것부터 버리고, 그 너머의 ⌫는 문서 글자를 지운다.
    private let historyLimit = 64

    public init(cycleWindow: Double = 0.8) {
        self.cycleWindow = cycleWindow
    }

    /// 지금 문서 커서 앞에 놓인, 아직 바뀔 수 있는 글자들.
    public var composingText: String { composition.text }
    public var isComposing: Bool { !composition.text.isEmpty }

    public mutating func type(_ input: CheonjiinInput, at time: Double) -> TextEdit {
        let before = composition.text
        switch input {
        case .consonant(let key):
            if let c = cycle, c.key == key, time - c.time <= cycleWindow {
                let index = (c.index + 1) % key.cycle.count
                cycle = (key, index, c.base, time, c.group)
                record(group: c.group)
                composition = c.base.adding(consonant: key.cycle[index])
            } else {
                let group = newGroup()
                cycle = (key, 0, composition, time, group)
                record(group: group)
                composition = composition.adding(consonant: key.cycle[0])
            }
        case .vowel(let stroke):
            cycle = nil
            record(group: newGroup())
            composition = composition.adding(stroke: stroke)
        }
        return .diff(from: before, to: composition.text)
    }

    /// 마지막 키 입력 하나를 되돌린다. 자음은 순환까지 한 번에(ㅋ → 없음), 모음은 한 획씩(ㅑ → ㅏ).
    /// 되돌릴 게 없으면 문서의 한 글자를 지우는 편집을 돌려준다.
    public mutating func backspace() -> TextEdit {
        cycle = nil
        guard let group = history.last?.group else {
            composition = Composition()
            return TextEdit(deleteCount: 1)
        }
        let before = composition.text
        while let last = history.last, last.group == group {
            composition = history.removeLast().composition
        }
        return .diff(from: before, to: composition.text)
    }

    /// 조합을 끝낸다. 화면의 글자는 그대로 두고 엔진만 잊는다.
    public mutating func commit() {
        composition = Composition()
        history.removeAll()
        cycle = nil
    }

    private mutating func newGroup() -> Int {
        nextGroup += 1
        return nextGroup
    }

    private mutating func record(group: Int) {
        history.append((composition, group))
        if history.count > historyLimit { history.removeFirst() }
    }
}

/// 같은 키를 시간 안에 다시 누르면 다음 후보로 넘어가는 순환기(문장부호 키 등).
public struct TapCycler: Sendable {
    public var window: Double
    private var last: (id: String, index: Int, time: Double)?

    public init(window: Double = 0.8) { self.window = window }

    /// 이번 탭이 고를 후보 번호와, 직전 후보를 바꾸는 반복 탭인지.
    public mutating func tap(_ id: String, count: Int, at time: Double) -> (index: Int, replaces: Bool) {
        if let l = last, l.id == id, time - l.time <= window {
            let index = (l.index + 1) % count
            last = (id, index, time)
            return (index, true)
        }
        last = (id, 0, time)
        return (0, false)
    }

    public mutating func reset() { last = nil }
}
