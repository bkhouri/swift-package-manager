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
import Foundation
import Basics
import SbomSupport
import Testing

import enum TSCBasic.JSON

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct OutputSBOMTests {
    @Test
    func cyclonedxFormat_toFile() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0"
        )
        
        let sbom = try generateSBOM(from: graph)
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/sbom.json")
        
        try outputSBOM(
            sbom,
            specification: .cyclonedx,
            outputPath: outputPath,
            fileSystem: mockFileSystem
        )
        
        // Verify file was written
        #expect(mockFileSystem.exists(outputPath))
        
        // Verify JSON content
        let data = try mockFileSystem.readFileContents(outputPath)
        let json = try JSON(data: Data(data.contents))
        
        #expect(json["bomFormat"]?.string == "CycloneDX")
        #expect(json["specVersion"]?.string == "1.4")
        #expect(json["metadata"]?["component"]?["name"]?.string == "testapp")
    }
    
    @Test
    func spdxFormat_toFile() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0",
            dependencies: [
                (name: "TestDep", version: "2.0.0")
            ]
        )
        
        let sbom = try generateSBOM(from: graph)
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/sbom.spdx.json")
        
        try outputSBOM(
            sbom,
            specification: .spdx,
            outputPath: outputPath,
            fileSystem: mockFileSystem
        )
        
        // Verify file was written
        #expect(mockFileSystem.exists(outputPath))
        
        // Verify SPDX JSON content
        let data = try mockFileSystem.readFileContents(outputPath)
        let json = try JSON(data: Data(data.contents))
        
        #expect(json["spdxVersion"]?.string == "SPDX-2.3")
        #expect(json["dataLicense"]?.string == "CC0-1.0")
        #expect(json["name"]?.string == "testapp")
        #expect(json["packages"]?.array?.count == 2)
    }
    
    @Test
    func yclonedxFormat_prettyPrinted() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0"
        )
        
        let sbom = try generateSBOM(from: graph)
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/sbom.json")
        
        try outputSBOM(
            sbom,
            specification: .cyclonedx,
            outputPath: outputPath,
            fileSystem: mockFileSystem
        )
        
        // Verify file was written and is pretty printed
        let data = try mockFileSystem.readFileContents(outputPath)
        let jsonString = String(decoding: data.contents, as: UTF8.self)
        
        // Pretty printed JSON should contain newlines and indentation
        #expect(jsonString.contains("\n"))
        #expect(jsonString.contains("  ")) // Indentation
    }
    
    @Test
    func sbomJSONValidation_validSBOM() throws {
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0"
        )
        
        let sbom = try generateSBOM(from: graph)
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/sbom.json")
        
        // This should succeed with validation
        try outputSBOM(
            sbom,
            specification: .cyclonedx,
            outputPath: outputPath,
            fileSystem: mockFileSystem
        )
        
        // Verify file was written
        #expect(mockFileSystem.exists(outputPath))
        
        // Verify JSON content has required fields
        let data = try mockFileSystem.readFileContents(outputPath)
        let json = try JSON(data: Data(data.contents))
        
        #expect(json["bomFormat"]?.string == "CycloneDX")
        #expect(json["specVersion"]?.string == "1.4")
        #expect(json["serialNumber"]?.string?.hasPrefix("urn:uuid:") == true)
        // Just check that version exists and is not nil
        #expect(json["version"] != nil)
    }
    
    @Test
    func sbomJSONValidation_invalidBomFormat() throws {
        // Create an invalid SBOM with wrong bomFormat
        let invalidSBOM = SBOMDocument(
            bomFormat: "InvalidFormat", // Should be "CycloneDX"
            specVersion: "1.6",
            serialNumber: "urn:uuid:\(UUID().uuidString)",
            version: 1,
            metadata: nil,
            components: nil,
            dependencies: nil
        )
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/invalid-sbom.json")
        
        // This should throw an error due to invalid bomFormat
        #expect(throws: (any Error).self) {
            try outputSBOM(
                invalidSBOM,
                specification: .cyclonedx,
                outputPath: outputPath,
                fileSystem: mockFileSystem
            )
        }
    }
    
    @Test
    func sbomJSONValidation_invalidSpecVersion() throws {
        // Create an invalid SBOM with wrong specVersion format
        let invalidSBOM = SBOMDocument(
            bomFormat: "CycloneDX",
            specVersion: "invalid-version", // Should be like "1.4"
            serialNumber: "urn:uuid:\(UUID().uuidString)",
            version: 1,
            metadata: nil,
            components: nil,
            dependencies: nil
        )
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/invalid-spec-sbom.json")
        
        // This should throw an error due to invalid specVersion
        #expect(throws: (any Error).self) {
            try outputSBOM(
                invalidSBOM,
                specification: .cyclonedx,
                outputPath: outputPath,
                fileSystem: mockFileSystem
            )
        }
    }
    
    @Test
    func sbomJSONValidation_invalidSerialNumber() throws {
        // Create an invalid SBOM with wrong serialNumber format
        let invalidSBOM = SBOMDocument(
            bomFormat: "CycloneDX",
            specVersion: "1.4",
            serialNumber: "invalid-uuid-format", // Should be "urn:uuid:..."
            version: 1,
            metadata: nil,
            components: nil,
            dependencies: nil
        )
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/invalid-serial-sbom.json")
        
        // This should throw an error due to invalid serialNumber
        #expect(throws: (any Error).self) {
            try outputSBOM(
                invalidSBOM,
                specification: .cyclonedx,
                outputPath: outputPath,
                fileSystem: mockFileSystem
            )
        }
    }
    
    @Test
    func sbomJSONValidation_spdxSkipsValidation() throws {
        // SPDX format should skip CycloneDX validation
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0"
        )
        
        let sbom = try generateSBOM(from: graph)
        
        let mockFileSystem = InMemoryFileSystem()
        let outputPath = AbsolutePath("/output/sbom.spdx.json")
        
        // This should succeed without CycloneDX validation
        try outputSBOM(
            sbom,
            specification: .spdx,
            outputPath: outputPath,
            fileSystem: mockFileSystem
        )
        
        // Verify file was written
        #expect(mockFileSystem.exists(outputPath))
    }
}
