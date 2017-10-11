//
//  SimpleParser.swift
//  pathyPackageDescription
//
//  Created by Brandon Kase on 10/11/17.
//

import Foundation

struct Parser {
    let run: (String) -> (A, String)
}

let parsePath = parseSlash <*> repSep(
