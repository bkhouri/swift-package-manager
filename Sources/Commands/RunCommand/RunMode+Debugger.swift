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
import class CoreCommands.SwiftCommandState
import Basics
// import CoreCommands
// import Foundation
// import PackageGraph
import PackageModel
import SPMBuildCore

import enum TSCBasic.ProcessEnv
import func TSCBasic.exec

import enum TSCUtility.Diagnostics

#if canImport(Android)
import Android
#endif

package struct RunModeDebugger: RunCommandProtocol {
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

        let productRelativePath = try swiftCommandState.productsBuildParameters.executablePath(for: productName)
        let productAbsolutePath = try swiftCommandState.productsBuildParameters.buildPath.appending(productRelativePath)

        // Make sure we are running from the original working directory.
        let cwd: AbsolutePath? = swiftCommandState.fileSystem.currentWorkingDirectory
        if cwd == nil || swiftCommandState.originalWorkingDirectory != cwd {
            try ProcessEnv.chdir(swiftCommandState.originalWorkingDirectory)
        }

        if let debugger = try swiftCommandState.getTargetToolchain().swiftSDK.toolset.knownTools[.debugger],
            let debuggerPath = debugger.path {
            try self.run(
                fileSystem: swiftCommandState.fileSystem,
                executablePath: debuggerPath,
                originalWorkingDirectory: swiftCommandState.originalWorkingDirectory,
                arguments: debugger.extraCLIOptions + [productAbsolutePath.pathString] + options.arguments
            )
        } else {
            let pathRelativeToWorkingDirectory = productAbsolutePath.relative(to: swiftCommandState.originalWorkingDirectory)
            let lldbPath = try swiftCommandState.getTargetToolchain().getLLDB()
            try exec(path: lldbPath.pathString, args: ["--", pathRelativeToWorkingDirectory.pathString] + options.arguments)
        }
    }

}