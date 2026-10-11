import CheonjiinCore
import UIKit

/// 키보드 전체를 그리는 UIKit 뷰. 키는 그림만 그리고, 터치는 이 뷰가 한곳에서 받아
/// 손가락마다 어느 키인지 판정한다 — 시스템 키보드와 같은 방식이라 빠른 연타·겹친 터치에 강하다.
final class KeyboardView: UIView {
    /// 세로 화면의 줄 높이. 가로 화면(높이가 좁음)에서는 `compactRowHeight`.
    static let rowHeight: CGFloat = 48
    static let compactRowHeight: CGFloat = 34
    /// 키 둘레 3pt 틈과 합쳐 위아래 여백을 최소로.
    static let verticalPadding: CGFloat = 1
    static func height(rowHeight: CGFloat) -> CGFloat { rowHeight * 4 + verticalPadding * 2 }

    /// 컨트롤러가 화면 방향에 맞춰 정한다.
    var rowHeight = KeyboardView.rowHeight {
        didSet { if rowHeight != oldValue { builtLayer = nil; setNeedsLayout() } }
    }
    /// 천지인 오른쪽 기능 열(⌫ · .,?! · ↵)의 폭 — 글자 열 폭에 대한 비율.
    static let sideColumnRatio: CGFloat = 0.53

    private let model: KeyboardModel
    private var keys: [KeyView] = []
    private var builtLayer: Layer?
    private var builtPage = 0
    private var builtLandscape = false
    private var builtWidth: CGFloat = 0
    private var touches: [ObjectIdentifier: (key: KeyView, start: CGPoint)] = [:]

    init(model: KeyboardModel) {
        self.model = model
        super.init(frame: .zero)
        isMultipleTouchEnabled = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        if needsRebuild || builtWidth != bounds.width { rebuild() }
    }

    /// 모델 상태가 바뀌었을 때: 화면(레이어)이 바뀌었으면 다시 만들고, 아니면 키 표시만 고친다.
    func refresh() {
        overrideUserInterfaceStyle = model.forcedDark ? .dark : .unspecified
        if needsRebuild {
            setNeedsLayout()
            layoutIfNeeded()
        } else {
            keys.forEach { $0.update(model) }
        }
    }

    private var needsRebuild: Bool {
        builtLayer != model.layer || builtLandscape != model.landscape
            || (model.layer == .symbols && builtPage != model.symbolPage)
    }

    private func rebuild() {
        keys.forEach { $0.removeFromSuperview() }
        touches.removeAll()
        builtLayer = model.layer
        builtPage = model.symbolPage
        builtLandscape = model.landscape
        builtWidth = bounds.width
        keys = Self.layout(model.layer, page: model.symbolPage, letterLayer: model.letterLayer,
                           landscape: model.landscape, width: bounds.width, rowHeight: rowHeight).map { spec in
            let key = KeyView(spec: spec)
            addSubview(key)
            key.update(model)
            return key
        }
    }

