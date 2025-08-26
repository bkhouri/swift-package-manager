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

import struct TSCUtility.Version

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
    // MARK: - Transitive Dependencies Tests
    
    @Test
    func withTransitiveDependencies_simpleChain() throws {
        // Create a dependency chain: MyApp -> NetworkingLib -> CryptoLib
        let graph = try createMockModulesGraphWithTransitiveDeps(
            rootPackageName: "MyApp",
            rootPackageVersion: "1.0.0",
            dependencyChain: [
                ("NetworkingLib", "2.0.0", [("CryptoLib", "1.5.0", [])])
            ]
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify all components are included (root + direct + transitive)
        let components = try #require(sbom.components)
        #expect(components.count == 3) // MyApp + NetworkingLib + CryptoLib
        
        let componentNames = Set(components.map { $0.name })
        #expect(componentNames.contains("myapp"))
        #expect(componentNames.contains("networkinglib"))
        #expect(componentNames.contains("cryptolib"))
        
        // Verify scope classification
        let myAppComponent = components.first { $0.name == "myapp" }!
        #expect(myAppComponent.scope == "required")
        
        let networkingComponent = components.first { $0.name == "networkinglib" }!
        #expect(networkingComponent.scope == "required") // Direct dependency
        
        let cryptoComponent = components.first { $0.name == "cryptolib" }!
        #expect(cryptoComponent.scope == "optional") // Transitive dependency
        
        // Verify dependency relationships
        let dependencies = try #require(sbom.dependencies)
        #expect(dependencies.count == 2) // MyApp and NetworkingLib have dependencies
        
        // MyApp depends on NetworkingLib
        let myAppDeps = dependencies.first { $0.ref == "myapp" }!
        #expect(myAppDeps.dependsOn.contains("networkinglib"))
        #expect(myAppDeps.dependsOn.count == 1)
        
        // NetworkingLib depends on CryptoLib
        let networkingDeps = dependencies.first { $0.ref == "networkinglib" }!
        #expect(networkingDeps.dependsOn.contains("cryptolib"))
        #expect(networkingDeps.dependsOn.count == 1)
    }
    
    @Test
    func withTransitiveDependencies_complexGraph() throws {
        // Create a more complex dependency graph:
        // MyApp -> [NetworkingLib, LoggingLib]
        // NetworkingLib -> [CryptoLib, UtilsLib]
        // LoggingLib -> [UtilsLib] (shared transitive dependency)
        let graph = try createMockModulesGraphWithTransitiveDeps(
            rootPackageName: "MyApp",
            rootPackageVersion: "1.0.0",
            dependencyChain: [
                ("NetworkingLib", "2.0.0", [
                    ("CryptoLib", "1.5.0", []),
                    ("UtilsLib", "3.0.0", [])
                ]),
                ("LoggingLib", "1.2.0", [
                    ("UtilsLib", "3.0.0", [])
                ])
            ]
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify all components are included
        let components = try #require(sbom.components)
        #expect(components.count == 5) // MyApp + NetworkingLib + LoggingLib + CryptoLib + UtilsLib
        
        let componentNames = Set(components.map { $0.name })
        #expect(componentNames.contains("myapp"))
        #expect(componentNames.contains("networkinglib"))
        #expect(componentNames.contains("logginglib"))
        #expect(componentNames.contains("cryptolib"))
        #expect(componentNames.contains("utilslib"))
        
        // Verify scope classification
        let directDeps = ["networkinglib", "logginglib"]
        let transitiveDeps = ["cryptolib", "utilslib"]
        
        for component in components {
            if component.name == "myapp" {
                #expect(component.scope == "required")
            } else if directDeps.contains(component.name) {
                #expect(component.scope == "required", "Direct dependency \(component.name) should have 'required' scope")
            } else if transitiveDeps.contains(component.name) {
                #expect(component.scope == "optional", "Transitive dependency \(component.name) should have 'optional' scope")
            }
        }
        
        // Verify dependency relationships include all packages
        let dependencies = try #require(sbom.dependencies)
        #expect(dependencies.count == 3) // MyApp, NetworkingLib, and LoggingLib have dependencies
        
        // Verify MyApp's direct dependencies
        let myAppDeps = dependencies.first { $0.ref == "myapp" }!
        #expect(myAppDeps.dependsOn.contains("networkinglib"))
        #expect(myAppDeps.dependsOn.contains("logginglib"))
        #expect(myAppDeps.dependsOn.count == 2)
    }
    
    @Test
    func withTransitiveDependencies_deepChain() throws {
        // Create a deep dependency chain: MyApp -> A -> B -> C -> D
        let graph = try createMockModulesGraphWithTransitiveDeps(
            rootPackageName: "MyApp",
            rootPackageVersion: "1.0.0",
            dependencyChain: [
                ("LibA", "1.0.0", [
                    ("LibB", "2.0.0", [
                        ("LibC", "3.0.0", [
                            ("LibD", "4.0.0", [])
                        ])
                    ])
                ])
            ]
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify all components in the chain are included
        let components = try #require(sbom.components)
        #expect(components.count == 5) // MyApp + LibA + LibB + LibC + LibD
        
        let componentNames = Set(components.map { $0.name })
        #expect(componentNames.contains("myapp"))
        #expect(componentNames.contains("liba"))
        #expect(componentNames.contains("libb"))
        #expect(componentNames.contains("libc"))
        #expect(componentNames.contains("libd"))
        
        // Verify scope classification - only LibA should be direct (required)
        for component in components {
            if component.name == "myapp" {
                #expect(component.scope == "required")
            } else if component.name == "liba" {
                #expect(component.scope == "required", "Direct dependency LibA should have 'required' scope")
            } else {
                #expect(component.scope == "optional", "Transitive dependency \(component.name) should have 'optional' scope")
            }
        }
        
        // Verify complete dependency chain is represented
        let dependencies = try #require(sbom.dependencies)
        #expect(dependencies.count == 4) // All packages except LibD have dependencies
        
        // Verify the chain: MyApp -> LibA -> LibB -> LibC -> LibD
        let myAppDeps = dependencies.first { $0.ref == "myapp" }!
        #expect(myAppDeps.dependsOn == ["liba"])
        
        let libADeps = dependencies.first { $0.ref == "liba" }!
        #expect(libADeps.dependsOn == ["libb"])
        
        let libBDeps = dependencies.first { $0.ref == "libb" }!
        #expect(libBDeps.dependsOn == ["libc"])
        
        let libCDeps = dependencies.first { $0.ref == "libc" }!
        #expect(libCDeps.dependsOn == ["libd"])
    }
    
    @Test
    func withTransitiveDependencies_noDuplicates() throws {
        // Test that shared transitive dependencies are not duplicated
        // MyApp -> [LibA, LibB]
        // LibA -> SharedLib
        // LibB -> SharedLib (same shared dependency)
        let graph = try createMockModulesGraphWithTransitiveDeps(
            rootPackageName: "MyApp",
            rootPackageVersion: "1.0.0",
            dependencyChain: [
                ("LibA", "1.0.0", [("SharedLib", "2.0.0", [])]),
                ("LibB", "1.0.0", [("SharedLib", "2.0.0", [])])
            ]
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify SharedLib appears only once
        let components = try #require(sbom.components)
        #expect(components.count == 4) // MyApp + LibA + LibB + SharedLib (no duplicates)
        
        let sharedLibComponents = components.filter { $0.name == "sharedlib" }
        #expect(sharedLibComponents.count == 1, "SharedLib should appear exactly once")
        
        // Verify SharedLib is marked as transitive (optional)
        let sharedLibComponent = sharedLibComponents.first!
        #expect(sharedLibComponent.scope == "optional")
    }
}

// MARK: - Enhanced Helper Functions

/// Creates a mock ModulesGraph with transitive dependencies
private func createMockModulesGraphWithTransitiveDeps(
    rootPackageName: String,
    rootPackageVersion: String,
    dependencyChain: [(name: String, version: String, dependencies: [(name: String, version: String, dependencies: [(name: String, version: String, dependencies: Any)])])]
) throws -> ModulesGraph {
    var allPackages: [(name: String, version: String, dependencies: [String])] = []
    var processedPackages: Set<String> = []
    
    // Flatten the dependency chain into a list of packages with their direct dependencies
    func processDependency(_ name: String, _ version: String, _ deps: [(name: String, version: String, dependencies: Any)]) {
        if processedPackages.contains(name) {
            return // Avoid duplicates
        }
        processedPackages.insert(name)
        
        let directDeps = deps.map { $0.name }
        allPackages.append((name: name, version: version, dependencies: directDeps))
        
        // Recursively process transitive dependencies
        for dep in deps {
            if let transitiveDeps = dep.dependencies as? [(name: String, version: String, dependencies: [(name: String, version: String, dependencies: Any)])] {
                processDependency(dep.name, dep.version, transitiveDeps)
            } else if let transitiveDeps = dep.dependencies as? [(name: String, version: String, dependencies: Any)] {
                processDependency(dep.name, dep.version, transitiveDeps)
            }
        }
    }
    
    // Process all dependencies starting from the root
    let rootDirectDeps = dependencyChain.map { $0.name }
    allPackages.append((name: rootPackageName, version: rootPackageVersion, dependencies: rootDirectDeps))
    
    for rootDep in dependencyChain {
        processDependency(rootDep.name, rootDep.version, rootDep.dependencies)
    }
    
    // Create file system with proper source file structure
    var emptyFiles: [String] = []
    
    // Add source files for all packages
    for pkg in allPackages {
        emptyFiles.append("/\(pkg.name)/Sources/\(pkg.name)/\(pkg.name).swift")
    }
    
    let fs = InMemoryFileSystem(emptyFiles: emptyFiles)
    
    // Create manifests for all packages
    var manifests: [Manifest] = []
    
    // Create root package manifest
    let rootManifest = Manifest.createRootManifest(
        displayName: rootPackageName,
        path: "/\(rootPackageName)",
        version: Version(rootPackageVersion)!,
        toolsVersion: .v5_5,
        dependencies: rootDirectDeps.map { .fileSystem(path: "/\($0)") },
        targets: [
            try TargetDescription(name: rootPackageName)
        ]
    )
    manifests.append(rootManifest)
    
    // Create dependency manifests
    for pkg in allPackages where pkg.name != rootPackageName {
        let depManifest = Manifest.createFileSystemManifest(
            displayName: pkg.name,
            path: "/\(pkg.name)",
            version: Version(pkg.version)!,
            toolsVersion: .v5_5,
            dependencies: pkg.dependencies.map { .fileSystem(path: "/\($0)") },
            products: [
                try ProductDescription(name: pkg.name, type: .library(.automatic), targets: [pkg.name])
            ],
            targets: [
                try TargetDescription(name: pkg.name)
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
