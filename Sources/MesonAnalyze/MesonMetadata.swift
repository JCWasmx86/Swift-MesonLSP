import MesonAST

public class MesonMetadata {
  public var subdirCalls: [String: [SubdirCall]] = [:]
  public var methodCalls: [String: [MethodExpression]] = [:]
  public var functionCalls: [String: [FunctionExpression]] = [:]
  public var identifiers: [String: [IdExpression]] = [:]
  public var kwargs: [String: [(KeywordItem, Function)]] = [:]
  public var diagnostics: [String: [MesonDiagnostic]] = [:]

  public init() {}

  public func registerSubdirCall(call: SubdirCall) {
    if self.subdirCalls[call.file.file] == nil {
      self.subdirCalls.updateValue([call], forKey: call.file.file)
    } else {
      self.subdirCalls[call.file.file]!.append(call)
    }
  }

  public func registerDiagnostic(node: Node, diag: MesonDiagnostic) {
    if self.diagnostics[node.file.file] == nil {
      self.diagnostics.updateValue([diag], forKey: node.file.file)
    } else {
      self.diagnostics[node.file.file]!.append(diag)
    }
  }

  public func registerMethodCall(call: MethodExpression) {
    if self.methodCalls[call.file.file] == nil {
      self.methodCalls.updateValue([call], forKey: call.file.file)
    } else {
      self.methodCalls[call.file.file]!.append(call)
    }
  }

  public func registerFunctionCall(call: FunctionExpression) {
    if self.functionCalls[call.file.file] == nil {
      self.functionCalls.updateValue([call], forKey: call.file.file)
    } else {
      self.functionCalls[call.file.file]!.append(call)
    }
  }

  public func registerIdentifier(id: IdExpression) {
    if self.identifiers[id.file.file] == nil {
      self.identifiers.updateValue([id], forKey: id.file.file)
    } else {
      self.identifiers[id.file.file]!.append(id)
    }
  }

  public func registerKwarg(item: KeywordItem, f: Function) {
    if self.kwargs[item.file.file] == nil {
      self.kwargs.updateValue([(item, f)], forKey: item.file.file)
    } else {
      self.kwargs[item.file.file]!.append((item, f))
    }
  }

  func contains(_ node: Node, _ line: Int, _ column: Int) -> Bool {
    if node.location.startLine <= line && node.location.endLine >= line {
      if node.location.startColumn <= column && node.location.endColumn >= column { return true }
    }
    return false
  }

  public func findMethodCallAt(_ path: String, _ line: Int, _ column: Int) -> MethodExpression? {
    if let arr = self.methodCalls[path] {
      for m in arr where self.contains(m.id, line, column) { return m }
    }
    return nil
  }

  public func findFullMethodCallAt(_ path: String, _ line: Int, _ column: Int) -> MethodExpression?
  {
    if let arr = self.methodCalls[path] {
      for m in arr where self.contains(m, line, column) { return m }
    }
    return nil
  }

  public func findFunctionCallAt(_ path: String, _ line: Int, _ column: Int) -> FunctionExpression?
  {
    if let arr = self.functionCalls[path] {
      for f in arr where self.contains(f.id, line, column) { return f }
    }
    return nil
  }

  public func findFullFunctionCallAt(_ path: String, _ line: Int, _ column: Int)
    -> FunctionExpression?
  {
    if let arr = self.functionCalls[path] {
      for f in arr where self.contains(f, line, column) { return f }
    }
    return nil
  }

  public func findIdentifierAt(_ path: String, _ line: Int, _ column: Int) -> IdExpression? {
    if let arr = self.identifiers[path] {
      for i in arr where self.contains(i, line, column) { return i }
    }
    return nil
  }

  public func findSubdirCallAt(_ path: String, _ line: Int, _ column: Int) -> SubdirCall? {
    if let arr = self.subdirCalls[path] {
      for f in arr where self.contains(f.id, line, column) { return f }
    }
    return nil
  }
  public func findKwargAt(_ path: String, _ line: Int, _ column: Int) -> (KeywordItem, Function)? {
    if let arr = self.kwargs[path] {
      for f in arr where self.contains(f.0.key, line, column) { return f }
    }
    return nil
  }
}
