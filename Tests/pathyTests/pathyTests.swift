import XCTest
@testable import pathy
import SwiftCheck

extension Path: Arbitrary {
    // We only are generating a Path<Absolute, File>
    // but without conditional conformances, we have to just as! the
    // phantom type parameters
    public static var arbitrary: Gen<Path> {
        let pathPart = String.arbitrary.suchThat{ $0 != "" }
        let genPath: Gen<Path<Absolute, File>> = Gen<Int>.choose((1,10)).flatMap{ numDirs in
            let dirs: Gen<[Path<Relative, Directory>]> = pathPart.map{ dir(DirName($0)) }.proliferate(withSize: numDirs)
            let filename: Gen<Path<Relative, File>> = pathPart.map{ pathy.file(FileName($0)) }
            return Gen<([Path<Relative, Directory>], Gen<Path<Relative, File>>)>.zip(dirs, filename)
        }.map{ (tuple: ([Path<Relative, Directory>], Path<Relative, File>)) -> Path<Absolute, File> in
            let dirs = tuple.0
            let filename = tuple.1
            return root <%> dirs.reduce(filename) { acc, dir in
                dir <%> acc
            }
        }
        // TODO: Fix when we get conditional conformances
        return genPath as! Gen<Path<K, T>>
    }
}

class pathyTests: XCTestCase {
    func testWeakSelfInverse() {
        property("Weak self inverse") <- forAll { (p : Path<Absolute, File>) in
            path(rawFile: p.description)!.description == p.description
        }
    }
    
    func testFromRawFile() {
      let p: Path<Unknown, File> = Path(.fileIn(._current, "Hello.swift"))
        XCTAssertEqual(path(rawFile: "Hello.swift")!, p)
        XCTAssertEqual(path(rawFile: "/Users/bkase/Hello.swift"), Path(.fileIn(.dirIn(.dirIn(._root, "Users"), "bkase"), "Hello.swift")))
        
        XCTAssertNil(path(rawFile: ""))
        XCTAssertNil(path(rawFile: "/"))
        XCTAssertNil(path(rawFile: "."))
        XCTAssertNil(path(rawFile: ".."))
    }
    
    func testFromRawDir() {
        XCTAssertEqual(path(rawDir: "/")!, Path(._root))
        XCTAssertEqual(path(rawDir: ".")!, Path(._current))
        XCTAssertEqual(path(rawDir: ".."), Path(.parentIn(._current)))
        XCTAssertNil(path(rawDir: ""))
        
        XCTAssertEqual(path(rawDir: "/Users/bkase/.."), Path(.parentIn(.dirIn(.dirIn(._root, "Users"), "bkase"))))
    }
  
    func testJoin() {
      let p = root <%> dir("Users") <%> parent <%> file("Hello.swift")
      
      let p2: Path<Absolute, File> = Path(.dirIn(.parentIn(.fileIn(._root, "Hello.swift")), "Users"))
      
      dump(path(rawFile: "/Users/Hello.swift"))
      XCTAssertEqual(p, p2)
    }
    
    func testDescription() {
        XCTAssertEqual("/", root.description)
        XCTAssertEqual("/Users/bkase/Hello.swift", (root <%> dir("Users") <%> dir("bkase") <%> file("Hello.swift")).description)
    }

    static var allTests = [
        ("testFromRawFile", testFromRawFile),
        ("testFromRawDir", testFromRawDir),
    ]
}
