import Cocoa

protocol AttributedStringConvertible {
    func attributedString(environment: Environment) -> [NSAttributedString]
}

struct Environment {
    var attributes = Attributes()
}

struct Attributes {
    var family: String = "Helvetica"
    var size: CGFloat = 14
    var traits: NSFontTraitMask = []
    var weight = 5
    var foregroundColor: NSColor = .textColor

    var bold: Bool {
        get {
            traits.contains(.boldFontMask)
        }
        set {
            if newValue {
                traits.insert(.boldFontMask)
            } else {
                traits.remove(.boldFontMask)
            }
        }
    }

    var dict: [NSAttributedString.Key: Any] {
        let fm = NSFontManager.shared
        let font = fm.font(withFamily: family, traits: traits, weight: weight, size: size)
        return [
            .font: font,
            .foregroundColor: foregroundColor
        ]
    }
}

extension String: AttributedStringConvertible {
    func attributedString(environment: Environment) -> [NSAttributedString] {
        [.init(string: self, attributes: environment.attributes.dict)]
    }
}

extension AttributedString: AttributedStringConvertible {
    func attributedString(environment: Environment) -> [NSAttributedString] {
        [.init(self)]
    }
}

extension NSAttributedString: AttributedStringConvertible {
    func attributedString(environment: Environment) -> [NSAttributedString] {
        [self]
    }
}

extension Array: AttributedStringConvertible where Element == AttributedStringConvertible {
    func attributedString(environment: Environment) -> [NSAttributedString] {
        flatMap { $0.attributedString(environment: environment) }
    }
}

@resultBuilder
struct AttributedStringBuilder {
    static func buildBlock(_ components: AttributedStringConvertible...) -> some AttributedStringConvertible {
        [components]
    }

    static func buildOptional<C: AttributedStringConvertible>(_ component: C?) -> some AttributedStringConvertible {
        component.map { [$0] } ?? []
    }
}

struct Joined<Content: AttributedStringConvertible>: AttributedStringConvertible {
    var separator: AttributedStringConvertible = "\n"
    @AttributedStringBuilder var content: Content

    func attributedString(environment: Environment) -> [NSAttributedString] {
        [single(environment: environment)]
    }

    func single(environment: Environment) -> NSAttributedString {
        let pieces = content.attributedString(environment: environment)
        guard let f = pieces.first else { return .init() }
        let result = NSMutableAttributedString(attributedString: f)
        let sep = separator.attributedString(environment: environment)
        for piece in pieces.dropFirst() {
            for sepPiece in sep {
                result.append(sepPiece)
            }
            result.append(piece)
        }
        return result
    }
}

extension AttributedStringConvertible {
    func joined(separator: AttributedStringConvertible = "\n") -> some AttributedStringConvertible {
        Joined(separator: separator, content: {
            self
        })
    }

    func run(environment: Environment) -> NSAttributedString {
        Joined(separator: "", content: {
            self
        }).single(environment: environment)
    }
}

struct Modify: AttributedStringConvertible {
    var modify: (inout Attributes) -> ()
    var contents: AttributedStringConvertible

    func attributedString(environment: Environment) -> [NSAttributedString] {
        var copy = environment
        modify(&copy.attributes)
        return contents.attributedString(environment: copy)
    }
}

extension AttributedStringConvertible {
    func bold() -> some AttributedStringConvertible {
        Modify(modify: { $0.bold = true }, contents: self)
    }

    func foregroundColor(_ color: NSColor) -> some AttributedStringConvertible {
        Modify(modify: { $0.foregroundColor = color }, contents: self)
    }
}

import SwiftHighlighting

extension String {
    func highlightSwift() -> NSAttributedString {
        .highlightSwift(self, stylesheet: .xcodeDefaultDark)
    }
}

#if DEBUG
@AttributedStringBuilder
var example: some AttributedStringConvertible {
    "Hello, World!"
        .bold()
    #"""
    static var previews: some View {
        let attStr = example
            .joined()
            .run(environment: .init(attributes: sampleAttributes))
        Text(AttributedString(attStr))
    }
    """#
        .highlightSwift()
    try! AttributedString(markdown: "Hello *world*")
}

import SwiftUI

let sampleAttributes = Attributes(family: "Tiempos Text", size: 20)

struct DebugPreview: PreviewProvider {
    static var previews: some View {
        let attStr = example
            .joined()
            .run(environment: .init(attributes: sampleAttributes))
        Text(AttributedString(attStr))
    }
}
#endif
