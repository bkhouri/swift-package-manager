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
import ArgumentParser

package enum RunMode: EnumerableFlag {
    case repl
    case debugger
    case run

    package static func help(for value: RunMode) -> ArgumentHelp? {
        switch value {
        case .repl:
            return "Launch Swift REPL for the package."
        case .debugger:
            return "Launch the executable in a debugger session."
        case .run:
            return "Launch the executable with the provided arguments."
        }
    }
}

struct RunCommandOptions: ParsableArguments {
    /// The mode in with the tool command should run.
    @Flag var mode: RunMode = .run

    /// If the executable product should be built before running.
    @Flag(name: .customLong("skip-build"), help: "Skip building the executable product.")
    var shouldSkipBuild: Bool = false

    var shouldBuild: Bool { !shouldSkipBuild }

    /// If the test should be built.
    @Flag(name: .customLong("build-tests"), help: "Build both source and test targets.")
    var shouldBuildTests: Bool = false

    /// The executable product to run.
    @Argument(help: "The executable to run.", completion: .shellCommand("swift package completion-tool list-executables"))
    var executable: String?

    /// The arguments to pass to the executable.
    @Argument(parsing: .captureForPassthrough,
              help: "The arguments to pass to the executable.")
    var arguments: [String] = []
}
