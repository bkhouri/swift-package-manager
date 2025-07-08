//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation
import Testing

// import struct Commands.RunCommandOptions
import enum Commands.RunMode
import struct Commands.RunModeRepl
import struct Commands.RunModeDebugger
import struct Commands.RunModeRunExecutable
import struct Commands.RunModeRunFile
import protocol Commands.RunCommandProtocol
@testable import struct Commands.RunCommandFactory

import struct Basics.AbsolutePath
import class Basics.InMemoryFileSystem

struct RunModeTestData {
    let mode: RunMode
    let executable: String
    let expectedRunModeInstancetype: RunCommandProtocol.Type
}

fileprivate func getRunModeTestData() -> [RunModeTestData] {
    return [
        RunModeTestData(
            mode: RunMode.run,
            executable:  "/myExec",
            expectedRunModeInstancetype: RunModeRunExecutable.self,
        ),
        RunModeTestData(
            mode: RunMode.run,
            executable:  "/myExec.swift",
            expectedRunModeInstancetype: RunModeRunFile.self,
        ),
        RunModeTestData(
            mode: RunMode.repl,
            executable:  "/myExec",
            expectedRunModeInstancetype: RunModeRepl.self,
        ),
        RunModeTestData(
            mode: RunMode.debugger,
            executable:  "/myExec",
            expectedRunModeInstancetype: RunModeDebugger.self,
        ),
    ]
}
@Suite(
    .tags(
        Tag.TestSize.small
    )
)
struct RunCommandFactoryTests {

    @Test
    func validateTestData() async throws {
        let expected = RunMode.allCases.count

        // WHEN we get the test data
        let actual = getRunModeTestData()
        // AND get the unique set of modes
        let actualUniqueModes = Set(actual.map { $0.mode})

        // THEN we expect the filter number of items to match the number of available RunMode
        #expect(actualUniqueModes.count == expected, "Number of unique run modes does not match the number of vaialble run modes.")
    }

    @Test(
        arguments: getRunModeTestData(),
    )
    func getInstanceReturnsExpectedType(
        tcdata: RunModeTestData
    ) {
        // GIVEN we have a run mode
        let mode = tcdata.mode
        let fs = InMemoryFileSystem(
            emptyFiles: [
                tcdata.executable
            ]
        )

        // WHEN we get the an instance
        let actual = RunCommandFactory.getInstance(
            mode: mode,
            fileSystem: fs,
            executable: tcdata.executable,
        )

        // THEN we expect the return type to be as expecte
        #expect(type(of: actual) == tcdata.expectedRunModeInstancetype)
    }
}