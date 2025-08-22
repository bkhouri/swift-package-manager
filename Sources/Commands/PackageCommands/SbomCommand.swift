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
import Foundation

import protocol Basics.FileSystem
import protocol CoreCommands.AsyncSwiftCommand
import struct CoreCommands.GlobalOptions
import class CoreCommands.SwiftCommandState
import struct Basics.SwiftVersion
import struct Basics.AbsolutePath

import PackageGraph
import PackageModel
import SPMBuildCore
import SbomSupport

extension SBomSpecification: ExpressibleByArgument {}
extension SwiftPackageCommand {

    struct SBomCommand: AsyncSwiftCommand {

        package static var configuration = CommandConfiguration(
            commandName: "sbom",
            _superCommandName: "swift",
            abstract: "Generate a Software Bill Of Materials (SBom) for the package.",
            discussion: "SEE ALSO: swift build, swift package, swift test",
            version: SwiftVersion.current.completeDisplayString,
            helpNames: [
                .short,
                .long,
                .customLong("help", withSingleDash: true),
            ],
        )

        @OptionGroup(visibility: .hidden)
        var globalOptions: GlobalOptions

        @Option(help: "Set the SBOM specification.")
        var sbomSpecification: SBomSpecification = .cyclonedx

        @Option(
            name: [.long, .customShort("o")],
            help: "The absolute or relative path to output the SBOM."
        )
        var outputPath: AbsolutePath?

        func run(_ swiftCommandState: SwiftCommandState) async throws {
            // Load the package graph to analyze dependencies
            let graph = try await swiftCommandState.loadPackageGraph()
            let fs = swiftCommandState.fileSystem

            // Generate the SBOM
            let sbom = try generateSBOM(from: graph)

            // Validate the generated JSON against the schema
            try validateSBOMJSON(
                JSONEncoder().encode(sbom),
                specification: sbomSpecification,
                fileSystem: fs,
            )

            // Output the SBOM
            try outputSBOM(
                sbom,
                specification: sbomSpecification,
                outputPath: outputPath,
                fileSystem: fs,
            )
        }

    }
}
