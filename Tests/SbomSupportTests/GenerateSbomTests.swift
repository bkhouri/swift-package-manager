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

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct GenerateSBOMTests {
    @Test(
        arguments: [
            "MyApp",
            "My-Special_Package.Name",
            ALL_WORKING_PUNCTUATIONS_STRING,
        ] //+ NAMES_WITH_PUNCTUATIONS,
    )
    func withSingleRootPackage(
        packageName: String,
    ) throws {
        // Arrange
        let graph = try createMockModulesGraph(
            rootPackageName: packageName,
            rootPackageVersion: "2.1.0"
        )
        
        // Act
        // Act
        let sbom = try generateSBOM(from: graph)
        
        // Assert
        // Verify basic structure
        #expect(sbom.bomFormat == "CycloneDX")
        #expect(sbom.specVersion == "1.4")
        #expect(sbom.version == 1)
        let serialNumber = try #require(sbom.serialNumber)
        #expect(serialNumber.hasPrefix("urn:uuid:"))
        
        // Verify metadata (package names are normalized to lowercase)
        let metadata = try #require(sbom.metadata)
        let component = try #require(metadata.component)
        #expect(component.name == packageName.lowercased())
        #expect(component.version == "2.1.0")
        #expect(component.type == .library)
        #expect(component.scope == "required")
        
        // Verify components (should contain root package)
        let components = try #require(sbom.components)
        #expect(components.count == 1)
        let rootComponent = components.first!
        #expect(rootComponent.name == packageName.lowercased())
        #expect(rootComponent.version == "2.1.0")
        #expect(rootComponent.type == .library)
        #expect(rootComponent.scope == "required")
        
        // Verify no dependencies for single package
        let dependencies = try #require(sbom.dependencies)
        #expect(dependencies.isEmpty)
    }
    
    @Test func withDependenciesOrig() async throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "MyApp",
            rootPackageVersion: "1.0.0",
            dependencies: [
                (name: "Networking", version: "2.3.1"),
                (name: "Logging", version: "1.5.0")
            ]
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify components include root + dependencies (names are lowercase)
        let components = try #require(sbom.components)
        #expect(components.count == 3)
        
        let componentNames = Set(components.map { $0.name })
        #expect(componentNames.contains("myapp"))
        #expect(componentNames.contains("networking"))
        #expect(componentNames.contains("logging"))
        
        // Verify dependency versions
        let networkingComponent = components.first { $0.name == "networking" }!
        #expect(networkingComponent.version == "2.3.1")
        
        let loggingComponent = components.first { $0.name == "logging" }!
        #expect(loggingComponent.version == "1.5.0")
        
        // Verify dependencies structure
        let dependencies = try #require(sbom.dependencies)
        #expect(dependencies.count >= 1)
        
        // Find root package dependencies
        let rootDeps = dependencies.first { $0.ref == "myapp" }
        #expect(rootDeps != nil)
        #expect(rootDeps!.dependsOn.contains("networking"))
        #expect(rootDeps!.dependsOn.contains("logging"))

    }
    @Test(
        arguments: [
            0, 
            // 1,
            // 2, 
            // 10,
        ],
    )
    func withDependencies(
        numberOfDependencies: Int,
    ) throws {
        let dependencies = (0 ..< numberOfDependencies).map { index in 
            (name: "dep_\(index)", version: "2.0.\(index)")
        }
        let graph = try createMockModulesGraph(
            rootPackageName: "MyApp",
            rootPackageVersion: "1.0.0",
            dependencies: dependencies,
        )
        try #require(dependencies.count == numberOfDependencies)
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify components include root + dependencies (names are lowercase)
        let sbomComponents = try #require(sbom.components)
        #expect(sbomComponents.count == (numberOfDependencies + 1))
        
        let componentNames = Set(sbomComponents.map { $0.name })
        #expect(componentNames.contains("myapp"))
        for dep in dependencies {
            #expect(componentNames.contains(dep.name))
        }
        
        // // Verify dependency versions
        // let networkingComponent = sbom.components.first { $0.name == "networking" }!
        // #expect(networkingComponent.version == "2.3.1")
        
        // let loggingComponent = sbom.components.first { $0.name == "logging" }!
        // #expect(loggingComponent.version == "1.5.0")
        
        // Verify dependencies structure
        if numberOfDependencies == 0 {
            // When there are no dependencies, the dependencies array should be empty
            #expect(sbom.dependencies?.isEmpty == true || sbom.dependencies == nil)
        } else {
            // When there are dependencies, verify the structure
            #expect(sbom.dependencies?.count == 1) // Only root package should have dependencies
            
            // Find root package dependencies
            let rootDeps: SBOMDependency = try #require(sbom.dependencies?.first { $0.ref == "myapp" })
            for dep in dependencies {
                #expect(rootDeps.dependsOn.contains(dep.name))
                let depdencyComponent = sbomComponents.first { $0.name == dep.name }!
                #expect(depdencyComponent.version == dep.version)
            }
        }


        // let graph = try createMockModulesGraph(
        //     rootPackageName: "MyApp",
        //     rootPackageVersion: "1.0.0",
        //     dependencies: [
        //         (name: "Networking", version: "2.3.1"),
        //         (name: "Logging", version: "1.5.0")
        //     ]
        // )
        
        // let command = createSBomCommand()
        // let sbom = try command.generateSBOM(from: graph)
        
        // // Verify components include root + dependencies (names are lowercase)
        // #expect(sbom.components.count == 3)
        
        // let componentNames = Set(sbom.components.map { $0.name })
        // #expect(componentNames.contains("myapp"))
        // #expect(componentNames.contains("networking"))
        // #expect(componentNames.contains("logging"))
        
        // // Verify dependency versions
        // let networkingComponent = sbom.components.first { $0.name == "networking" }!
        // #expect(networkingComponent.version == "2.3.1")
        
        // let loggingComponent = sbom.components.first { $0.name == "logging" }!
        // #expect(loggingComponent.version == "1.5.0")
        
        // // Verify dependencies structure
        // #expect(sbom.dependencies.count >= 1)
        
        // // Find root package dependencies
        // let rootDeps = sbom.dependencies.first { $0.ref == "myapp" }
        // #expect(rootDeps != nil)
        // #expect(rootDeps!.dependsOn.contains("networking"))
        // #expect(rootDeps!.dependsOn.contains("logging"))
    }
    
    @Test
    func withUnknownVersions() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: nil,
            dependencies: [
                (name: "UnversionedDep", version: nil)
            ]
        )
        
        let sbom = try generateSBOM(from: graph)

        // Verify unknown versions are handled (names are lowercase)
        let sbomComponents = try #require(sbom.components)
        let rootComponent = sbomComponents.first { $0.name == "testapp" }!
        #expect(rootComponent.version == "unknown")
        
        let depComponent = sbomComponents.first { $0.name == "unversioneddep" }!
        #expect(depComponent.version == "unknown")
    }
    
    @Test
    func withNoRootPackage() throws {
        // Create an empty graph with no manifests
        let fs = InMemoryFileSystem(emptyFiles: [])
        let observability = ObservabilitySystem.makeForTesting()
        
        // This should create a graph with no root packages
        let graph = try loadModulesGraph(
            fileSystem: fs,
            manifests: [],
            observabilityScope: observability.topScope
        )
        
        // Should throw an error when no root package is found
        #expect(throws: StringError.self) {
            try generateSBOM(from: graph)
        }
    }
}
