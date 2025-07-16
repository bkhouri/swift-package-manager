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
import class PackageModel.UserToolchain
import class PackageModel.Product
import class PackageModel.SystemLibraryModule
import struct PackageGraph.ModulesGraph

package struct RunModeRepl: RunCommandProtocol {
    var useBuildSystem: Bool { true }

    func run(
        swiftCommandState: SwiftCommandState,
        globalOptions: GlobalOptions,
        options: RunCommandOptions
    ) async throws {
        // Load a custom package graph which has a special product for REPL.
        let asyncUnsafeGraphLoader = {
            try await swiftCommandState.loadPackageGraph(
                explicitProduct: options.executable,
                traitConfiguration: .init(traitOptions: options.traits),
            )
        }
        let graph = try await asyncUnsafeGraphLoader()

        // Construct the build operation.
        // FIXME: We need to implement the build tool invocation closure here so that build tool plugins work with the REPL. rdar://86112934
        let buildSystem = try await swiftCommandState.createBuildSystem(
            explicitBuildSystem: .native,
            traitConfiguration: .init(traitOptions: options.traits),
            cacheBuildManifest: false,
            packageGraphLoader: asyncUnsafeGraphLoader
        )

        // Perform build.
        let buildResult = try await buildSystem.build(subset: .allExcludingTests, buildOutputs: [.buildPlan])
            guard let buildPlan = buildResult.buildPlan else {
                throw ExitCode.failure
        }
        let executableArgs: [String]
        if let executable = options.executable {
            executableArgs = [executable]
        } else {
            executableArgs = []
        }
        // Execute the REPL.
        let arg = try createREPLArguments(
            buildPath: swiftCommandState.toolsBuildParameters.buildPath,
            graph: graph,
        ) + executableArgs
        let arguments = try buildPlan.createREPLArguments() + executableArgs
        print("New args                           : \(arg.joined(separator: " "))")
        print("Launching Swift REPL with arguments: \(arguments.joined(separator: " "))")
        // throw PurposefulError.because
        print("Launching Swift REPL with arguments: \(arguments.joined(separator: " "))")
        try self.run(
            fileSystem: swiftCommandState.fileSystem,
            executablePath: swiftCommandState.getTargetToolchain().swiftInterpreterPath,
            originalWorkingDirectory: swiftCommandState.originalWorkingDirectory,
            arguments: arguments
        )

    }

}

enum PurposefulError: Swift.Error {
    case because
}

func createREPLArguments(
    buildPath: AbsolutePath,
    graph: ModulesGraph,
) throws -> [String] {
        var arguments = ["repl", "-I" + buildPath.pathString, "-L" + buildPath.pathString]

        // Link the special REPL product that contains all of the library targets.
        let replProductName = try graph.getReplProductName()
        arguments.append("-l" + replProductName)

        // The graph should have the REPL product.
        assert(graph.product(for: replProductName) != nil)

        // // Add the search path to the directory containing the modulemap file.
        // for target in self.targets {
        //     switch target {
        //     case .swift: break
        //     case .clang(let targetDescription):
        //         if let includeDir = targetDescription.moduleMap?.parentDirectory {
        //             arguments += ["-I\(includeDir.pathString)"]
        //         }
        //     }
        // }

        // // Add search paths from the system library targets.
        // for target in graph.reachableModules {
        //     if let systemLib = target.underlying as? SystemLibraryModule {
        //         arguments += try self.pkgConfig(for: systemLib).cFlags
        //     }
        // }
        return arguments

}