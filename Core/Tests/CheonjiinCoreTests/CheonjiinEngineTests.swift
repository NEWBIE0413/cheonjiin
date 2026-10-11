import Testing
@testable import CheonjiinCore

/// 키 시퀀스를 엔진에 넣고 편집을 가상 문서에 적용한다.
/// 표기: ㅣㆍㅡ = 모음 획, ㄱㄴㄷㅂㅅㅈㅇ = 자음 키, `/` = 순환 시간을 넘기는 멈춤,
/// `<` = 백스페이스, `|` = 조합 끝내기(띄어쓰기 키가 하는 일).
struct Typist {
    var engine = CheonjiinEngine(cycleWindow: 0.8)
    var document: String
    var clock = 0.0

    init(document: String = "") { self.document = document }

    static let keys: [Character: ConsonantKey] = [
        "ㄱ": .giyeok, "ㄴ": .nieun, "ㄷ": .digeut, "ㅂ": .bieup,
        "ㅅ": .siot, "ㅈ": .jieut, "ㅇ": .ieung,
    ]

    mutating func type(_ keys: String) -> String {
        for k in keys {
            clock += 0.1
            switch k {
            case " ": continue
            case "/": clock += 2
            case "|": engine.commit()
            case "<": apply(engine.backspace())
            default:
                if let stroke = Stroke(rawValue: k) {
                    apply(engine.type(.vowel(stroke), at: clock))
                } else if let key = Typist.keys[k] {
                    apply(engine.type(.consonant(key), at: clock))
                } else {
                    Issue.record("모르는 키 \(k)")
                }
            }
        }
        return document
    }

    mutating func apply(_ edit: TextEdit) {
        document.removeLast(min(edit.deleteCount, document.count))
        document += edit.insert
    }
}

func typed(_ keys: String) -> String {
    var t = Typist()
    return t.type(keys)
}

@Test(arguments: [
    ("ㄱㅣㆍ", "가"),
    ("ㄱㅣㆍㆍ", "갸"),
    ("ㄱㆍㅣ", "거"),
    ("ㄱㆍㆍㅣ", "겨"),
    ("ㄱㆍㅡ", "고"),
    ("ㄱㆍㆍㅡ", "교"),
    ("ㄱㅡㆍ", "구"),
    ("ㄱㅡㆍㆍ", "규"),
    ("ㄱㅡ", "그"),
    ("ㄱㅣ", "기"),
    ("ㄱㅣㆍㅣ", "개"),
    ("ㅇㅣㆍㆍㅣ", "얘"),
    ("ㄱㆍㅣㅣ", "게"),
    ("ㅇㆍㆍㅣㅣ", "예"),
    ("ㄱㆍㅡㅣ", "괴"),
    ("ㄱㆍㅡㅣㆍ", "과"),
    ("ㅇㆍㅡㅣㆍㅣ", "왜"),
    ("ㅇㅡㆍㅣ", "위"),
    ("ㅇㅡㆍㆍㅣ", "워"),
    ("ㅇㅡㆍㆍㅣㅣ", "웨"),
    ("ㅇㅡㅣ", "의"),
])
func vowels(keys: String, expected: String) {
    #expect(typed(keys) == expected)
}

@Test(arguments: [
    ("ㅅㅅㅣㆍㄴ ㄱㅡㆍㄱ", "한국"),
    ("ㅅㅅㅣㆍㄱ / ㄱㆍㆍㅡ", "학교"),
    ("ㅅㅅㅣㆍㄱ ㄱㆍㆍㅡ", "하쿄"),
    ("ㄱㅣㆍㄱㅣ", "가기"),
    ("ㄷㅣㆍㄴㄴㄱ", "닭"),
    ("ㄷㅣㆍㄴㄴㄱㅣ", "달기"),
    ("ㅇㆍㅣㅂㅅ ㄷㅣㆍ", "없다"),
    ("ㅇㅡㅣㅅㅣㆍ", "의사"),
    ("ㄱㅣㆍㄷㄷ", "같"),
    ("ㄱㅣㆍㄷㄷㄷ", "가ㄸ"),
    ("ㄱㅣㆍㄷㄷㄷㅣㆍ", "가따"),
    ("ㄱㅣㆍㄷㄷㄷㄷ", "갇"),
    ("ㅇㅣㅅㅅㅅ / ㄷㅣㆍ", "있다"),
    ("ㅈㆍㅡㅅㅅ ㅇㅣㆍ", "좋아"),
    ("ㄱㆍㅡㅣㆍㅣㄴ ㅈㅈㅣㆍㄴㅅㅅ ㅇㅣㆍ", "괜찮아"),
    ("ㅇㅇㅡㆍㆍㅣ", "뭐"),
    ("ㄱㄱㄱ", "ㄲ"),
    ("ㄱㄱㄱㄱ", "ㄱ"),
    ("ㄱ / ㄱ", "ㄱㄱ"),
    ("ㄱㅣㆍㄱㆍ", "가ㄱㆍ"),
    ("ㄱㅣㆍㄱㆍㅣ", "가거"),
    ("ㄱㅣㆍㄱㆍㆍㅡ", "가교"),
    ("ㆍ", "ㆍ"),
    ("ㆍㆍ", "‥"),
    ("ㆍㆍㆍ", "ㆍ"),
    ("ㄱㅣㆍㅡ", "가ㅡ"),
    ("ㄴㄴㅣㆍㅇㅇ", "람"),
    ("ㅂㅂㅣ", "피"),
    ("ㅂㅂㅂㅣ", "삐"),
])
func words(keys: String, expected: String) {
    #expect(typed(keys) == expected)
}

