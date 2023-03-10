import Foundation
import SwiftTreeSitter

// There seem to be some name collisions
public typealias MesonVoid = ()

extension SwiftTreeSitter.Node {
  public func enumerateNamedChildren(block: (SwiftTreeSitter.Node) -> MesonVoid) {
    for i in 0..<namedChildCount {
      let n = namedChild(at: i)!
      block(n)
    }
  }
}

func string_value(file: MesonSourceFile, node: SwiftTreeSitter.Node) -> String {
  if let text = try? file.contents() {
    return text.substring(with: node.range).trimmingCharacters(in: .whitespacesAndNewlines)
  }
  return ""
}
