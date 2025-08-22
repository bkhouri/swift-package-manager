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

import Basics
import Foundation
@_spi(DontAdoptOutsideOfSwiftPMExposedForBenchmarksAndTestsOnly) import PackageGraph
import PackageLoading
import PackageModel
import Testing
import SbomSupport
import _InternalTestSupport

import class TSCBasic.BufferedOutputByteStream
import struct TSCBasic.ByteString
import enum TSCBasic.JSON
import struct TSCBasic.StringError

import struct TSCUtility.Version
// @testable import Commands
// @testable import CoreCommands

// MARK: - Helper Methods

package func createMockModulesGraph(
    rootPackageName: String = "TestPackage",
    rootPackageVersion: String? = "1.0.0",
    dependencies: /*[PackageDependency] = [],*/[(name: String, version: String?)] = [],
) throws -> ModulesGraph {
    // Create file system with proper source file structure
    var emptyFiles: [String] = []
    
    // Add root package source files
    emptyFiles.append("/\(rootPackageName)/Sources/\(rootPackageName)/\(rootPackageName).swift")
    
    // Add dependency source files
    for dep in dependencies {
        emptyFiles.append("/\(dep.name)/Sources/\(dep.name)/\(dep.name).swift")
    }
    
    let fs = InMemoryFileSystem(emptyFiles: emptyFiles)
    
    // Create root package manifest
    let rootManifest = Manifest.createRootManifest(
        displayName: rootPackageName,
        path: "/\(rootPackageName)",
        version: rootPackageVersion.map { Version($0)! },
        toolsVersion: .v5_5,
        dependencies: dependencies.map { dep in
            .fileSystem(path: "/\(dep.name)")
        },
        targets: [
            try TargetDescription(name: rootPackageName)
        ]
    )
    
    var manifests = [rootManifest]
    
    // Create dependency manifests
    for dep in dependencies {
        let depManifest = Manifest.createFileSystemManifest(
            displayName: dep.name,
            path: "/\(dep.name)",
            version: dep.version.map { Version($0)! },
            toolsVersion: .v5_5,
            products: [
                try ProductDescription(name: dep.name, type: .library(.automatic), targets: [dep.name])
            ],
            targets: [
                try TargetDescription(name: dep.name)
            ]
        )
        manifests.append(depManifest)
    }
    
    let observability = ObservabilitySystem.makeForTesting()
    return try loadModulesGraph(
        fileSystem: fs,
        manifests: manifests,
        observabilityScope: observability.topScope
    )
}

// package func createSBomCommand() -> SwiftPackageCommand.SBomCommand {
//     return SwiftPackageCommand.SBomCommand()
// }


package let ALL_WORKING_PUNCTUATIONS_STRING = ALL_PUNCTUATIONS.filter { !["/"].contains($0) }
package let NAMES_WITH_PUNCTUATIONS = ALL_WORKING_PUNCTUATIONS_STRING.map { "ThisisAName\($0)WithAPuctuation"}
