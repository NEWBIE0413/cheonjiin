import AudioToolbox
import CheonjiinCore
import UIKit

enum Layer {
    /// symbols = 숫자와 특수문자를 한 화면에.
    case korean, english, symbols

    var isLetters: Bool { self == .korean || self == .english }
}

enum Shift {
    case off, on, locked
}

enum KeyAction: Equatable {
    case cheonjiin(CheonjiinInput)
    case character(String)
    /// 가로 화면 두벌식 자모.
    case jamo(Character)
    case backspace, space, enter, globe, shift
    /// . , ? ! 를 연타로 순환.
    case punctuation
    /// 숫자·특수문자 화면의 1/2 ↔ 2/2.
    case symbolPage
    case layer(Layer)
}

/// 키보드의 모든 입력 동작. 화면은 `press`/`release`만 부르고, 상태가 바뀌면 `onChange`로 다시 그린다.
@MainActor
final class KeyboardModel {
    var layer: Layer = .korean { didSet { if layer != oldValue { onChange?() } } }
    var shift: Shift = .off { didSet { if shift != oldValue { onChange?() } } }
    private(set) var forcedDark = false { didSet { if forcedDark != oldValue { onChange?() } } }
    /// 조합 중인 글자(문장부호 순환 포함)가 있는지 — 이때 간격 키는 띄어쓰지 않고 조합만 끝낸다.
    private(set) var composing = false { didSet { if composing != oldValue { onChange?() } } }
    /// 키를 밀어 커서를 옮기는 중 — 키 글자는 그대로 둔다(사용자 요청: 키보드가 사라지지 않게).
    private(set) var cursorMode = false { didSet { if cursorMode != oldValue { onChange?() } } }
    /// 숫자·특수문자 화면의 쪽(0 = 1/2, 1 = 2/2).
    private(set) var symbolPage = 0 { didSet { if symbolPage != oldValue { onChange?() } } }
    /// 가로 화면이면 한글을 천지인 대신 두벌식으로, 키를 낮게.
    var landscape = false {
        didSet {
            guard landscape != oldValue else { return }
            commitComposition()
            onChange?()
        }
    }
    var isDubeolsik: Bool { layer == .korean && landscape }
    /// 숫자·기호에서 돌아갈 글자 레이어.
    private(set) var letterLayer: Layer = .korean

    var onChange: (() -> Void)?

