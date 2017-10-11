import XCTest
@testable import pathy

class pathyTests: XCTestCase {
    
    func testFromRawFile() {
        XCTAssertEqual(path(rawFile: "Hello.swift"), .fileIn(._current, "Hello.swift"))
        XCTAssertEqual(path(rawFile: "/Users/bkase/Hello.swift"), .fileIn(.dirIn(.dirIn(._root, "Users"), "bkase"), "Hello.swift"))
        
        XCTAssertNil(path(rawFile: ""))
        XCTAssertNil(path(rawFile: "/"))
        XCTAssertNil(path(rawFile: "."))
        XCTAssertNil(path(rawFile: ".."))
    }
    
    func testFromRawDir() {
        XCTAssertEqual(path(rawDir: "/"), ._root)
        XCTAssertEqual(path(rawDir: "."), ._current)
        XCTAssertEqual(path(rawDir: ".."), .parentIn(._current))
        XCTAssertNil(path(rawDir: ""))
        
        XCTAssertEqual(path(rawDir: "/Users/bkase/.."), .parentIn(.dirIn(.dirIn(._root, "Users"), "bkase")))
    }

    static var allTests = [
        ("testFromRawFile", testFromRawFile),
        ("testFromRawDir", testFromRawDir),
    ]
}