@Test func backspaceRewindsKeystrokes() {
    var t = Typist()
    #expect(t.type("ㄱㅣㆍㄱㅣ") == "가기")
    #expect(t.type("<") == "각")
    #expect(t.type("<") == "가")
    #expect(t.type("<") == "기")
    #expect(t.type("<") == "ㄱ")
    #expect(t.type("<") == "")
}

@Test func backspaceRemovesWholeCycledConsonant() {
    var t = Typist()
    #expect(t.type("ㄱㅣㆍㄱㄱ") == "갘")
    #expect(t.type("<") == "가")
}

@Test func backspaceRewindsVowelStrokeByStroke() {
    var t = Typist()
    #expect(t.type("ㅇㅡㆍㆍㅣ") == "워")
    #expect(t.type("<") == "유")
    #expect(t.type("<") == "우")
}

@Test func backspaceAfterCommitDeletesDocumentText() {
    var t = Typist(document: "안녕 ")
    #expect(t.type("ㄱㅣㆍ|") == "안녕 가")
    #expect(t.type("<") == "안녕 ")
    #expect(t.type("<") == "안녕")
}

@Test func commitKeepsTextAndStartsFresh() {
    var t = Typist()
    #expect(t.type("ㄱㅣㆍ|ㄱㅣ") == "가기")
    #expect(t.type("<<") == "가")
}

@Test func cycleRestartsAfterVowel() {
    var t = Typist()
    #expect(t.type("ㄱㅣㆍㄱ") == "각")
    #expect(t.type("ㅣㄱ") == "가긱")
}

@Test func editTouchesOnlyChangedTail() {
    var e = CheonjiinEngine()
    _ = e.type(.consonant(.giyeok), at: 0)
    _ = e.type(.vowel(.i), at: 0.1)
    _ = e.type(.vowel(.dot), at: 0.2)
    // "가" → "각": 한 글자 바꾸기
    #expect(e.type(.consonant(.giyeok), at: 0.3) == TextEdit(deleteCount: 1, insert: "각"))
    // "각" → "가기": 받침이 넘어가며 마지막 글자만 바뀐다
    #expect(e.type(.vowel(.i), at: 0.4) == TextEdit(deleteCount: 1, insert: "가기"))
}

@Test func tapCycler() {
    var c = TapCycler(window: 0.8)
    #expect(c.tap("p", count: 4, at: 0).index == 0)
    #expect(c.tap("p", count: 4, at: 0.3) == (1, true))
    #expect(c.tap("p", count: 4, at: 2.0) == (0, false))
}

// MARK: 두벌식 (가로 화면)

func dubeol(_ jamo: String) -> String {
    var t = Typist()
    for (i, c) in jamo.enumerated() {
        if c == "<" { t.apply(t.engine.backspace()); continue }
        t.apply(t.engine.type(.jamo(c), at: Double(i)))
    }
    return t.document
}

@Test(arguments: [
    ("ㅎㅏㄴㄱㅜㄱ", "한국"),
    ("ㄷㅏㄹㄱㅏ", "달가"),
    ("ㄷㅏㄹㄱ", "닭"),
    ("ㅇㅗㅏ", "와"),
    ("ㅇㅗㅐ", "왜"),
    ("ㅇㅜㅓ", "워"),
    ("ㅇㅡㅣㅅㅏ", "의사"),
    ("ㅇㅏㅣ", "아ㅣ"),
    ("ㅇㅠㅣ", "유ㅣ"),
    ("ㄱㅏㅂㅅ", "값"),
    ("ㄱㅏㅂㅅㅇㅣ", "값이"),
    ("ㅃㅏㅇ", "빵"),
    ("ㄱㅏㄸ", "가ㄸ"),
    ("ㅋㅋㅋ", "ㅋㅋㅋ"),
    ("ㅇㅗㅏ<", "오"),
    ("ㄷㅏㄹㄱ<", "달"),
])
func dubeolsik(keys: String, expected: String) {
    #expect(dubeol(keys) == expected)
}

// MARK: 길게 누르기 반복

@Test func repeatConsonantKeyRepeatsCycledConsonant() {
    var t = Typist()
    #expect(t.type("ㄱㄱ") == "ㅋ")
    t.apply(t.engine.repeatKey(.consonant(.giyeok)))
    t.apply(t.engine.repeatKey(.consonant(.giyeok)))
    #expect(t.document == "ㅋㅋㅋ")
}

@Test func repeatVowelKeyRepeatsWholeVowel() {
    var t = Typist()
    #expect(t.type("ㅡㆍㆍ") == "ㅠ")
    t.apply(t.engine.repeatKey(.vowel(.dot)))
    t.apply(t.engine.repeatKey(.vowel(.dot)))
    #expect(t.document == "ㅠㅠㅠ")
}

@Test func repeatAfterSyllableAddsStandaloneJamo() {
    var t = Typist()
    #expect(t.type("ㄱㅣㆍ") == "가")
    t.apply(t.engine.repeatKey(.vowel(.eu)))
    #expect(t.document == "가ㅡ")
    t.apply(t.engine.backspace())
    #expect(t.document == "가")
}
