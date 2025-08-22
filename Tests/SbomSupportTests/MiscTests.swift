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

import enum TSCBasic.JSON

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct VariousSbomTests {
    @Test
    func integration_complexDependencyGraph() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "ComplexApp",
            rootPackageVersion: "3.2.1",
            dependencies: [
                (name: "NetworkingKit", version: "4.1.0"),
                (name: "LoggingFramework", version: "2.3.4"),
                (name: "UtilityLibrary", version: "1.0.5"),
                (name: "TestingHelpers", version: nil) // Unversioned dependency
            ]
        )
        
        
        // Test full pipeline: generate -> convert -> output
        let cycloneDX = try generateSBOM(from: graph)
        let _ = convertToSPDX(cycloneDX)
        
        let mockFileSystem = InMemoryFileSystem()
        let cyclonDXPath = AbsolutePath("/output/cyclonedx.json")
        let spdxPath = AbsolutePath("/output/spdx.json")
        
        // Output both formats
        try outputSBOM(cycloneDX, specification: .cyclonedx, outputPath: cyclonDXPath, fileSystem: mockFileSystem)
        try outputSBOM(cycloneDX, specification: .spdx, outputPath: spdxPath, fileSystem: mockFileSystem)
        
        // Verify both files exist
        #expect(mockFileSystem.exists(cyclonDXPath))
        #expect(mockFileSystem.exists(spdxPath))
        
        // Verify CycloneDX content
        let cyclonDXData = try mockFileSystem.readFileContents(cyclonDXPath)
        let cyclonDXJson = try JSON(data: Data(cyclonDXData.contents))
        #expect(cyclonDXJson["components"]?.array?.count == 5) // Root + 4 dependencies
        
        // Verify SPDX content
        let spdxData = try mockFileSystem.readFileContents(spdxPath)
        let spdxJson = try JSON(data: Data(spdxData.contents))
        #expect(spdxJson["packages"]?.array?.count == 5) // Root + 4 dependencies
        
        // Verify unversioned dependency handling
        let testingHelpersPackage = spdxJson["packages"]?.array?.first { pkg in
            pkg.dictionary?["name"]?.string == "testinghelpers"
        }
        #expect(testingHelpersPackage?.dictionary?["versionInfo"]?.string == "unknown")
    }
    
    @Test
    func integration_emptyDependencies() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "StandaloneApp",
            rootPackageVersion: "1.0.0",
            dependencies: []
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify minimal SBOM structure
        let dependencies = try #require(sbom.dependencies)
        let components = try #require(sbom.components)
        #expect(components.count == 1)
        #expect(dependencies.isEmpty)
        
        // Test conversion to SPDX
        let spdx = convertToSPDX(sbom)
        #expect(spdx.packages.count == 1)
        #expect(spdx.packages.first?.name == "standaloneapp")
    }
    
    // MARK: - Error Handling Tests
    
    @Test(
        .tags(
            .TestSize.small,
        ),
    )
    func errorHandling_invalidFileSystemPath() throws {
        let graph = try createMockModulesGraph()
        let sbom = try generateSBOM(from: graph)
        
        let invalidPath = AbsolutePath.root.appending(components: ["nonexistent", "directory", "sbom.json"])

        expectFileDoesNotExists(at: invalidPath)
        // This should handle the error gracefully
        #expect(throws: (any Error).self) {
            try outputSBOM(
                sbom,
                specification: .cyclonedx,
                outputPath: invalidPath,
                fileSystem: localFileSystem,
            )
        }
    }
    
    // MARK: - Data Structure Tests
    @Suite(
        .tags(
            .TestSize.small,
        ),
    )
    struct DataStructuresTets {
        @Test(
            arguments: [0,1, 2, 10,
            ],
            [0, 1, 2, 10,],
        )
        func sbomDocumentSerialization(
            numberOfComponents: Int,
            numberOfDependencies: Int,
        ) throws {
            let metadataComponentName = "MetadataTestComponent"
            let metadata = SBOMMetadata(
                timestamp: "2025-01-01T00:00:00Z",
                component: SBOMComponent(
                    type: .library,
                    bomRef: "test-ref",
                    name: metadataComponentName,
                    version: "200.0.0",
                    scope: "required"
                ),
            )
            
            let components = (0 ..< numberOfComponents).map { index in
                SBOMComponent(
                    type: .library,
                    bomRef: "test-ref",
                    name: "TestComponent_\(index)",
                    version: "1.0.\(index)",
                    scope: "required"
                )
            }
            let dependencies = (0 ..< numberOfDependencies).map { index in 
                SBOMDependency(
                    ref: "test-ref_\(index)",
                    dependsOn: ["dep1", "dep2"]
                )
            }

            let document = SBOMDocument(
                bomFormat: "CycloneDX",
                specVersion: "1.4",
                serialNumber: "urn:uuid:test-uuid",
                version: 1,
                metadata: metadata,
                components: components,
                dependencies: dependencies,
            )
            
            // Test JSON serialization
            let encoder = JSONEncoder()
            let data = try encoder.encode(document)
            
            // Test deserialization
            let decoder = JSONDecoder()
            let decodedDocument = try decoder.decode(SBOMDocument.self, from: data)
            
            #expect(components.count == numberOfComponents)
            #expect(dependencies.count == numberOfDependencies)
            #expect(decodedDocument.bomFormat == "CycloneDX")
            let decodedComponents = try #require(decodedDocument.components)
            #expect(decodedComponents.count == numberOfComponents, "Decoded not equal to what was set")
            let deps = try #require(decodedDocument.dependencies)
            #expect(deps.count == numberOfDependencies, "Decoded not equal to what was set")
            let actualMetadata = try #require(decodedDocument.metadata)
            let actualComponent = try #require(actualMetadata.component)
            #expect(actualComponent.name == metadataComponentName)

            #expect(document == decodedDocument, "Actual is not as expected")
        }
        
        @Test(
            arguments: [0, 1, 2, 10],
        )
        func spdxDocumentSerialization(
            numberOfPackages: Int,
        ) throws {
            let creationInfo = SPDXCreationInfo(
                created: "2025-01-01T00:00:00Z",
                creators: ["Tool: swift-package-manager"]
            )
            
            let packages = (0 ..< numberOfPackages).map { index in
                SPDXPackage(
                    spdxId: "SPDXRef-TestPackage_\(index)",
                    name: "TestPackage_\(index)",
                    downloadLocation: "NOASSERTION",
                    filesAnalyzed: false,
                    versionInfo: "1.0.\(index)"
                )
            }
            #expect(packages.count == numberOfPackages)

            let document = SPDXDocument(
                spdxVersion: "SPDX-2.3",
                dataLicense: "CC0-1.0",
                spdxId: "SPDXRef-DOCUMENT",
                name: "TestDocument",
                documentNamespace: "https://swift.org/test",
                creationInfo: creationInfo,
                packages: packages
            )
            
            // Test JSON serialization
            let encoder = JSONEncoder()
            let data = try encoder.encode(document)
            
            // Test deserialization
            let decoder = JSONDecoder()
            let decodedDocument = try decoder.decode(SPDXDocument.self, from: data)
            
            #expect(decodedDocument.spdxVersion == "SPDX-2.3")
            #expect(decodedDocument.packages.count == numberOfPackages)
            #expect(decodedDocument.creationInfo.creators == ["Tool: swift-package-manager"])

            #expect(decodedDocument == document)
        }
    }
    
    // MARK: - SBOM Specification Tests
    @Suite(
        .tags(
            .TestSize.small,
        ),
    )
    struct SBomSpecificationTests {
        @Test(
            arguments: [
                (
                    format: SBomSpecification.cyclonedx,
                    expectedFormat: "cyclonedx",
                    expectedDescription: "CycloneDX",
                ),
                (
                    format: .spdx,
                    expectedFormat: "spdx",
                    expectedDescription: "SPDX",
                ),
            ]
        )
        func formats_enumValues(
            format: SBomSpecification,
            expectedFormat: String,
            expectedDescription: String,
        ) {
            #expect(format.rawValue == expectedFormat)
            #expect(format.description == expectedDescription)
        }
    }
    
    // MARK: - License Tests
    @Suite(
        .tags(
            .TestSize.small,
        ),
    )
    struct LicenseTests {
        @Test
        func licenseStructures_serialization() throws {
            // Test SBOMLicenseText
            let licenseText = SBOMLicenseText(
                content: "Apache License 2.0 text here",
                encoding: .base64,
                contentType: "text/plain"
            )
            
            // Test SBOMLicenseID with id
            let licenseWithId = SBOMLicenseID(
                id: "Apache-2.0",
                url: "https://apache.org/licenses/LICENSE-2.0"
            )
            
            // Test SBOMLicenseName with name
            let licenseWithName = SBOMLicenseName(
                name: "Apache License 2.0",
                text: licenseText,
                url: "https://apache.org/licenses/LICENSE-2.0"
            )
            
            // Test SBOMLicenseChoice variants
            let expressionChoice = SBOMLicenseChoice.expression("MIT OR Apache-2.0")
            let licenseIDChoice = SBOMLicenseChoice.licenseID(licenseWithId)
            let licenseNameChoice = SBOMLicenseChoice.licenseName(licenseWithName)
            
            // Test SBOMComponent with licenses
            let component = SBOMComponent(
                type: .library,
                bomRef: "test-component",
                name: "TestLibrary",
                version: "1.0.0",
                scope: "required",
                licenses: [expressionChoice, licenseIDChoice, licenseNameChoice]
            )
            
            // Test JSON serialization
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let componentData = try encoder.encode(component)
            let licenseTextData = try encoder.encode(licenseText)
            let licenseIDData = try encoder.encode(licenseWithId)
            let licenseNameData = try encoder.encode(licenseWithName)
            
            // Test deserialization
            let decoder = JSONDecoder()
            let decodedComponent = try decoder.decode(SBOMComponent.self, from: componentData)
            let decodedLicenseText = try decoder.decode(SBOMLicenseText.self, from: licenseTextData)
            let decodedLicenseID = try decoder.decode(SBOMLicenseID.self, from: licenseIDData)
            let decodedLicenseName = try decoder.decode(SBOMLicenseName.self, from: licenseNameData)
            
            // Verify structure
            #expect(decodedComponent.licenses?.count == 3)
            #expect(decodedLicenseText.content == "Apache License 2.0 text here")
            #expect(decodedLicenseText.encoding == .base64)
            #expect(decodedLicenseID.id == "Apache-2.0")
            #expect(decodedLicenseID.url == "https://apache.org/licenses/LICENSE-2.0")
            #expect(decodedLicenseName.name == "Apache License 2.0")
            #expect(decodedLicenseName.url == "https://apache.org/licenses/LICENSE-2.0")
            
            // Verify equality
            #expect(component == decodedComponent)
            #expect(licenseText == decodedLicenseText)
            #expect(licenseWithId == decodedLicenseID)
            #expect(licenseWithName == decodedLicenseName)
        }
        
        @Test 
        func licenseConversion_toSPDX() throws {
            // Create component with various license types
            let licenses: [SBOMLicenseChoice] = [
                .expression("MIT"),
                .expression("Apache-2.0"),
                .licenseID(SBOMLicenseID(id: "GPL-3.0")),
                .licenseName(SBOMLicenseName(name: "Custom License"))
            ]
            
            let component = SBOMComponent(
                type: .library,
                bomRef: "test-lib",
                name: "TestLibrary",
                version: "1.0.0",
                scope: "required",
                licenses: licenses
            )
            
            let sbom = SBOMDocument(
                bomFormat: "CycloneDX",
                specVersion: "1.4",
                version: 1,
                components: [component]
            )
            
            // Convert to SPDX
            let spdx = convertToSPDX(sbom)
            
            // Verify license information is preserved
            #expect(spdx.packages.count == 1)
            let package = spdx.packages.first!
            
            // Should combine all licenses with AND
            let expectedLicense = "MIT AND Apache-2.0 AND GPL-3.0 AND Custom License"
            #expect(package.licenseConcluded == expectedLicense)
            #expect(package.licenseDeclared == expectedLicense)
        }
        
        @Test
        func licenseConversion_emptyLicenses() throws {
            let component = SBOMComponent(
                type: .library,
                bomRef: "test-lib",
                name: "TestLibrary",
                version: "1.0.0",
                scope: "required",
                licenses: nil
            )
            
            let sbom = SBOMDocument(
                bomFormat: "CycloneDX",
                specVersion: "1.4",
                version: 1,
                components: [component]
            )
            
            // Convert to SPDX
            let spdx = convertToSPDX(sbom)
            
            // Verify default license handling
            let package = spdx.packages.first!
            #expect(package.licenseConcluded == "NOASSERTION")
            #expect(package.licenseDeclared == "NOASSERTION")
        }
    }
}