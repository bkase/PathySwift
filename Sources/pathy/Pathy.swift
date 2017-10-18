// why is this not in the std lib
enum Either<A, B> {
    case left(A)
    case right(B)
    
    var asLeft: A? {
        switch self {
        case let .left(a): return a
        case .right(_): return nil
        }
    }
    
    var asRight: B? {
        switch self {
        case .left(_): return nil
        case let .right(b): return b
        }
    }
    
    func fold<C>(left: (A) -> C, right: (B) -> C) -> C {
        switch self {
        case let .left(x): return left(x)
        case let .right(x): return right(x)
        }
    }
}

public struct FileName { let s: String; public init(_ s: String) { self.s = s}; public init(stringLiteral s: String) { self.s = s } }
extension FileName: ExpressibleByStringLiteral, Equatable {
    public static func ==(lhs: FileName, rhs: FileName) -> Bool {
        return lhs.s == rhs.s
    }
}
public struct DirName { let s: String; public init(_ s: String) { self.s = s}; public init(stringLiteral s: String) { self.s = s } }
extension DirName: ExpressibleByStringLiteral, Equatable {
    public static func ==(lhs: DirName, rhs: DirName) -> Bool {
        return lhs.s == rhs.s
    }
}

public protocol PathKind {}
public enum Absolute: PathKind {}
public enum Relative: PathKind {}

public protocol FileType {}
public enum Directory: FileType {}
public enum File: FileType {}

public enum Unknown: PathKind, FileType {}

// invariant: These are only constructed via the static builders
indirect enum _Path<K: PathKind, T: FileType> {
    case _root
    case _current
    case fileIn(_Path<K, T>, FileName)
    case dirIn(_Path<K, T>, DirName)
    case parentIn(_Path<K, T>)
}


extension _Path {
    private func getDescription(first: Bool) -> String {
        switch self {
        case ._root where first:
            return "/"
        case ._root:
            return ""
        case ._current:
            return "."
        case let .fileIn(p, name):
            return p.getDescription(first: false) + "/" + name.s
        case let .dirIn(p, name):
            return p.getDescription(first: false) + "/" + name.s
        case let .parentIn(p):
            return p.getDescription(first: false) + "/.."
        }
    }
    var description: String {
        return getDescription(first: true)
    }
}

// we use a public struct wrapper to hide the implementation details for the _Path enum
public struct Path<K: PathKind, T: FileType> {
    let p: _Path<K, T>
    
    init(_ p: _Path<K, T>) {
        self.p = p
    }
}

extension Path {
  var description: String {
    return p.description
  }
}

/**
 * Returns a path to a file if possible, fails if:
 * 1. The string is empty
 * 2. You just passed a `/`
 * 3. The last path component is a . or a ..
 *
 */
public func path(rawFile: String) -> Path<Unknown, File>? {
    return _path(rawFile: rawFile).map{ Path($0) }
}
func _path(rawFile: String) -> _Path<Unknown, File>? {
    
    // TODO: Does this need to be smarter?
    guard rawFile.count > 0 else { return nil }
    
    let allChunks = rawFile.split(separator: "/").map { String($0) }
    guard let lastChunk = allChunks.last, lastChunk != "." && lastChunk != ".." else { return nil }
  
    let headChunks = allChunks.dropLast()
    let prefix = Array(headChunks.reversed())
        .filter{ $0 != "" }
        .reduce(rawFile.characters.first == "/" ? ._root : ._current) { (path: _Path<Unknown, File>, chunk: String) -> _Path<Unknown, File> in
            switch chunk {
            case chunk where chunk == ".":
                return path
            case chunk where chunk == "..":
                return .parentIn(path)
            default:
                return .dirIn(path, DirName(chunk))
            }
    }
    return .fileIn(prefix, FileName(lastChunk))
    
}

/**
 * Returns a path to a directory if possible, fails if:
 * 1. The input is empty
 */
public func path(rawDir: String) -> Path<Unknown, Directory>? {
    return _path(rawDir: rawDir).map{ Path($0) }
}
func _path(rawDir: String) -> _Path<Unknown, Directory>? {
    guard rawDir.count > 0 else { return nil }
    if rawDir == "/" { return ._root }
    
    let chunks = rawDir.split(separator: "/").map { String($0) }
    
    return chunks
        .filter{ $0 != "" }
        .reduce(rawDir.characters.first == "/" ? ._root : ._current) { (path: _Path<Unknown, Directory>, chunk: String) -> _Path<Unknown, Directory> in
            switch chunk {
            case chunk where chunk == ".":
                return path
            case chunk where chunk == "..":
                return .parentIn(path)
            default:
                return .dirIn(path, DirName(chunk))
            }
    }
}

