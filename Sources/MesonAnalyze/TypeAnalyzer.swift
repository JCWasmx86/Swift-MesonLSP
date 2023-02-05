import Glibc
import Logging
import MesonAST
import PathKit
import Timing

// TODO: Type derivation based on the options
public class TypeAnalyzer: ExtendedCodeVisitor {
  static let LOG = Logger(label: "MesonAnalyze::TypeAnalyzer")
  var scope: Scope
  var t: TypeNamespace?
  var tree: MesonTree
  var metadata: MesonMetadata
  let checkerState: CheckerState = CheckerState()
  let typeanalyzersState: TypeAnalyzersState = TypeAnalyzersState()
  let options: [MesonOption]
  var stack: [[String: [Type]]] = []
  var overriddenVariables: [[String: [Type]]] = []

  public init(parent: Scope, tree: MesonTree, options: [MesonOption]) {
    self.scope = parent
    self.tree = tree
    self.t = tree.ns
    self.options = options
    self.metadata = MesonMetadata()
  }

  deinit { self.t = nil }

  public func visitSubdirCall(node: SubdirCall) {
    let begin = clock()
    node.visitChildren(visitor: self)
    self.metadata.registerSubdirCall(call: node)
    let newPath = Path(
      Path(node.file.file).absolute().parent().description + "/" + node.subdirname + "/meson.build"
    ).description
    let subtree = self.tree.findSubdirTree(file: newPath)
    if let st = subtree {
      let tmptree = self.tree
      self.tree = st
      self.scope = Scope(parent: self.scope)
      subtree?.ast?.setParents()
      subtree?.ast?.parent = node
      subtree?.ast?.visit(visitor: self)
      self.tree = tmptree
    } else {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(
          sev: .error,
          node: node,
          message: "Unable to find subdir \(node.subdirname)"
        )
      )
      TypeAnalyzer.LOG.warning("Not found: \(node.subdirname)")
    }
    Timing.INSTANCE.registerMeasurement(name: "visitSubdirCall", begin: begin, end: clock())
  }

  public func applyToStack(_ name: String, _ types: [Type]) {
    if self.stack.isEmpty { return }
    let begin = clock()
    if self.scope.variables[name] != nil {
      if self.overriddenVariables[self.overriddenVariables.count - 1][name] == nil {
        self.overriddenVariables[self.overriddenVariables.count - 1][name] = self.scope.variables[
          name
        ]!
      } else {
        self.overriddenVariables[self.overriddenVariables.count - 1][name]! += self.scope.variables[
          name
        ]!
      }
    }
    if self.stack[self.stack.count - 1][name] == nil {
      self.stack[self.stack.count - 1][name] = types
    } else {
      self.stack[self.stack.count - 1][name]! += types
    }
    Timing.INSTANCE.registerMeasurement(name: "applyToStack", begin: begin, end: clock())
  }
  public func visitSourceFile(file: SourceFile) { file.visitChildren(visitor: self) }
  public func visitBuildDefinition(node: BuildDefinition) { node.visitChildren(visitor: self) }
  public func visitErrorNode(node: ErrorNode) {
    node.visitChildren(visitor: self)
    self.metadata.registerDiagnostic(
      node: node,
      diag: MesonDiagnostic(sev: .error, node: node, message: node.message)
    )
  }
  public func visitSelectionStatement(node: SelectionStatement) {
    let begin1 = clock()
    self.stack.append([:])
    self.overriddenVariables.append([:])
    node.visitChildren(visitor: self)
    let begin = clock()
    let types = self.stack.removeLast()
    for k in types.keys {
      // TODO: This leaks some overwritten types
      // x = 'Foo'
      // if bar
      //   x = 2
      // else
      //   x = true
      // endif
      // x is now str|int|bool instead of int|bool
      let l = dedup(types: (self.scope.variables[k] ?? []) + types[k]!)
      self.scope.variables[k] = l
    }
    self.overriddenVariables.removeLast()
    Timing.INSTANCE.registerMeasurement(
      name: "SelectionStatementTypeMerge",
      begin: begin,
      end: clock()
    )
    Timing.INSTANCE.registerMeasurement(
      name: "visitSelectionStatement",
      begin: begin1,
      end: clock()
    )
  }
  public func visitBreakStatement(node: BreakNode) { node.visitChildren(visitor: self) }
  public func visitContinueStatement(node: ContinueNode) { node.visitChildren(visitor: self) }
  public func visitIterationStatement(node: IterationStatement) {
    let begin = clock()
    node.expression.visit(visitor: self)
    for id in node.ids { id.visit(visitor: self) }
    let iterTypes = node.expression.types
    if node.ids.count == 1 {
      if iterTypes.count > 0 && iterTypes[0] is ListType {
        node.ids[0].types = (iterTypes[0] as! ListType).types
      } else if iterTypes.count > 0 && iterTypes[0] is RangeType {
        node.ids[0].types = [self.t!.types["int"]!]
      } else {
        node.ids[0].types = [`Any`()]
      }
      self.applyToStack((node.ids[0] as! IdExpression).id, node.ids[0].types)
      self.scope.variables[(node.ids[0] as! IdExpression).id] = node.ids[0].types
      self.checkIdentifier(node.ids[0] as! IdExpression)
    } else if node.ids.count == 2 {
      node.ids[0].types = [self.t!.types["str"]!]
      if let d = iterTypes.filter({ $0 is Dict }).first {
        node.ids[1].types = (d as! Dict).types
      } else {
        node.ids[1].types = []
      }
      self.applyToStack((node.ids[1] as! IdExpression).id, node.ids[0].types)
      self.applyToStack((node.ids[1] as! IdExpression).id, node.ids[0].types)
      self.scope.variables[(node.ids[1] as! IdExpression).id] = node.ids[1].types
      self.scope.variables[(node.ids[0] as! IdExpression).id] = node.ids[0].types
      self.checkIdentifier(node.ids[0] as! IdExpression)
      self.checkIdentifier(node.ids[1] as! IdExpression)
    }
    for b in node.block { b.visit(visitor: self) }
    Timing.INSTANCE.registerMeasurement(name: "visitIterationStatement", begin: begin, end: clock())
  }

  func checkIdentifier(_ node: IdExpression) {
    let begin = clock()
    if !isSnakeCase(str: node.id) {
      // TODO: For assignments, too
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(sev: .warning, node: node, message: "Expected snake case")
      )
    }
    Timing.INSTANCE.registerMeasurement(
      name: "checkIdentifier",
      begin: Int(begin),
      end: Int(clock())
    )
  }
  public func visitAssignmentStatement(node: AssignmentStatement) {
    let begin = clock()
    node.visitChildren(visitor: self)
    if node.op == .equals {
      var arr = node.rhs.types
      if arr.isEmpty && node.rhs is ArrayLiteral && (node.rhs as! ArrayLiteral).args.isEmpty {
        arr = [ListType(types: [])]
      }
      if arr.isEmpty && node.rhs is DictionaryLiteral
        && (node.rhs as! DictionaryLiteral).values.isEmpty
      {
        arr = [Dict(types: [])]
      }
      self.applyToStack((node.lhs as! IdExpression).id, arr)
      self.scope.variables[(node.lhs as! IdExpression).id] = arr
      (node.lhs as! IdExpression).types = arr
    } else {
      var newTypes: [Type] = []
      for l in node.lhs.types {
        for r in node.rhs.types {
          switch node.op {
          case .divequals:
            if l is `IntType` && r is `IntType` {
              newTypes.append(self.t!.types["int"]!)
            } else if l is Str && r is Str {
              newTypes.append(self.t!.types["str"]!)
            }
          case .minusequals:
            if l is `IntType` && r is `IntType` { newTypes.append(self.t!.types["int"]!) }
          case .modequals:
            if l is `IntType` && r is `IntType` { newTypes.append(self.t!.types["int"]!) }
          case .mulequals:
            if l is `IntType` && r is `IntType` { newTypes.append(self.t!.types["int"]!) }
          case .plusequals:
            if l is `IntType` && r is `IntType` {
              newTypes.append(self.t!.types["int"]!)
            } else if l is Str && r is Str {
              newTypes.append(self.t!.types["str"]!)
            } else if l is ListType && r is ListType {
              newTypes.append(
                ListType(types: dedup(types: (l as! ListType).types + (r as! ListType).types))
              )
            } else if l is ListType {
              newTypes.append(ListType(types: dedup(types: (l as! ListType).types + [r])))
            } else if l is Dict && r is Dict {
              newTypes.append(Dict(types: dedup(types: (l as! Dict).types + (r as! Dict).types)))
            } else if l is Dict {
              newTypes.append(Dict(types: dedup(types: (l as! Dict).types + [r])))
            }
          default: _ = 1
          }
        }
      }
      var deduped = dedup(types: newTypes)
      if deduped.isEmpty {
        if node.rhs.types.count == 0 && self.scope.variables[(node.lhs as! IdExpression).id] != nil
          && self.scope.variables[(node.lhs as! IdExpression).id]!.count != 0
        {
          deduped = dedup(types: self.scope.variables[(node.lhs as! IdExpression).id]!)
        }
      }
      (node.lhs as! IdExpression).types = deduped
      self.applyToStack((node.lhs as! IdExpression).id, deduped)
      self.scope.variables[(node.lhs as! IdExpression).id] = deduped
    }
    self.metadata.registerIdentifier(id: (node.lhs as! IdExpression))
    Timing.INSTANCE.registerMeasurement(
      name: "visitAssignmentStatement",
      begin: begin,
      end: clock()
    )
  }
  public func visitFunctionExpression(node: FunctionExpression) {
    let begin = clock()
    node.visitChildren(visitor: self)
    let funcName = (node.id as! IdExpression).id
    if let fn = self.t!.lookupFunction(name: funcName) {
      node.types = self.typeanalyzersState.apply(
        node: node,
        options: self.options,
        f: fn,
        ns: self.t!
      )
      if fn.name == "get_variable" && node.argumentList != nil, node.argumentList is ArgumentList {
        let args = (node.argumentList as! ArgumentList).args
        if args.count != 0 && args[0] is StringLiteral {
          let varname = (args[0] as! StringLiteral).contents()
          var types: [Type] = []
          if let sv = self.scope.variables[varname] {
            types += sv
          } else {
            types.append(self.t!.types["any"]!)
          }
          if args.count >= 2 { types += args[1].types }
          self.scope.variables[varname] = types
          self.applyToStack(varname, types)
          TypeAnalyzer.LOG.info("get_variable: \(varname) = \(self.joinTypes(types: types))")
        } else if args.count != 0 {
          var types: [Type] = [self.t!.types["any"]!]
          if args.count >= 2 { types += args[1].types }
          node.types = self.dedup(types: types)
          TypeAnalyzer.LOG.info("get_variable (Imprecise): ??? = \(self.joinTypes(types: types))")
        }
      } else if fn.name == "subdir" && node.argumentList != nil, node.argumentList is ArgumentList {
        if (node.argumentList as! ArgumentList).args[0] is StringLiteral {
          let sl = (node.argumentList as! ArgumentList).args[0] as! StringLiteral
          let s = sl.contents()
          self.metadata.registerDiagnostic(
            node: node,
            diag: MesonDiagnostic(sev: .error, node: node, message: s + "/meson.build not found")
          )
        }
      }
      node.function = fn
      self.metadata.registerFunctionCall(call: node)
      checkerState.apply(node: node, metadata: self.metadata, f: fn)
      if let args = node.argumentList, args is ArgumentList {
        self.checkCall(node: node)
      } else if node.argumentList == nil {
        if node.function!.minPosArgs() != 0 {
          self.metadata.registerDiagnostic(
            node: node,
            diag: MesonDiagnostic(
              sev: .error,
              node: node,
              message: "Expected " + String(node.function!.minPosArgs())
                + " positional arguments, but got none!"
            )
          )
        }
      }
      if node.argumentList != nil, node.argumentList is ArgumentList {
        for a in (node.argumentList as! ArgumentList).args where a is KeywordItem {
          self.metadata.registerKwarg(item: a as! KeywordItem, f: fn)
        }
        if node.function!.name == "set_variable" {
          let args = (node.argumentList as! ArgumentList).args
          if args.count > 1 && args[0] is StringLiteral {
            let varname = (args[0] as! StringLiteral).contents()
            let types = args[1].types
            self.scope.variables[varname] = types
            self.applyToStack(varname, types)
            TypeAnalyzer.LOG.info("set_variable: \(varname) = \(self.joinTypes(types: types))")
          }
        }
      }
    } else {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(sev: .error, node: node, message: "Unknown function \(funcName)")
      )
    }
    Timing.INSTANCE.registerMeasurement(name: "visitFunctionExpression", begin: begin, end: clock())
  }
  public func visitArgumentList(node: ArgumentList) { node.visitChildren(visitor: self) }
  public func visitKeywordItem(node: KeywordItem) { node.visitChildren(visitor: self) }
  public func visitConditionalExpression(node: ConditionalExpression) {
    node.visitChildren(visitor: self)
    node.types = dedup(types: node.ifFalse.types + node.ifTrue.types)
  }
  public func visitUnaryExpression(node: UnaryExpression) {
    node.visitChildren(visitor: self)
    switch node.op! {
    case .minus: node.types = [self.t!.types["int"]!]
    case .not, .exclamationMark: node.types = [self.t!.types["bool"]!]
    }
  }
  public func visitSubscriptExpression(node: SubscriptExpression) {
    node.visitChildren(visitor: self)
    var newTypes: [Type] = []
    for t in node.outer.types {
      if t is Dict {
        newTypes += (t as! Dict).types
      } else if t is ListType {
        newTypes += (t as! ListType).types
      } else if t is Str {
        newTypes += [self.t!.types["str"]!]
      } else if t is CustomTgt {
        newTypes += [self.t!.types["custom_idx"]!]
      }
    }
    node.types = dedup(types: newTypes)
  }
  // TODO: In 2.0 fix this by making all types
  // classes
  func verify(types: [Type]) -> [Type] {
    let begin = clock()
    let deduped = dedup(types: types)
    var ret: [Type] = []
    for d in deduped {
      if d is AbstractObject {
        ret += [self.t!.types[d.name]!]
      } else if d is Dict {
        ret += [Dict(types: verify(types: (d as! Dict).types))]
      } else if d is ListType {
        ret += [ListType(types: verify(types: (d as! ListType).types))]
      } else {
        ret += [d]
      }
    }
    Timing.INSTANCE.registerMeasurement(name: "verify", begin: begin, end: clock())
    return ret
  }
  public func visitMethodExpression(node: MethodExpression) {
    let begin = clock()
    node.visitChildren(visitor: self)
    let types = node.obj.types
    var ownResultTypes: [Type] = []
    var found = false
    let methodName = (node.id as! IdExpression).id
    var nAny = 0
    for t in types {
      if t is `Any` {
        nAny += 1
        continue
      }
      if let m = t.getMethod(name: methodName) {
        ownResultTypes += verify(
          types: self.typeanalyzersState.apply(node: node, options: self.options, f: m, ns: self.t!)
        )
        node.method = m
        self.metadata.registerMethodCall(call: node)
        found = true
        checkerState.apply(node: node, metadata: self.metadata, f: m)
      }
    }
    node.types = dedup(types: ownResultTypes)
    if !found && nAny == types.count {
      let begin = clock()
      let guessedMethod = self.t!.lookupMethod(name: methodName)
      Timing.INSTANCE.registerMeasurement(name: "guessingMethod", begin: begin, end: clock())
      if let guessedM = guessedMethod {
        TypeAnalyzer.LOG.info(
          "Guessed method \(guessedM.id()) at \(node.file.file)\(node.location.format())"
        )
        ownResultTypes += self.typeanalyzersState.apply(
          node: node,
          options: self.options,
          f: guessedM,
          ns: self.t!
        )
        node.method = guessedM
        self.metadata.registerMethodCall(call: node)
        found = true
        checkerState.apply(node: node, metadata: self.metadata, f: guessedM)
      }
    }
    if !found {
      let t = joinTypes(types: types)
      for tt in types {
        TypeAnalyzer.LOG.info("\(tt.name)::\(tt.methods.count)")
        for m in tt.methods { TypeAnalyzer.LOG.info("\(tt.name)::\(m.name)") }
      }
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(
          sev: .error,
          node: node,
          message: "No method \(methodName) found for types `\(t)'"
        )
      )
    } else {
      if let args = node.argumentList, args is ArgumentList {
        self.checkCall(node: node)
      } else if node.argumentList == nil {
        if node.method!.minPosArgs() != 0 {
          self.metadata.registerDiagnostic(
            node: node,
            diag: MesonDiagnostic(
              sev: .error,
              node: node,
              message: "Expected " + String(node.method!.minPosArgs())
                + " positional arguments, but got none!"
            )
          )
        }
      }
      if node.argumentList != nil, node.argumentList is ArgumentList {
        for a in (node.argumentList as! ArgumentList).args where a is KeywordItem {
          self.metadata.registerKwarg(item: a as! KeywordItem, f: node.method!)
        }
      }
    }
    Timing.INSTANCE.registerMeasurement(name: "visitMethodExpression", begin: begin, end: clock())
  }

  func checkCall(node: Expression) {
    let begin = clock()
    let args: [Node]
    let fn: Function
    if node is FunctionExpression {
      fn = (node as! FunctionExpression).function!
      args = ((node as! FunctionExpression).argumentList! as! ArgumentList).args
    } else {
      fn = (node as! MethodExpression).method!
      args = ((node as! MethodExpression).argumentList! as! ArgumentList).args
    }
    var kwargsOnly = false
    for arg in args {
      if kwargsOnly {
        if arg is KeywordItem { continue }
        self.metadata.registerDiagnostic(
          node: arg,
          diag: MesonDiagnostic(
            sev: .error,
            node: arg,
            message: "Unexpected positional argument after a keyword argument"
          )
        )
        continue
      } else if arg is KeywordItem {
        kwargsOnly = true
      }
    }
    var nKwargs = 0
    var nPos = 0
    for arg in args { if arg is KeywordItem { nKwargs += 1 } else { nPos += 1 } }
    if nPos < fn.minPosArgs() {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(
          sev: .error,
          node: node,
          message: "Expected " + String(fn.minPosArgs()) + " positional arguments, but got "
            + String(nPos) + "!"
        )
      )
    }
    if nPos > fn.maxPosArgs() {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(
          sev: .error,
          node: node,
          message: "Expected " + String(fn.maxPosArgs()) + " positional arguments, but got "
            + String(nPos) + "!"
        )
      )
    }
    var usedKwargs: [String: KeywordItem] = [:]
    for arg in args where arg is KeywordItem {
      let k = (arg as! KeywordItem).key
      if let kId = k as? IdExpression {
        usedKwargs[kId.id] = (arg as! KeywordItem)
        // TODO: What is this kwargs kwarg? Can it be applied everywhere?
        if !fn.hasKwarg(name: kId.id) && kId.id != "kwargs" {
          self.metadata.registerDiagnostic(
            node: arg,
            diag: MesonDiagnostic(
              sev: .error,
              node: arg,
              message: "Unknown key word argument '" + kId.id + "'!"
            )
          )
        }
      }
    }
    for requiredKwarg in fn.requiredKwargs() where usedKwargs[requiredKwarg] == nil {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(
          sev: .error,
          node: node,
          message: "Missing required key word argument '" + requiredKwarg + "'!"
        )
      )
    }
    // TODO: Type checking for each argument
    Timing.INSTANCE.registerMeasurement(name: "checkCall", begin: Int(begin), end: Int(clock()))
  }

  public func evalStack(name: String) -> [Type] {
    var ret: [Type] = []
    for ov in self.overriddenVariables where ov[name] != nil { ret += ov[name]! }
    return ret
  }
  public func visitIdExpression(node: IdExpression) {
    let begin = clock()
    let s = self.evalStack(name: node.id)
    Timing.INSTANCE.registerMeasurement(name: "evalStack", begin: begin, end: clock())
    node.types = dedup(types: s + (scope.variables[node.id] ?? []))
    node.visitChildren(visitor: self)
    if (node.parent is FunctionExpression
      && (node.parent as! FunctionExpression).id.equals(right: node))
      || (node.parent is MethodExpression
        && (node.parent as! MethodExpression).id.equals(right: node))
    {
      return
    } else if node.parent is KeywordItem && (node.parent as! KeywordItem).key.equals(right: node) {
      return
    }
    if !isKnownId(id: node) {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(sev: .error, node: node, message: "Unknown identifier")
      )
    }
    self.metadata.registerIdentifier(id: node)
  }

  func isKnownId(id: IdExpression) -> Bool {
    if let a = id.parent as? AssignmentStatement, let b = a.lhs as? IdExpression {
      if b.id == id.id && a.op == .equals { return true }
    } else if let i = id.parent as? IterationStatement {
      for idd in i.ids { if let l = idd as? IdExpression, id.id == l.id { return true } }
    } else if let kw = id.parent as? KeywordItem, let b = kw.key as? IdExpression {
      if id.id == b.id { return true }
    } else if let fe = id.parent as? FunctionExpression, let b = fe.id as? IdExpression {
      if id.id == b.id { return true }
    } else if let me = id.parent as? MethodExpression, let b = me.id as? IdExpression {
      if id.id == b.id { return true }
    }

    return self.scope.variables[id.id] != nil
  }

  func isType(_ type: Type, _ name: String) -> Bool {
    return type.name == name || type.name == "any"
  }
  public func visitBinaryExpression(node: BinaryExpression) {
    let begin = clock()
    node.visitChildren(visitor: self)
    var newTypes: [Type] = []
    if node.op == nil {
      // Emergency fix
      node.types = dedup(types: node.lhs.types + node.rhs.types)
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(sev: .error, node: node, message: "Missing binary operator")
      )
      Timing.INSTANCE.registerMeasurement(name: "visitBinaryExpression", begin: begin, end: clock())
      return
    }
    var nErrors = 0
    let nTimes = node.lhs.types.count * node.rhs.types.count
    for l in node.lhs.types {
      for r in node.rhs.types {
        // Theoretically not an error (yet),
        // but practically better safe than sorry.
        if r.name == "any" && l.name == "any" {
          nErrors += 1
          continue
        }
        switch node.op! {
        case .and, .or:
          if isType(l, "bool") && isType(r, "bool") {
            newTypes.append(self.t!.types["bool"]!)
          } else {
            nErrors += 1
          }
        case .div:
          if isType(l, "int") && isType(r, "int") {
            newTypes.append(self.t!.types["int"]!)
          } else if isType(l, "str") && isType(r, "str") {
            newTypes.append(self.t!.types["str"]!)
          } else {
            nErrors += 1
          }
        case .equalsEquals:
          if isType(l, "int") && isType(r, "int") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "str") && isType(r, "str") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "bool") && isType(r, "bool") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "dict") && isType(r, "dict") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "list") && isType(r, "list") {
            newTypes.append(self.t!.types["bool"]!)
          } else {
            nErrors += 1
          }
        case .ge, .gt, .le, .lt:
          if isType(l, "int") && isType(r, "int") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "str") && isType(r, "str") {
            newTypes.append(self.t!.types["bool"]!)
          } else {
            nErrors += 1
          }
        case .IN: newTypes.append(self.t!.types["bool"]!)
        case .minus, .modulo, .mul:
          if isType(l, "int") && isType(r, "int") {
            newTypes.append(self.t!.types["int"]!)
          } else {
            nErrors += 1
          }
        case .notEquals:
          if isType(l, "int") && isType(r, "int") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "str") && isType(r, "str") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "bool") && isType(r, "bool") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "dict") && isType(r, "dict") {
            newTypes.append(self.t!.types["bool"]!)
          } else if isType(l, "list") && isType(r, "list") {
            newTypes.append(self.t!.types["bool"]!)
          } else {
            nErrors += 1
          }
        case .notIn: newTypes.append(self.t!.types["bool"]!)
        case .plus:
          if isType(l, "int") && isType(r, "int") {
            newTypes.append(self.t!.types["int"]!)
          } else if isType(l, "str") && isType(r, "str") {
            newTypes.append(self.t!.types["str"]!)
          } else if l is ListType && r is ListType {
            newTypes.append(
              ListType(types: dedup(types: (l as! ListType).types + (r as! ListType).types))
            )
          } else if l is ListType {
            newTypes.append(ListType(types: dedup(types: (l as! ListType).types + [r])))
          } else if l is Dict && r is Dict {
            newTypes.append(Dict(types: dedup(types: (l as! Dict).types + (r as! Dict).types)))
          } else if l is Dict {
            newTypes.append(Dict(types: dedup(types: (l as! Dict).types + [r])))
          } else {
            nErrors += 1
          }
        }
      }
    }
    if nTimes != 0 && nErrors == nTimes && (!node.lhs.types.isEmpty) && (!node.rhs.types.isEmpty) {
      self.metadata.registerDiagnostic(
        node: node,
        diag: MesonDiagnostic(
          sev: .error,
          node: node,
          message:
            "Unable to apply operator `\(node.op!)` to types \(self.joinTypes(types: node.lhs.types)) and \(self.joinTypes(types: node.rhs.types))"
        )
      )
    }
    node.types = dedup(types: newTypes)
    Timing.INSTANCE.registerMeasurement(name: "visitBinaryExpression", begin: begin, end: clock())
  }
  public func visitStringLiteral(node: StringLiteral) {
    node.types = [self.t!.types["str"]!]
    node.visitChildren(visitor: self)
  }
  public func visitArrayLiteral(node: ArrayLiteral) {
    node.visitChildren(visitor: self)
    var t: [Type] = []
    for elem in node.args { t += elem.types }
    node.types = [ListType(types: dedup(types: t))]
  }
  public func visitBooleanLiteral(node: BooleanLiteral) {
    node.types = [self.t!.types["bool"]!]
    node.visitChildren(visitor: self)
  }
  public func visitIntegerLiteral(node: IntegerLiteral) {
    node.types = [self.t!.types["int"]!]
    node.visitChildren(visitor: self)
  }
  public func visitDictionaryLiteral(node: DictionaryLiteral) {
    node.visitChildren(visitor: self)
    var t: [Type] = []
    for elem in node.values { t += elem.types }
    node.types = [Dict(types: dedup(types: t))]
  }
  public func visitKeyValueItem(node: KeyValueItem) {
    node.visitChildren(visitor: self)
    node.types = node.value.types
  }

  func isSnakeCase(str: String) -> Bool {
    for s in str where s.isUppercase { return false }
    return true
  }

  public func joinTypes(types: [Type]) -> String {
    return types.map({ $0.toString() }).joined(separator: "|")
  }

  public func dedup(types: [Type]) -> [Type] {
    if types.count == 0 { return types }
    let begin = clock()
    var listtypes: [Type] = []
    var dicttypes: [Type] = []
    var hasAny: Bool = false
    var hasBool: Bool = false
    var hasInt: Bool = false
    var hasStr: Bool = false
    var objs: [String: Type] = [:]
    var gotList: Bool = false
    var gotDict: Bool = false
    for t in types {
      if t is `Any` { hasAny = true }
      if t is BoolType {
        hasBool = true
      } else if t is `IntType` {
        hasInt = true
      } else if t is Str {
        hasStr = true
      } else if t is Dict {
        dicttypes += (t as! Dict).types
        gotDict = true
      } else if t is ListType {
        listtypes += (t as! ListType).types
        gotList = true
      } else {
        objs[t.name] = t
      }
    }
    var ret: [Type] = []
    if listtypes.count != 0 || gotList { ret.append(ListType(types: dedup(types: listtypes))) }
    if dicttypes.count != 0 || gotDict { ret.append(Dict(types: dedup(types: dicttypes))) }
    if hasAny { ret.append(self.t!.types["any"]!) }
    if hasBool { ret.append(self.t!.types["bool"]!) }
    if hasInt { ret.append(self.t!.types["int"]!) }
    if hasStr { ret.append(self.t!.types["str"]!) }
    ret += objs.values
    Timing.INSTANCE.registerMeasurement(name: "dedup", begin: begin, end: clock())
    return ret
  }
}
