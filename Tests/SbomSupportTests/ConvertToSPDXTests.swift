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
//

import SbomSupport
import Basics
import Foundation
@_spi(DontAdoptOutsideOfSwiftPMExposedForBenchmarksAndTestsOnly) import PackageGraph
import PackageLoading
import PackageModel
import Testing
import _InternalTestSupport

import class TSCBasic.BufferedOutputByteStream
import struct TSCBasic.ByteString
import enum TSCBasic.JSON
// import struct TSCBasic.StringError

// import struct TSCUtility.Version
// @testable import Commands
// @testable import CoreCommands

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct converToSPDXTests {
    @Test
    func basicConversion() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "TestPackage",
            rootPackageVersion: "1.0.0",
            dependencies: [
                (name: "Dependency1", version: "2.0.0")
            ]
        )
        
        let cycloneDX = try generateSBOM(from: graph)
        let spdx = convertToSPDX(cycloneDX)
        
        // Verify SPDX structure
        #expect(spdx.spdxVersion == "SPDX-2.3")
        #expect(spdx.dataLicense == "CC0-1.0")
        #expect(spdx.spdxId == "SPDXRef-DOCUMENT")
        #expect(spdx.name == "testpackage") // Names are lowercase
        #expect(spdx.documentNamespace.hasPrefix("https://swift.org/testpackage-"))
        
        // Verify creation info
        #expect(spdx.creationInfo.creators == ["Tool: swift-package-manager"])
        #expect(!spdx.creationInfo.created.isEmpty)
        
        // Verify packages
        #expect(spdx.packages.count == 2) // Root + 1 dependency
        
        let packageNames = Set(spdx.packages.map { $0.name })
        #expect(packageNames.contains("testpackage"))
        #expect(packageNames.contains("dependency1"))
        
        // Verify package properties
        let rootPackage = spdx.packages.first { $0.name == "testpackage" }!
        #expect(rootPackage.spdxId == "SPDXRef-testpackage")
        #expect(rootPackage.downloadLocation == "NOASSERTION")
        #expect(rootPackage.filesAnalyzed == false)
        #expect(rootPackage.versionInfo == "1.0.0")
    }
    
    @Test(
        arguments: [
            "MyApp",
            "My-Special_Package.Name",
            ALL_WORKING_PUNCTUATIONS_STRING,
        ] //+ NAMES_WITH_PUNCTUATIONS,
    )
    func withSpecialCharactersInName(
        rootPackageName: String,
    ) throws {
        let graph = try createMockModulesGraph(
            rootPackageName: rootPackageName,
            rootPackageVersion: "1.0.0"
        )

        let cycloneDX = try generateSBOM(from: graph)
        let spdx = convertToSPDX(cycloneDX)
        
        // Verify special characters are handled in SPDX IDs (names are lowercase)
        let rootPackage = try #require(spdx.packages.first, "Root package does not exists.")
        #expect(rootPackage.spdxId == "SPDXRef-\(rootPackageName.lowercased())")
        #expect(rootPackage.name == rootPackageName.lowercased())
    }
}