extension Path: Equatable {
    public static func ==(lhs: Path<K, T>, rhs: Path<K, T>) -> Bool {
        return lhs.p == rhs.p
    }
}
extension _Path: Equatable {
    static func ==(lhs: _Path<K, T>, rhs: _Path<K, T>) -> Bool {
        switch (lhs, rhs) {
        case (._root, ._root), (._current, ._current): return true
        case let (.fileIn(p1, n1), .fileIn(p2, n2)):
            return p1 == p2 && n1 == n2
        case let (.dirIn(p1, n1), .dirIn(p2, n2)):
            return p1 == p2 && n1 == n2
        case let (.parentIn(p1), .parentIn(p2)):
            return p1 == p2
        case (.parentIn(_), ._root),
         (.parentIn(_), ._current),
        (.parentIn(_), .fileIn(_, _)),
        (.parentIn(_), .dirIn(_, _)),
        (.dirIn(_, _), ._root),
        (.dirIn(_, _), ._current),
        (.dirIn(_, _), .fileIn(_, _)),
        (.dirIn(_, _), .parentIn(_)),
        (.fileIn(_, _), ._root),
        (.fileIn(_, _), ._current),
        (.fileIn(_, _), .dirIn(_, _)),
        (.fileIn(_, _), .parentIn(_)),
        (._current, ._root),
        (._current, .fileIn(_, _)),
        (._current, .dirIn(_, _)),
        (._current, .parentIn(_)),
        (._root, ._current),
        (._root, .fileIn(_, _)),
        (._root, .dirIn(_, _)),
        (._root, .parentIn(_)): return false
        }
    }
}

extension Path where K == Unknown {
    var proveKind: Either<Path<Absolute, T>, Path<Relative, T>> {
        switch p.proveKind {
        case let .left(absolute):
            return .left(Path<Absolute, T>(absolute))
        case let .right(relative):
            return .right(Path<Relative, T>(relative))
        }
    }
    var absolute: Path<Absolute, T>? {
        return p.absolute.map{ Path<Absolute, T>($0) }
    }
    var relative: Path<Relative, T>? {
        return p.relative.map { Path<Relative, T>($0) }
    }
}
extension _Path where K == Unknown {
    var proveKind: Either<_Path<Absolute, T>, _Path<Relative, T>> {
        switch self {
        case ._current:
            return .right(._current)
        case ._root:
            return .left(._root)
        case let .dirIn(p1, name):
            // TODO: Swift chokes when I try to use Fold here
            switch p1.proveKind {
            case let .left(absolute):
                return .left(.dirIn(absolute, name))
            case let .right(relative):
                return .right(.dirIn(relative, name))
            }
        case let .fileIn(p1, name):
            switch p1.proveKind {
            case let .left(absolute):
                return .left(.fileIn(absolute, name))
            case let .right(relative):
                return .right(.fileIn(relative, name))
            }
        case let .parentIn(p1):
            switch p1.proveKind {
            case let .left(absolute):
                return .left(.parentIn(absolute))
            case let .right(relative):
                return .right(.parentIn(relative))
            }
        }
    }
    
    var absolute: _Path<Absolute, T>? {
        return proveKind.asLeft
    }
    var relative: _Path<Relative, T>? {
        return proveKind.asRight
    }
}