    private weak var controller: UIInputViewController?
    /// 같은 자음 연타는 시간 제한 없이 순환한다. 끊을 때는 간격 키를 누른다("안녕": ㄴ, 간격, ㄴ).
    private var engine = CheonjiinEngine(cycleWindow: .infinity)
    private var hapticsAllowed = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)
    private var lastShiftTap = 0.0
    private var repeatTask: Task<Void, Never>?
    private var globeTask: Task<Void, Never>?
    private var globeLongPressed = false
    private var spaceSteps = 0
    /// 길게 누르면 반복할 입력과, 그 반복을 일으킨 키.
    private var keyRepeatTask: Task<Void, Never>?
    private var repeatingAction: KeyAction?
    /// 방금 누른 키의 입력을 되돌리는 방법 — 그 키에서 손가락을 밀어 커서 이동이 시작되면 쓴다
    /// (키는 닿는 순간 입력되므로, 밀기로 바뀌면 잘못 들어간 글자를 지워야 한다).
    private var undoLastPress: (() -> Void)?
    /// 문장부호 키로 넣은 마지막 부호의 순번. 다른 키를 누르면 끝난다.
    private var punctuationIndex: Int?
    private var lastEditTime = 0.0
    private var syncTask: Task<Void, Never>?

    static let punctuationMarks = [".", ",", "?", "!"]

    /// 간격 키를 끌 때 커서 한 칸에 해당하는 거리(pt).
    private static let cursorStep: CGFloat = 9

    init(controller: UIInputViewController) {
        self.controller = controller
    }

    private var proxy: UITextDocumentProxy? { controller?.textDocumentProxy }
    private var now: Double { ProcessInfo.processInfo.systemUptime }

    // MARK: 키

    func press(_ action: KeyAction) {
        feedback(Self.sound(for: action))
        keyRepeatTask?.cancel()
        var repeatPayload: RepeatPayload?
        syncTask?.cancel()
        lastEditTime = now
        if action != .punctuation, action != .space, punctuationIndex != nil {
            punctuationIndex = nil
            syncComposing()
        }
        undoLastPress = nil
        switch action {
        case .cheonjiin(let input):
            rememberEngineForUndo()
            apply(engine.type(input, at: now))
            repeatPayload = .hangul(input)
        case .jamo(let c):
            let jamo = shift == .off ? c : Dubeolsik.shifted(c)
            rememberEngineForUndo()
            apply(engine.type(.jamo(jamo), at: now))
            if shift == .on { shift = .off }
            repeatPayload = .hangul(.jamo(jamo))
        case .character(let text):
            commitComposition()
            let typed = shift == .off ? text : text.uppercased()
            proxy?.insertText(typed)
            undoLastPress = { [weak self] in self?.proxy?.deleteBackward() }
            if shift == .on { shift = .off }
            autoShift()
            repeatPayload = .text(typed)
        case .backspace:
            deleteOnce()
            startRepeat()
        case .space:
            // 누르는 순간 처리한다. 떼는 순간에 하면 빠른 연타에서 간격을 떼기 전에 다음 자음이
            // 먼저 들어가 앞 글자에 붙어 버린다("안" 간격 ㄴ → "알").
            spaceSteps = 0
            // 천지인에서는 조합 중인 간격이 조합만 끝낸다. 두벌식은 언제나 띄어쓴다.
            if !isDubeolsik, punctuationIndex != nil || engine.isComposing {
                commitComposition()
            } else {
                commitComposition()
                proxy?.insertText(" ")
                undoLastPress = { [weak self] in self?.proxy?.deleteBackward() }
                if !layer.isLetters { setLayer(letterLayer) }
                autoShift()
            }
        case .punctuation:
            let marks = Self.punctuationMarks
            let previous = punctuationIndex
            undoLastPress = { [weak self] in
                guard let self else { return }
                self.proxy?.deleteBackward()
                if let previous { self.proxy?.insertText(marks[previous]) }
                self.punctuationIndex = previous
                self.syncComposing()
            }
            if let index = punctuationIndex {
                proxy?.deleteBackward()
                punctuationIndex = (index + 1) % marks.count
            } else {
                commitComposition()
                punctuationIndex = 0
            }
            proxy?.insertText(marks[punctuationIndex!])
            syncComposing()
            repeatPayload = .mark(marks[punctuationIndex!])
        case .enter:
            commitComposition()
            proxy?.insertText("\n")
            autoShift()
        case .layer(let next):
            setLayer(next)
        case .shift:
            shiftTap()
        case .symbolPage:
            symbolPage = 1 - symbolPage
        case .globe:
            globeLongPressed = false
            globeTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, let self else { return }
                self.globeLongPressed = true
                self.commitComposition()
                self.controller?.advanceToNextInputMode()
            }
        }
        repeatingAction = repeatPayload == nil ? nil : action
        if let repeatPayload { startKeyRepeat(repeatPayload) }
    }

    func release(_ action: KeyAction) {
        if action == repeatingAction {
            keyRepeatTask?.cancel()
            repeatingAction = nil
        }
        if cursorMode {
            // 밀어서 커서를 옮긴 손가락이 떨어졌을 뿐 — 그 키의 탭 동작(한/A 전환 등)은 하지 않는다.
            cursorMode = false
            return
        }
        switch action {
        case .backspace:
            repeatTask?.cancel()
            repeatTask = nil
        case .globe:
            // 한/A 탭: 한글 ↔ 영문. 길게: iOS의 다음 키보드(이모지 등) — 심사 규정상 다음 키보드로 넘어갈 방법.
            globeTask?.cancel()
            if !globeLongPressed { setLayer(layer == .korean ? .english : .korean) }
        default:
            break
        }
    }

    /// 글자 키나 간격 키를 누른 채 좌우로 밀면 커서가 움직인다.
    /// 빠른 타자 중 손가락이 조금 미끄러진 것과 구분하려고 글자 키는 16pt 넘게, 가로로 분명하게
    /// 밀어야 시작한다. 시작되면 그 키로 들어간 글자는 되돌린다.
    func drag(_ action: KeyAction, dx: CGFloat, dy: CGFloat) {
        guard Self.startsCursorDrag(action) else { return }
        if !cursorMode {
            let threshold: CGFloat = action == .space ? Self.cursorStep : 16
            guard abs(dx) >= threshold, abs(dx) > abs(dy) * 1.5 else { return }
            keyRepeatTask?.cancel()
            repeatingAction = nil
            undoLastPress?()
            undoLastPress = nil
            commitComposition()
            spaceSteps = 0
            cursorMode = true
        }
        let steps = Int(dx / Self.cursorStep)
        guard steps != spaceSteps else { return }
        proxy?.adjustTextPosition(byCharacterOffset: steps - spaceSteps)
        spaceSteps = steps
        // 커서 이동은 진동만(칸마다 소리가 나면 시끄럽다). 세기는 다른 키와 같다.
        if hapticsAllowed { haptic.impactOccurred() }
    }

    private static func startsCursorDrag(_ action: KeyAction) -> Bool {
        switch action {
        case .cheonjiin, .jamo, .character, .punctuation, .space: true
        default: false
        }
    }

    /// 한글 키 입력 직전 상태를 붙잡아 두고, 되돌릴 때 그 상태로 문서와 조합기를 함께 돌린다.
    private func rememberEngineForUndo() {
        let saved = engine
        let savedText = engine.composingText
        undoLastPress = { [weak self] in
            guard let self else { return }
            let edit = TextEdit.diff(from: self.engine.composingText, to: savedText)
            self.engine = saved
            self.apply(edit)
        }
    }

    // MARK: 문서와 동기화

    func refreshContext() {
        commitComposition()
        hapticsAllowed = controller?.hasFullAccess == true
        if hapticsAllowed { haptic.prepare() }
        forcedDark = proxy?.keyboardAppearance == .dark
        autoShift()
    }

    /// 커서를 옮기거나 앱이 글을 바꾸면(메시지 전송 후 입력창 비우기 등) 조합을 놓는다.
    /// 앱이 알려 주는 문서 내용은 우리 입력보다 늦게 따라오므로, 타자가 멈추고 잠시 뒤에
    /// 확인한다 — 바로 비교하면 빠른 연타 중에 멀쩡한 조합을 끊어 자모가 떨어져 나간다.
    func documentChanged() {
        syncTask?.cancel()
        guard composing else { return }
        syncTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            self.verifyComposition()
        }
    }

    private func verifyComposition() {
        guard composing, now - lastEditTime >= 0.3,
              let before = proxy?.documentContextBeforeInput else { return }
        let expected = punctuationIndex.map { Self.punctuationMarks[$0] } ?? engine.composingText
        if !before.hasSuffix(expected) { commitComposition() }
    }

    // MARK: 내부

    private func setLayer(_ next: Layer) {
        commitComposition()
        shift = .off
        symbolPage = 0
        layer = next
        if next.isLetters { letterLayer = next }
        autoShift()
    }

    private func shiftTap() {
        let t = now
        if shift == .on, t - lastShiftTap < 0.35 {
            shift = .locked
        } else {
            shift = shift == .off ? .on : .off
        }
        lastShiftTap = t
    }

    /// 영문에서 문장 첫 글자는 대문자로 — 입력창의 자동 대문자 설정을 따른다.
    private func autoShift() {
        guard layer == .english, shift != .locked, let proxy else { return }
        let before = proxy.documentContextBeforeInput ?? ""
        let wantsCapital: Bool
        switch proxy.autocapitalizationType ?? .sentences {
        case .allCharacters:
            wantsCapital = true
        case .words:
            wantsCapital = before.last.map(\.isWhitespace) ?? true
        case .sentences:
            let trimmed = before.trimmingCharacters(in: .whitespaces)
            wantsCapital = trimmed.isEmpty || before.hasSuffix("\n")
                || (before.last == " " && [".", "!", "?"].contains(trimmed.last))
        default:
            wantsCapital = false
        }
        shift = wantsCapital ? .on : .off
    }

    // MARK: 길게 누르기 반복

    enum RepeatPayload {
        case hangul(CheonjiinInput)
        case text(String)
        case mark(String)
    }

    /// 글자 키를 0.45초 넘게 누르고 있으면 같은 글자를 계속 넣는다(ㅋㅋㅋ, ㅠㅠㅠ, ...).
    private func startKeyRepeat(_ payload: RepeatPayload) {
        keyRepeatTask = Task { [weak self] in
            try? await Task.sleep(for: Self.repeatDelay)
            while !Task.isCancelled {
                guard let self else { return }
                self.feedback(Self.keySound)
                self.repeatOnce(payload)
                try? await Task.sleep(for: Self.repeatInterval)
            }
        }
    }

    private func repeatOnce(_ payload: RepeatPayload) {
        switch payload {
        case .hangul(let input):
            apply(engine.repeatKey(input))
        case .text(let text):
            proxy?.insertText(text)
        case .mark(let mark):
            // 반복이 시작되면 문장부호 순환은 끝난다(...이 .,?로 바뀌지 않게).
            if punctuationIndex != nil {
                punctuationIndex = nil
                syncComposing()
            }
            proxy?.insertText(mark)
        }
    }

    /// 길게 누르면 처음엔 한 글자씩, 1초쯤 지나면 시스템 키보드처럼 단어째 지운다.
    private func startRepeat() {
        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
            try? await Task.sleep(for: Self.repeatDelay)
            var count = 0
            while !Task.isCancelled {
                guard let self else { return }
                self.feedback(Self.deleteSound)
                if count < 14 {
                    self.deleteOnce()
                    try? await Task.sleep(for: Self.repeatInterval)
                } else {
                    self.deleteWord()
                    try? await Task.sleep(for: .milliseconds(150))
                }
                count += 1
            }
        }
    }

    private func deleteOnce() {
        apply(engine.backspace())
        autoShift()
    }

    private func deleteWord() {
        commitComposition()
        guard let proxy else { return }
        var count = 0
        var sawWord = false
        for ch in (proxy.documentContextBeforeInput ?? "").reversed() {
            if ch.isWhitespace, sawWord { break }
            if !ch.isWhitespace { sawWord = true }
            count += 1
        }
        for _ in 0..<max(count, 1) { proxy.deleteBackward() }
    }

    private func commitComposition() {
        engine.commit()
        punctuationIndex = nil
        composing = false
    }

    private func syncComposing() {
        composing = engine.isComposing || punctuationIndex != nil
    }

    private func apply(_ edit: TextEdit) {
        if let proxy {
            for _ in 0..<edit.deleteCount { proxy.deleteBackward() }
            if !edit.insert.isEmpty { proxy.insertText(edit.insert) }
        }
        syncComposing()
    }

    // MARK: 진동·소리

    /// 길게 누르기: 이만큼 누르고 있으면 반복을 시작하고, 이 간격으로 반복한다(지우기도 같다).
    static let repeatDelay: Duration = .milliseconds(320)
    static let repeatInterval: Duration = .milliseconds(50)

    /// iOS 기본 키보드와 같은 시스템 소리: 글자 / 지우기 / 기능 키.
    static let keySound: SystemSoundID = 1104
    static let deleteSound: SystemSoundID = 1155
    static let modifierSound: SystemSoundID = 1156

    private static func sound(for action: KeyAction) -> SystemSoundID {
        switch action {
        case .cheonjiin, .jamo, .character, .punctuation: keySound
        case .backspace: deleteSound
        default: modifierSound
        }
    }

    /// 진동과 소리를 먼저 — 문서 편집보다 앞서야 손끝 느낌이 늦지 않는다.
    /// 누르기·반복·지우기 모두 같은 세기로 울린다.
    private func feedback(_ sound: SystemSoundID) {
        // 키보드 익스텐션의 진동과 시스템 소리는 '전체 접근 허용'이 켜져 있을 때만 난다.
        // 소리는 무음 모드면 iOS가 알아서 끈다.
        if hapticsAllowed {
            haptic.impactOccurred()
            haptic.prepare()
            AudioServicesPlaySystemSound(sound)
        } else {
            UIDevice.current.playInputClick()
        }
    }
}
