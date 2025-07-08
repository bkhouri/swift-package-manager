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
import struct ArgumentParser.ExitCode
import struct CoreCommands.GlobalOptions
import struct Basics.AbsolutePath
import class CoreCommands.SwiftCommandState
import struct SPMBuildCore.BuildSystemProvider
import typealias SPMBuildCore.CLIArguments
import class PackageModel.UserToolchain
import class PackageModel.Product
import class PackageModel.SystemLibraryModule
import struct PackageGraph.ModulesGraph

import TSCBasic

package struct RunModeRepl: RunCommandProtocol {
    var useBuildSystem: Bool { true }

    func run(
        swiftCommandState: SwiftCommandState,
        globalOptions: GlobalOptions,
        options: RunCommandOptions
    ) async throws {
        defer {
            swiftCommandState.outputStream.flush()
        }

        // FIXME: We need to implement the build tool invocation closure here so that build tool plugins work with the REPL. rdar://86112934
        let buildSystem = try await getBuildSystem(
            swiftCommandState: swiftCommandState,
            executable: options.executable,
        )
        // Perform build.
        let buildResult = try await buildSystem.build(subset: .allExcludingTests, buildOutputs: [.buildPlan, .replArguments])

        // Get the REPL arguments
        guard let replArguments = buildResult.replArguments else {
            throw ExitCode.failure
        }
        let arguments: CLIArguments = replArguments

        // Execute the REPL.
        let interpreterPath = try swiftCommandState.getTargetToolchain().swiftInterpreterPath
        swiftCommandState.outputStream.send("Launching Swift (interpreter at \(interpreterPath)) REPL with arguments: \(arguments.joined(separator: " "))\n")
        swiftCommandState.outputStream.flush()
        try self.run(
            fileSystem: swiftCommandState.fileSystem,
            executablePath: interpreterPath,
            originalWorkingDirectory: swiftCommandState.originalWorkingDirectory,
            arguments: arguments,
        )

    }

}