extension Path where T == Unknown {
    var proveType: Either<Path<K, File>, Path<K, Directory>> {
        switch p.proveType {
        case let .left(file):
            return .left(Path<K, File>(file))
        case let .right(dir):
            return .right(Path<K, Directory>(dir))
        }
    }
    var file: Path<K, File>? {
        return p.file.map { Path<K, File>($0) }
    }
    var directory: Path<K, Directory>? {
        return p.directory.map{ Path<K, Directory>($0) }
    }
}
// TODO: This may never be needed
extension _Path where T == Unknown {
    // This is pretty hacky:
    // we know at the first step whether we have a file or a directory, but we can't coerce the recursive part
    // so we have to recurse and recreate each node with some
    // extra knowledge about which branch to take
    var proveType: Either<_Path<K, File>, _Path<K, Directory>> {
        func loop(isLeft: Bool, path: _Path<K, Unknown>) ->  Either<_Path<K, File>, _Path<K, Directory>> {
            switch path {
            case ._current:
                return isLeft ? .left(._current) : .right(._current)
            case ._root:
                return isLeft ? .left(._root) : .right(._root)
            case let .dirIn(p1, name):
                switch loop(isLeft: isLeft, path: p1) {
                case let .left(file):
                    return .left(.dirIn(file, name))
                case let .right(dir):
                    return .right(.dirIn(dir, name))
                }
            case let .fileIn(p1, name):
                switch loop(isLeft: isLeft, path: p1) {
                case let .left(file):
                    return .left(.fileIn(file, name))
                case let .right(dir):
                    return .right(.fileIn(dir, name))
                }
            case let .parentIn(p1):
                switch loop(isLeft: isLeft, path: p1) {
                case let .left(file):
                    return .left(.parentIn(file))
                case let .right(dir):
                    return .right(.parentIn(dir))
                }
            }
        }
        switch self {
        case ._current:
            return .right(._current)
        case ._root:
            return .right(._root)
        case let .dirIn(p, name):
            switch loop(isLeft: false, path: p) {
            case .left(_): fatalError("Unreachable")
            case let .right(dir): return .right(.dirIn(dir, name))
            }
        case let .fileIn(p, name):
            switch loop(isLeft: true, path: p) {
            case let .left(file): return .left(.fileIn(file, name))
            case .right(_): fatalError("Unreachable")
            }
        case let .parentIn(p):
            switch loop(isLeft: false, path: p) {
            case .left(_): fatalError("Unreachable")
            case let .right(dir): return .right(.parentIn(dir))
            }
        }
    }
    
    var file: _Path<K, File>? {
        return proveType.asLeft
    }
    
    var directory: _Path<K, Directory>? {
        return proveType.asRight
    }
}

extension Path where T == Directory {
    func join<T2>(_ path: Path<Relative, T2>) -> Path<K, T2> {
        return Path<K, T2>(p.join(path.p))
    }
}
extension _Path where T == Directory {
    func join<T2>(_ path: _Path<Relative, T2>) -> _Path<K, T2> {
        switch (self, path) {
        case (._root, ._current):
            return ._root
        case (._current, ._current):
            return ._current
        case let (.dirIn(p1, name), p2):
            return .dirIn(p1.join(p2), name)
        case let (.parentIn(p1), p2):
            return .parentIn(p1.join(p2))
        case (.fileIn(_, _), _):
            fatalError("Unreachable")
        case (_, ._root):
            fatalError("Unreachable")
        case let (._current, .fileIn(p1, name)):
            return .fileIn(_Path<K, Directory>._current.join(p1), name)
        case let (._current, .dirIn(p1, name)):
            return .dirIn(_Path<K, Directory>._current.join(p1), name)
        case let (._current, .parentIn(p1)):
            return .parentIn(_Path<K, Directory>._current.join(p1))
        case let (._root, .fileIn(p1, name)):
            return .fileIn(_Path<K, Directory>._root.join(p1), name)
        case let (._root, .dirIn(p1, name)):
            return .dirIn(_Path<K, Directory>._root.join(p1), name)
        case let (._root, .parentIn(p1)):
            return .parentIn(_Path<K, Directory>._root.join(p1))
        }
    }
}


// the primitives
let root: Path<Absolute, Directory> = Path(._root)
let current: Path<Relative, Directory> = Path(._current)
func file(_ name: FileName) -> Path<Relative, File> {
    return Path(.fileIn(._current, name))
}
func dir(_ name: DirName) -> Path<Relative, Directory> {
    return Path(.dirIn(._current, name))
}
let parent: Path<Relative, Directory> = Path(.parentIn(._current))

extension Path where T == Directory {
    func join<T2>(with path: Path<Relative, T2>) -> Path<K, T2> {
      let joined: _Path<K, T2> = self.p.join(path.p)
      return Path<K, T2>(joined)
    }
}

infix operator <%>: AdditionPrecedence
func <%><K, T2>(lhs: Path<K, Directory>, rhs: Path<Relative, T2>) -> Path<K, T2> {
    return lhs.join(with: rhs)
}

extension Path where K == Unknown, T == Unknown {
    init?(rawString: String) {
        self.p = ._root
    }
}
