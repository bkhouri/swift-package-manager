/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Basics
import TSCBasic

public func expectFileExists(
    _ path: Basics.AbsolutePath,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    print("localFileSystem.isFile(path) ==> \(TSCBasic.localFileSystem.isFile(path))")
    #expect(
        TSCBasic.localFileSystem.isFile(path),
        "Expected file doesn't exist: \(path)",
        sourceLocation: sourceLocation
    )
}
public func expectDirectoryExists(
    _ path: Basics.AbsolutePath,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    #expect(
        TSCBasic.localFileSystem.isDirectory(path),
        "Expected directory doesn't exist: \(path)",
        sourceLocation: sourceLocation
    )
}

public func requireNoDiagnostics(
    _ diagnostics: [Basics.Diagnostic],
    problemsOnly: Bool = true,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let diagnostics = problemsOnly ? diagnostics.filter { $0.severity >= .warning } : diagnostics
    let description = diagnostics.map { "- " + $0.description }.joined(separator: "\n")

    try #require(
        diagnostics.isEmpty,
        "Found unexpected diagnostics: \n\(description)",
        sourceLocation: sourceLocation
    )
}

public func expectNoDiagnostics(
    _ engine: DiagnosticsEngine,
    sourceLocation: SourceLocation = #_sourceLocation
) {
    let diagnostics = engine.diagnostics
    let diags = diagnostics.map({ "- " + $0.description }).joined(separator: "\n")
    #expect(
        diagnostics.isEmpty,
        "Found unexpected diagnostics: \n\(diags)",
        sourceLocation: sourceLocation
    )
}