    // MARK: 터치

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard let key = key(at: point) else { continue }
            self.touches[ObjectIdentifier(touch)] = (key, point)
            key.isPressed = true
            model.press(key.spec.action)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let entry = self.touches[ObjectIdentifier(touch)] else { continue }
            let point = touch.location(in: self)
            model.drag(entry.key.spec.action, dx: point.x - entry.start.x, dy: point.y - entry.start.y)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        finish(touches)
    }

    private func finish(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let entry = self.touches.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            entry.key.isPressed = false
            model.release(entry.key.spec.action)
        }
    }

    /// 키 칸 안이면 그 키, 틈이나 가장자리면 가장 가까운 키.
    private func key(at point: CGPoint) -> KeyView? {
        if let hit = keys.first(where: { $0.spec.cell.contains(point) }) { return hit }
        return keys.min { distance($0.spec.cell, point) < distance($1.spec.cell, point) }
    }

    private func distance(_ rect: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(rect.minX - p.x, 0, p.x - rect.maxX)
        let dy = max(rect.minY - p.y, 0, p.y - rect.maxY)
        return dx * dx + dy * dy
    }

    // MARK: 배치

    static func layout(_ layer: Layer, page: Int, letterLayer: Layer, landscape: Bool,
                       width: CGFloat, rowHeight: CGFloat) -> [KeySpec] {
        var specs: [KeySpec] = []
        let top = verticalPadding

        func add(_ action: KeyAction, _ content: KeyContent, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) {
            specs.append(KeySpec(action: action, content: content, cell: CGRect(x: x, y: y, width: w, height: h)))
        }

        switch layer {
        case .korean where landscape:
            // 가로 화면: 두벌식. 키가 낮아 천지인 4×4보다 일반 자판이 빠르다.
            let unit = width / 10
            let h = rowHeight
            func jamo(_ s: String, x: CGFloat, y: CGFloat) {
                for (i, ch) in s.enumerated() {
                    add(.jamo(ch), .letter(String(ch)), x + CGFloat(i) * unit, y, unit, h)
                }
            }
            jamo(Dubeolsik.rows[0], x: 0, y: top)
            jamo(Dubeolsik.rows[1], x: unit / 2, y: top + h)
            add(.shift, .shift, 0, top + h * 2, unit * 1.5, h)
            jamo(Dubeolsik.rows[2], x: unit * 1.5, y: top + h * 2)
            add(.backspace, .symbol("delete.left", 18), unit * 8.5, top + h * 2, unit * 1.5, h)
            let y = top + h * 3
            add(.layer(.symbols), .text("123", 15), 0, y, unit * 1.25, h)
            add(.globe, .text("한/A", 14), unit * 1.25, y, unit * 1.25, h)
            add(.space, .space, unit * 2.5, y, unit * 4.5, h)
            add(.punctuation, .text(".,?!", 16), unit * 7, y, unit, h)
            add(.enter, .symbol("arrow.turn.down.left", 18), unit * 8, y, unit * 2, h)

        case .korean:
            let column = width / (3 + sideColumnRatio)
            let h = rowHeight
            let grid: [[KeyAction]] = [
                [.cheonjiin(.vowel(.i)), .cheonjiin(.vowel(.dot)), .cheonjiin(.vowel(.eu))],
                [.cheonjiin(.consonant(.giyeok)), .cheonjiin(.consonant(.nieun)), .cheonjiin(.consonant(.digeut))],
                [.cheonjiin(.consonant(.bieup)), .cheonjiin(.consonant(.siot)), .cheonjiin(.consonant(.jieut))],
            ]
            for (r, row) in grid.enumerated() {
                for (c, action) in row.enumerated() {
                    add(action, .cheonjiin(action), CGFloat(c) * column, top + CGFloat(r) * h, column, h)
                }
            }
            let y = top + 3 * h
            add(.layer(.symbols), .text("123", 16), 0, y, column / 2, h)
            add(.globe, .text("한/A", 15), column / 2, y, column / 2, h)
            let ieung = KeyAction.cheonjiin(.consonant(.ieung))
            add(ieung, .cheonjiin(ieung), column, y, column, h)
            add(.space, .space, column * 2, y, column, h)
            let side = width - column * 3
            add(.backspace, .symbol("delete.left", 20), column * 3, top, side, h)
            add(.punctuation, .text(".,?!", 17), column * 3, top + h, side, h)
            add(.enter, .symbol("arrow.turn.down.left", 19), column * 3, top + h * 2, side, h * 2)

        case .english:
            let unit = width / 10
            let h = rowHeight
            func letters(_ s: String, x: CGFloat, y: CGFloat) {
                for (i, ch) in s.enumerated() {
                    add(.character(String(ch)), .letter(String(ch)), x + CGFloat(i) * unit, y, unit, h)
                }
            }
            letters("qwertyuiop", x: 0, y: top)
            letters("asdfghjkl", x: unit / 2, y: top + h)
            add(.shift, .shift, 0, top + h * 2, unit * 1.5, h)
            letters("zxcvbnm", x: unit * 1.5, y: top + h * 2)
            add(.backspace, .symbol("delete.left", 20), unit * 8.5, top + h * 2, unit * 1.5, h)
            let y = top + h * 3
            add(.layer(.symbols), .text("123", 16), 0, y, unit * 1.25, h)
            add(.globe, .text("한/A", 15), unit * 1.25, y, unit * 1.25, h)
            add(.space, .space, unit * 2.5, y, unit * 5.5, h)
            add(.enter, .symbol("arrow.turn.down.left", 19), unit * 8, y, unit * 2, h)

        case .symbols:
            // iOS 숫자 화면처럼 두 쪽. 1/2 키는 가/ABC 바로 위.
            let unit = width / 10
            let h = rowHeight
            let rows = page == 0
                ? ["1234567890", "-/:;()₩&@\""]
                : ["[]{}#%^*+=", "_\\|~<>$£¥•"]
            for (r, row) in rows.enumerated() {
                for (i, ch) in row.enumerated() {
                    let text = String(ch)
                    add(.character(text), .text(text, r == 0 && page == 0 ? 22 : 20), CGFloat(i) * unit, top + CGFloat(r) * h, unit, h)
                }
            }
            var y = top + h * 2
            add(.symbolPage, .text(page == 0 ? "1/2" : "2/2", 16), 0, y, unit * 1.5, h)
            for (i, ch) in ".,?!'".enumerated() {
                let text = String(ch)
                add(.character(text), .text(text, 20), unit * (1.5 + CGFloat(i) * 1.4), y, unit * 1.4, h)
            }
            add(.backspace, .symbol("delete.left", 20), unit * 8.5, y, unit * 1.5, h)
            y += h
            add(.layer(letterLayer), .text(letterLayer == .korean ? "가" : "ABC", 16), 0, y, unit * 2.5, h)
            add(.space, .space, unit * 2.5, y, unit * 5.5, h)
            add(.enter, .symbol("arrow.turn.down.left", 19), unit * 8, y, unit * 2, h)
        }
        return specs
    }
}

