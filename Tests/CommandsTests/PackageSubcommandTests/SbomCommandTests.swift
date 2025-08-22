//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Basics
// import Foundation
// @_spi(DontAdoptOutsideOfSwiftPMExposedForBenchmarksAndTestsOnly) import PackageGraph
// import PackageLoading
// import PackageModel
// import SourceControl
import Testing
// import Workspace
import _InternalTestSupport
import enum SbomSupport.SBomSpecification

// import class Basics.AsyncProcess
// import struct SPMBuildCore.BuildSystemProvider
// import typealias SPMBuildCore.CLIArguments
// import class TSCBasic.BufferedOutputByteStream
// import struct TSCBasic.ByteString
// import enum TSCBasic.JSON

// @testable import Commands
// @testable import CoreCommands

@Suite(
    .tags(
        .Feature.Command.Package.Sbom
    )
)
struct SbomCommandTests {

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms), SBomSpecification.allCases,
    )
    func stdoutIsTheSameAsWritingToAFile(
        buildData: BuildData,
        SBomSpecification: SBomSpecification,
    ) async throws {
        let commonArgs = [
            "sbom",
            "--sbom-specification",
            "\(SBomSpecification)",
        ]
        try await fixture(name: "SBOM/Licenses") { fixturePath in
            let packagePath = fixturePath.appending("App")

            let output = try await executeSwiftPackage(
                packagePath,
                configuration: buildData.config,
                extraArgs: commonArgs,
                buildSystem: buildData.buildSystem,
            ).stdout

            try await withTemporaryDirectory(removeTreeOnDeinit: true) { tempDirectory in
                let sbomOutputFile = tempDirectory.appending("sbom.json")
                try await executeSwiftPackage(
                    packagePath,
                    configuration: buildData.config,
                    extraArgs: commonArgs + [
                        "--output-path",
                        sbomOutputFile.pathString,
                    ],
                    buildSystem: buildData.buildSystem,
                )
                
                let fileContents = try localFileSystem.readFileContents(sbomOutputFile).description

                #expect(output == fileContents, "UUID and timestamps are likely different. need to exclude these from the comparison.")
            }
        }
    }

    @Test(
        arguments: getBuildData(for: SupportedBuildSystemOnAllPlatforms), SBomSpecification.allCases,
    )
    func testLicense(
        buildData: BuildData,
        SBomSpecification: SBomSpecification,
    ) async throws {
        try await fixture(name: "SBOM/Licenses") { fixturePath in
            try await withTemporaryDirectory(removeTreeOnDeinit: true) { tempDirectory in
                let packagePath = fixturePath.appending("App")
                let sbomOutputJson = tempDirectory.appending("sbom.json")
                try await executeSwiftPackage(
                    packagePath,
                    configuration: buildData.config,
                    extraArgs: [
                        "sbom",
                        "--sbom-specification",
                        "\(SBomSpecification)",
                        "--output-path",
                        sbomOutputJson.pathString,
                    ],
                    buildSystem: buildData.buildSystem,
                )
            }
        }
    }
}
