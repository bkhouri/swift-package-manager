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
import struct CoreCommands.GlobalOptions

import Basics
import CoreCommands
import Foundation
import PackageGraph
import PackageModel
import SPMBuildCore

import enum TSCBasic.ProcessEnv
import func TSCBasic.exec

import enum TSCUtility.Diagnostics

#if canImport(Android)
import Android
#endif


package struct RunModeRunFile: RunCommandProtocol {
    var useBuildSystem: Bool { false }

    func run(
        swiftCommandState: SwiftCommandState,
        globalOptions: GlobalOptions,
        options: RunCommandOptions,
    ) async throws {
        if let executable = options.executable {
            swiftCommandState.observabilityScope.emit(
                .warning("'swift run \(executable)' command to interpret swift files is deprecated; use 'swift \(executable)' instead.")
            )
            // Redirect execution to the toolchain's swift executable.
            let swiftInterpreterPath = try swiftCommandState.getTargetToolchain().swiftInterpreterPath
            // Prepend the script to interpret to the arguments.
            let arguments = [executable] + options.arguments
            try self.run(
                fileSystem: swiftCommandState.fileSystem,
                executablePath: swiftInterpreterPath,
                originalWorkingDirectory: swiftCommandState.originalWorkingDirectory,
                arguments: arguments
            )
        } else {
            throw RunError.noExecutableFound
        }
    }
}

package struct RunModeRunExecutable: RunCommandProtocol {
    var useBuildSystem: Bool { true }

    func run(
        swiftCommandState: SwiftCommandState,
        globalOptions: GlobalOptions,
        options: RunCommandOptions,
    ) async throws {
        let buildSystem = try await getBuildSystem(
            swiftCommandState: swiftCommandState,
            executable: options.executable,
        )
        let productName = try await findProductName(in: buildSystem.getPackageGraph(), executable: options.executable)
        if options.shouldBuildTests {
            try await buildSystem.build(subset: .allIncludingTests, buildOutputs: [])
        } else if options.shouldBuild {
            try await buildSystem.build(subset: .product(productName), buildOutputs: [])
        }

        let executablePath = try swiftCommandState.productsBuildParameters.buildPath.appending(component: productName)

        let productRelativePath = try swiftCommandState.productsBuildParameters.executablePath(for: productName)
        let productAbsolutePath = try swiftCommandState.productsBuildParameters.buildPath.appending(productRelativePath)

        let runnerPath: AbsolutePath
        let arguments: [String]

        if let debugger = try swiftCommandState.getTargetToolchain().swiftSDK.toolset.knownTools[.debugger],
            let debuggerPath = debugger.path {
            runnerPath = debuggerPath
            arguments = debugger.extraCLIOptions + [productAbsolutePath.pathString] + options.arguments
        } else {
            runnerPath = executablePath
            arguments = options.arguments
        }

        try self.run(
            fileSystem: swiftCommandState.fileSystem,
            executablePath: runnerPath,
            originalWorkingDirectory: swiftCommandState.originalWorkingDirectory,
            arguments: arguments
        )
    }
}