// MARK: - 키 한 칸

enum KeyContent {
    case text(String, CGFloat)
    /// 영문 글자 — 시프트에 따라 대소문자가 바뀐다.
    case letter(String)
    case symbol(String, CGFloat, UIImage.SymbolWeight = .regular)
    case cheonjiin(KeyAction)
    case space
    case shift
}

struct KeySpec {
    var action: KeyAction
    var content: KeyContent
    /// 터치 판정 칸(키 사이 틈 포함). 그려지는 키는 이보다 3pt씩 안쪽이다.
    var cell: CGRect
}

final class KeyView: UIView {
    let spec: KeySpec

    private static let normal = UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.24, green: 0.24, blue: 0.26, alpha: 1)
            : UIColor(red: 0.953, green: 0.953, blue: 0.961, alpha: 1)
    }
    private static let pressedColor = UIColor {
        $0.userInterfaceStyle == .dark
            ? UIColor(red: 0.36, green: 0.36, blue: 0.38, alpha: 1)
            : UIColor(red: 0.80, green: 0.81, blue: 0.84, alpha: 1)
    }

    private let content = UIView()
    private var label: UILabel?
    private var image: UIImageView?
    /// 간격 키 아래의 작은 → (조합 중일 때만 보인다).
    private var arrow: UIImageView?
    private var active = false

    var isPressed = false { didSet { if isPressed != oldValue { paint() } } }

    init(spec: KeySpec) {
        self.spec = spec
        super.init(frame: spec.cell.insetBy(dx: 3, dy: 3))
        isUserInteractionEnabled = false
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        content.frame = bounds
        content.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(content)
        build()
        paint()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func update(_ model: KeyboardModel) {
        switch spec.content {
        case .letter(let s):
            if model.shift == .off {
                label?.text = s
            } else if case .jamo(let c) = spec.action {
                label?.text = String(Dubeolsik.shifted(c))
            } else {
                label?.text = s.uppercased()
            }
        case .shift:
            image?.image = Self.symbol(model.shift == .locked ? "capslock.fill" : model.shift == .on ? "shift.fill" : "shift", 19)
            active = model.shift != .off
            paint()
        case .space:
            // 두벌식에서는 간격이 언제나 띄어쓰므로 → 표시가 없다.
            arrow?.alpha = model.composing && !model.isDubeolsik ? 1 : 0
        default:
            break
        }
    }

    private func paint() {
        backgroundColor = isPressed || active ? Self.pressedColor : Self.normal
    }

    private func build() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        switch spec.content {
        case .text(let s, let size):
            addLabel(s, size: size)
        case .letter(let s):
            addLabel(s, size: 21)
        case .symbol(let name, let size, let weight):
            addImage(Self.symbol(name, size, weight), center: center)
        case .shift:
            addImage(Self.symbol("shift", 19), center: center)
        case .space:
            addImage(Self.symbol("space", 19), center: CGPoint(x: center.x, y: center.y + 2))
            let arrow = UIImageView(image: Self.symbol("arrow.right", 10, .medium))
            arrow.tintColor = .label
            arrow.center = CGPoint(x: center.x, y: center.y + min(15, bounds.height * 0.32))
            arrow.alpha = 0
            content.addSubview(arrow)
            self.arrow = arrow
        case .cheonjiin(let action):
            guard case .cheonjiin(let input) = action else { break }
            switch input {
            case .consonant(let key):
                addLabel("\(key.cycle[0]) \(key.cycle[1])", size: 19)
            case .jamo(let c):
                addLabel(String(c), size: 19)
            case .vowel(let stroke):
                let size: CGSize = switch stroke {
                // 획 굵기는 옆 자음 글자(시스템 글꼴 19pt)의 획과 같게.
                case .i: CGSize(width: 1.3, height: 17)
                case .dot: CGSize(width: 3, height: 3)
                case .eu: CGSize(width: 17, height: 1.3)
                }
                let bar = UIView(frame: CGRect(origin: .zero, size: size))
                bar.center = center
                bar.backgroundColor = .label
                bar.layer.cornerRadius = stroke == .dot ? 1.5 : 0
                content.addSubview(bar)
            }
        }
    }

    private func addLabel(_ text: String, size: CGFloat) {
        let label = UILabel(frame: bounds)
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        label.text = text
        // 가로 화면의 낮은 키에서도 글자가 키 높이를 넘지 않게.
        label.font = .systemFont(ofSize: min(size, bounds.height * 0.62))
        label.textColor = .label
        label.textAlignment = .center
        content.addSubview(label)
        self.label = label
    }

    private func addImage(_ image: UIImage?, center: CGPoint) {
        let view = UIImageView(image: image)
        view.tintColor = .label
        view.center = center
        content.addSubview(view)
        self.image = view
    }

    private static func symbol(_ name: String, _ size: CGFloat, _ weight: UIImage.SymbolWeight = .regular) -> UIImage? {
        UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: weight))
    }
}
