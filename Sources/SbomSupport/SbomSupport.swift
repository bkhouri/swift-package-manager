//===----------------------------------------------------------------------===//
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
import Foundation
import struct TSCBasic.StringError
import struct TSCBasic.ByteString
import JSONSchema

import Basics
import PackageGraph
import PackageModel
import SourceControl

// import class TSCBasic.LocalFileOutputByteStream
// import protocol TSCBasic.OutputByteStream
// import var TSCBasic.stdoutStream
// import struct TSCUtility.Version

package enum SBomSpecification: String, CaseIterable {
    case cyclonedx = "cyclonedx"
    case spdx = "spdx"

    package var description: String {
        switch self {
        case .cyclonedx: return "CycloneDX"
        case .spdx: return "SPDX"
        }
    }
}

// MARK: - License Extraction

/// Extracts license information from a package by checking common license files and sources
internal func extractLicenseInformation(from package: ResolvedPackage, fileSystem: FileSystem = localFileSystem) -> [SBOMLicenseChoice]? {
    var licenses: [SBOMLicenseChoice] = []
    
    // Common license file names to check
    let licenseFileNames = [
        "LICENSE", "LICENSE.txt", "LICENSE.md", "LICENSE.rst",
        "LICENCE", "LICENCE.txt", "LICENCE.md", "LICENCE.rst",
        "COPYING", "COPYING.txt", "COPYING.md",
        "COPYRIGHT", "COPYRIGHT.txt", "COPYRIGHT.md"
    ]
    
    // Check for license files in the package directory
    for fileName in licenseFileNames {
        let licensePath = package.path.appending(component: fileName)
        if fileSystem.exists(licensePath) {
            do {
                let licenseContent = try fileSystem.readFileContents(licensePath).cString
                
                // Try to detect license type from content
                let detectedLicense = detectLicenseFromContent(licenseContent)
                if let license = detectedLicense {
                    licenses.append(license)
                } else {
                    // If we can't detect the specific license, create a generic one
                    let license = SBOMLicenseName(
                        name: "License from \(fileName)",
                        text: SBOMLicenseText(content: licenseContent)
                    )
                    licenses.append(.licenseName(license))
                }
                break // Use the first license file found
            } catch {
                // Continue to next file if this one can't be read
                continue
            }
        }
    }
    
    // Check for common license expressions in README files
    if licenses.isEmpty {
        let readmeFileNames = ["README.md", "README.txt", "README.rst", "README"]
        for fileName in readmeFileNames {
            let readmePath = package.path.appending(component: fileName)
            if fileSystem.exists(readmePath) {
                do {
                    let readmeContent = try fileSystem.readFileContents(readmePath).cString
                    if let licenseExpression = extractLicenseFromReadme(readmeContent) {
                        licenses.append(.expression(licenseExpression))
                        break
                    }
                } catch {
                    continue
                }
            }
        }
    }
    
    // Check Package.swift for license information (future enhancement)
    // This could be extended to parse comments or metadata in Package.swift
    
    return licenses.isEmpty ? nil : licenses
}

/// Detects license type from license file content
internal func detectLicenseFromContent(_ content: String) -> SBOMLicenseChoice? {
    let lowercaseContent = content.lowercased()
    
    // Common license patterns - order matters, more specific patterns first
    let licensePatterns: [(id: String, name: String, patterns: [String])] = [
        (id: "Apache-2.0", name: "Apache License 2.0", patterns: [
            "apache license",
            "version 2.0",
            "apache software foundation"
        ]),
        (id: "GPL-3.0", name: "GNU General Public License v3.0", patterns: [
            "version 3, 29 june 2007",
            "version 3",
            "gplv3"
        ]),
        (id: "GPL-2.0", name: "GNU General Public License v2.0", patterns: [
            "version 2, june 1991",
            "version 2",
            "gplv2"
        ]),
        (id: "BSD-3-Clause", name: "BSD 3-Clause License", patterns: [
            "bsd 3-clause license",
            "bsd license",
            "3-clause"
        ]),
        (id: "BSD-2-Clause", name: "BSD 2-Clause License", patterns: [
            "bsd 2-clause license",
            "bsd license",
            "2-clause"
        ]),
        (id: "ISC", name: "ISC License", patterns: [
            "isc license",
            "permission to use, copy, modify, and/or distribute"
        ]),
        (id: "MIT", name: "MIT License", patterns: [
            "mit license",
            "permission is hereby granted, free of charge"
        ])
    ]
    
    for licenseInfo in licensePatterns {
        let matchCount = licenseInfo.patterns.reduce(0) { count, pattern in
            return count + (lowercaseContent.contains(pattern) ? 1 : 0)
        }
        
        // If we match at least half of the patterns, consider it a match
        if matchCount >= max(1, licenseInfo.patterns.count / 2) {
            // Prefer ID-based license if we have a standard SPDX ID
            return .licenseID(SBOMLicenseID(
                id: licenseInfo.id,
                text: SBOMLicenseText(content: content)
            ))
        }
    }
    
    return nil
}

/// Extracts license expressions from README content
internal func extractLicenseFromReadme(_ content: String) -> String? {
    let lowercaseContent = content.lowercased()
    
    // Common license expressions in README files
    let licenseExpressions = [
        "mit", "apache-2.0", "gpl-3.0", "gpl-2.0", "bsd-3-clause", "bsd-2-clause", "isc"
    ]
    
    for expression in licenseExpressions {
        if lowercaseContent.contains("license: \(expression)") ||
           lowercaseContent.contains("licensed under \(expression)") ||
           lowercaseContent.contains("\(expression) license") {
            return expression.uppercased()
        }
    }
    
    return nil
}

/// Extracts HEAD commit information from a Git repository
internal func extractHeadCommitInfo(from package: ResolvedPackage, fileSystem: FileSystem = localFileSystem) -> SBOMCommit? {
    // Check if the package path is a Git repository
    guard fileSystem.exists(package.path.appending(".git")) else {
        return nil
    }
    
    do {
        let gitRepo = GitRepository(path: package.path)
        
        // Get current revision (HEAD commit hash)
        let currentRevision = try gitRepo.getCurrentRevision()
        
        // Use AsyncProcess directly to get commit details since callGit is private
        let process = AsyncProcess(
            arguments: ["git", "-C", package.path.pathString, "log", "-1", "--format=%H|%aN|%ae|%aI|%cN|%ce|%cI|%B", currentRevision.identifier],
            environment: .current,
            outputRedirection: .collect
        )
        
        try process.launch()
        let result = try process.waitUntilExit()
        
        guard result.exitStatus == .terminated(code: 0) else {
            return nil
        }
        
        let commitInfo = try result.utf8Output().spm_chomp()
        let numItems = 8
        let parts = commitInfo.split(separator: "|", maxSplits: numItems)
        guard parts.count == numItems else {
            return nil
        }
        
        let commitHash = String(parts[0])
        let authorName = String(parts[1])
        let authorEmail = String(parts[2])
        let authorTimestamp = String(parts[3])
        let committerName = String(parts[4])
        let committerEmail = String(parts[5])
        let committerTimestamp = String(parts[6])
        let message = String(parts[7])
        
        return SBOMCommit(
            uid: commitHash,
            url: nil, // We don't have the remote URL context here
            author: SBOMIdentifiableAction(
                timestamp: authorTimestamp,
                name: authorName,
                email: authorEmail
            ),
            committer: SBOMIdentifiableAction(
                timestamp: committerTimestamp,
                name: committerName,
                email: committerEmail,
            ),
            message: message
        )
        
    } catch {
        // If we can't get Git information, return nil
        return nil
    }
}

/// Creates a pedigree with HEAD commit information for packages without version
internal func createPedigreeWithHeadCommit(from package: ResolvedPackage, fileSystem: FileSystem = localFileSystem) -> SBOMPedigree? {
    guard let commit = extractHeadCommitInfo(from: package, fileSystem: fileSystem) else {
        return nil
    }
    
    return SBOMPedigree(
        ancestors: nil,
        descendants: nil,
        variants: nil,
        commits: [commit],
        patches: nil,
        notes: "HEAD commit information for package without version"
    )
}

package func generateSBOM(from graph: ModulesGraph) throws -> SBOMDocument {
    guard let rootPackage = graph.rootPackages.first else {
        throw StringError("No root package found")
    }

    var components: [SBOMComponent] = []
    var allProducts: IdentifiableSet<ResolvedProduct> = []

    // Collect all products from all packages (root + dependencies)
    func collectAllProducts(from package: ResolvedPackage, visited: inout Set<PackageIdentity>) {
        if !visited.contains(package.identity) {
            visited.insert(package.identity)
            
            // Add all products from this package
            for product in package.products {
                if !product.includeInSbom { continue}
                allProducts.insert(product)
            }
            
            // Recursively collect from dependencies
            let directDeps = graph.directDependencies(for: package)
            for dependencyPackage in directDeps {
                collectAllProducts(from: dependencyPackage, visited: &visited)
            }
        }
    }

    // Collect all products starting from root packages
    var visited: Set<PackageIdentity> = []
    for rootPkg in graph.rootPackages {
        collectAllProducts(from: rootPkg, visited: &visited)
    }

    // Create components for all products
    for product in allProducts {
        // if let product = graph.allProducts.first(where: { $0.id == productId }) {
            let package: ResolvedPackage = graph.package(for: product.packageIdentity)!
            let productVersion = package.manifest.version?.description ?? "unknown"
            let productLicenses = extractLicenseInformation(from: package)
            
            // Determine if this is from root package or dependency
            let isFromRootPackage = graph.rootPackages.contains { $0.identity == product.packageIdentity }
            let scope = isFromRootPackage ? "required" : "optional"
            
            let productPedigree = productVersion == "unknown" ? createPedigreeWithHeadCommit(from: package) : nil
            
            // Determine component type based on product type
            let componentType: SBOMType = switch product.type {
            case .executable, .snippet: .application
            case .library, .macro, .plugin, .test: .library
            }
            
            components.append(
                SBOMComponent(
                    type: componentType,
                    bomRef: "\(product.id)",
                    // bomRef: "\(product.packageIdentity.description):\(product.name)",
                    name: product.name,
                    version: productVersion,
                    scope: scope,
                    licenses: productLicenses,
                    pedigree: productPedigree
                )
            )
        // }
    }

    // Create dependency relationships between products
    var dependencies: [SBOMDependency] = []
    
    for product in allProducts {
        // if let product = graph.allProducts.first(where: { $0.id == productId }) {
            var productDependencies: [String] = []
            
            // Find products that this product depends on through its modules
            for module in product.modules {
                for dependency in module.dependencies {
                    switch dependency {
                    case .product(let dependentProduct, _):
                        let dependentProductRef = "\(dependentProduct.packageIdentity.description):\(dependentProduct.name)"
                        if !productDependencies.contains(dependentProductRef) {
                            productDependencies.append(dependentProductRef)
                        }
                    case .module(let dependentModule, _):
                        // Find which product contains this module
                        if let containingProduct = graph.allProducts.first(where: { $0.modules.contains(id: dependentModule.id) }) {
                            let containingProductRef = "\(containingProduct.packageIdentity.description):\(containingProduct.name)"
                            if containingProductRef != "\(product.packageIdentity.description):\(product.name)" && !productDependencies.contains(containingProductRef) {
                                productDependencies.append(containingProductRef)
                            }
                        }
                    }
                }
            }
            
            if !productDependencies.isEmpty {
                dependencies.append(
                    SBOMDependency(
                        ref: "\(product.packageIdentity.description):\(product.name)",
                        dependsOn: productDependencies
                    )
                )
            }
        // }
    }

    // Create metadata based on root package (as requested)
    let rootVersion = rootPackage.manifest.version?.description ?? "unknown"
    let rootLicenses = extractLicenseInformation(from: rootPackage)
    let rootPedigree = rootVersion == "unknown" ? createPedigreeWithHeadCommit(from: rootPackage) : nil
    
    let types = rootPackage.products.map { $0.type }
    let sbomMetadataType: SBOMType = if types.contains(.executable) {
        .application
    } else {
        .library
    }

    return SBOMDocument(
        bomFormat: "CycloneDX",
        specVersion: "1.4",
        serialNumber: "urn:uuid:\(UUID().uuidString)".lowercased(),
        version: 1,
        metadata: SBOMMetadata(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            component: SBOMComponent(
                type: sbomMetadataType,
                bomRef: rootPackage.identity.description,
                name: rootPackage.identity.description,
                version: rootVersion,
                scope: "required",
                licenses: rootLicenses,
                pedigree: rootPedigree
            )
        ),
        components: components,
        dependencies: dependencies
    )
}

/// Performs enhanced structural validation of SBOM JSON
private func performEnhancedValidation(_ jsonData: Foundation.Data) throws {
    let generatedJSON = try JSONSerialization.jsonObject(with: jsonData, options: [])
    
    // Enhanced validation - check required fields and structure
    guard let jsonDict = generatedJSON as? [String: Any] else {
        throw StringError("Generated JSON is not a valid object")
    }
    
    // Validate required fields according to CycloneDX schema
    let requiredFields = ["bomFormat", "specVersion"]
    for field in requiredFields {
        guard jsonDict[field] != nil else {
            throw StringError("Missing required field '\(field)' in generated SBOM")
        }
    }
    
    // Validate bomFormat value
    if let bomFormat = jsonDict["bomFormat"] as? String, bomFormat != "CycloneDX" {
        throw StringError("Invalid bomFormat value: '\(bomFormat)'. Expected 'CycloneDX'")
    }
    
    // Validate specVersion format
    if let specVersion = jsonDict["specVersion"] as? String {
        // Basic version format validation
        let versionPattern = #"^\d+\.\d+$"#
        let regex = try NSRegularExpression(pattern: versionPattern)
        let range = NSRange(location: 0, length: specVersion.utf16.count)
        if regex.firstMatch(in: specVersion, options: [], range: range) == nil {
            throw StringError("Invalid specVersion format: '\(specVersion)'. Expected format like '1.4' or '1.6'")
        }
    }
    
    // Validate serialNumber format if present
    if let serialNumber = jsonDict["serialNumber"] as? String {
        let uuidPattern = #"^urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"#
        let regex = try NSRegularExpression(pattern: uuidPattern, options: .caseInsensitive)
        let range = NSRange(location: 0, length: serialNumber.utf16.count)
        if regex.firstMatch(in: serialNumber, options: [], range: range) == nil {
            throw StringError("Invalid serialNumber format: '\(serialNumber)'. Expected UUID format like 'urn:uuid:...'")
        }
    }
    
    // Validate version is a positive integer
    if let version = jsonDict["version"] as? Int, version < 1 {
        throw StringError("Invalid version value: \(version). Expected positive integer >= 1")
    }
    
    // Validate metadata structure if present
    if let metadata = jsonDict["metadata"] as? [String: Any] {
        if let timestamp = metadata["timestamp"] as? String {
            // Validate ISO8601 timestamp format
            let timestampFormatter = ISO8601DateFormatter()
            if timestampFormatter.date(from: timestamp) == nil {
                throw StringError("Invalid timestamp format in metadata: '\(timestamp)'. Expected ISO8601 format")
            }
        }
    }
    
    // Validate components array structure if present
    if let components = jsonDict["components"] as? [[String: Any]] {
        for (index, component) in components.enumerated() {
            // Check required component fields
            let requiredComponentFields = ["type", "name"]
            for field in requiredComponentFields {
                guard component[field] != nil else {
                    throw StringError("Missing required field '\(field)' in component at index \(index)")
                }
            }
            
            // Validate component type
            if let type = component["type"] as? String {
                let validTypes = ["application", "framework", "library", "container", "operating-system", "device", "firmware", "file"]
                if !validTypes.contains(type) {
                    throw StringError("Invalid component type '\(type)' at index \(index). Must be one of: \(validTypes.joined(separator: ", "))")
                }
            }
        }
    }
    
    print("✓ SBOM JSON validation passed (structural validation)")
}

/// Validates JSON data against the CycloneDX schema using JSONSchema library
package func validateSBOMJSON(_ jsonData: Foundation.Data, specification: SBomSpecification, fileSystem: FileSystem) throws {
    // Only validate CycloneDX format for now
    guard specification == .cyclonedx else {
        return
    }
    
    // Try to find the schema file using Bundle resources first, then fallback to file paths
    var schemaData: Foundation.Data?
    let bomSchemaVersion = "1.6"
    
    // First try to load from Bundle resources
    if let bundleSchemaURL = Bundle.module.url(forResource: "bom-\(bomSchemaVersion).schema", withExtension: "json", subdirectory: "CycloneDX") {
        do {
            schemaData = try Data(contentsOf: bundleSchemaURL)
        } catch {
            // Continue to file system approach
        }
    }
    
    // If Bundle approach failed, try file system paths
    // if schemaData == nil {
    //     let possiblePaths = [
    //         try AbsolutePath(validating: #filePath).parentDirectory.appending(components: "Resources", "CycloneDX", "bom-\(bomSchemaVersion).schema.json"),
    //         try AbsolutePath(validating: #filePath).parentDirectory.appending(components: "resources", "CycloneDX", "bom-\(bomSchemaVersion).schema.json")
    //     ]
        
    //     for path in possiblePaths {
    //         if fileSystem.exists(path) {
    //             do {
    //                 let schemaByteString = try fileSystem.readFileContents(path)
    //                 schemaData = Foundation.Data(schemaByteString.contents)
    //                 break
    //             } catch {
    //                 continue
    //             }
    //         }
    //     }
    // }
    
    guard let validSchemaData = schemaData else {
        print("Warning: CycloneDX schema file not found. Skipping JSON Schema validation.")
        // Still perform enhanced structural validation even without schema file
        try performEnhancedValidation(jsonData)
        return
    }
    
    do {
        // Parse both schema and generated JSON to ensure they're valid
        _ = try JSONSerialization.jsonObject(with: validSchemaData, options: [])
        _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
         
        // Convert Data to proper JSON strings for the JSONSchema library
        guard let schemaString = String(data: validSchemaData, encoding: .utf8) else {
            throw StringError("Failed to convert schema data to UTF-8 string")
        }
        
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw StringError("Failed to convert JSON data to UTF-8 string")
        }
        
        print("JSON String: \(jsonString)")
        let schema = try Schema(instance: schemaString,)
        let result = try schema.validate(instance: jsonString)
        
        if !result.isValid {
            let errorMessages = result.errors?.map { error in
                "- [\(error.keyword)] \(error.message) at instance location: \(error.instanceLocation)"
            }.joined(separator: "\n") ?? "Unknown validation errors"
            throw StringError("SBOM JSON validation failed:\n\(errorMessages)")
        }
        
        print("✓ SBOM JSON validation passed (schema validation)")
        
    } catch let error as StringError {
        throw error
    } catch {
        throw StringError("SBOM JSON validation failed: \(error.localizedDescription)")
    }
}

package func outputSBOM(
    _ sbom: SBOMDocument,
    specification: SBomSpecification,
    outputPath: AbsolutePath?,
    fileSystem: FileSystem,
) throws {

    // Validate the generated JSON against the schema
    try validateSBOMJSON(
        JSONEncoder().encode(sbom),
        specification: specification,
        fileSystem: fileSystem,
    )


    let dataToEncode: Codable
    switch specification {
    case .cyclonedx:
        dataToEncode = sbom
    case .spdx:
        // For now, convert to SPDX-like format (simplified)
        let spdxDocument = convertToSPDX(sbom)
        dataToEncode = spdxDocument
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    let foundationData = try encoder.encode(dataToEncode)

    if let outputPath = outputPath {
        try fileSystem.writeFileContents(outputPath, bytes: ByteString(foundationData))
        print("Software Bill of Materials (SBOM) written to: \(outputPath)")
    } else {
        print(String(decoding: foundationData, as: UTF8.self))
    }
}

internal func extractLicenseInfo(from licenses: [SBOMLicenseChoice]?) -> (concluded: String?, declared: String?) {
    guard let licenses = licenses, !licenses.isEmpty else {
        return (concluded: "NOASSERTION", declared: "NOASSERTION")
    }
    
    var expressions: [String] = []
    var licenseIds: [String] = []
    
    for license in licenses {
        switch license {
        case .expression(let expression):
            expressions.append(expression)
        case .licenseName(let licenseNameObj):
            licenseIds.append(licenseNameObj.name)
        case .licenseID(let licenseIDObj):
            licenseIds.append(licenseIDObj.id)
        }
    }
    
    // Combine all license information
    let allLicenses = expressions + licenseIds
    let combinedLicense = allLicenses.isEmpty ? "NOASSERTION" : allLicenses.joined(separator: " AND ")
    
    return (concluded: combinedLicense, declared: combinedLicense)
}

package func convertToSPDX(_ cycloneDX: SBOMDocument) -> SPDXDocument {
    // Handle cases where metadata might be nil
    let documentName: String
    let documentNamespace: String
    let createdTimestamp: String
    
    if let metadata = cycloneDX.metadata, let component = metadata.component {
        documentName = component.name
        documentNamespace = "https://swift.org/\(component.name)-\(UUID().uuidString)"
        createdTimestamp = metadata.timestamp ?? ISO8601DateFormatter().string(from: Date())
    } else {
        // Fallback values when metadata is not available
        documentName = "Unknown"
        documentNamespace = "https://swift.org/unknown-\(UUID().uuidString)"
        createdTimestamp = ISO8601DateFormatter().string(from: Date())
    }
    
    return SPDXDocument(
        spdxVersion: "SPDX-2.3",
        dataLicense: "CC0-1.0",
        spdxId: "SPDXRef-DOCUMENT",
        name: documentName,
        documentNamespace: documentNamespace,
        creationInfo: SPDXCreationInfo(
            created: createdTimestamp,
            creators: ["Tool: swift-package-manager"]
        ),
        packages: (cycloneDX.components ?? []).map { component in
            // Convert CycloneDX licenses to SPDX license format
            let licenseInfo = extractLicenseInfo(from: component.licenses)
            
            return SPDXPackage(
                spdxId: "SPDXRef-\(component.name)",
                name: component.name,
                downloadLocation: "NOASSERTION",
                filesAnalyzed: false,
                versionInfo: component.version,
                licenseConcluded: licenseInfo.concluded,
                licenseDeclared: licenseInfo.declared
            )
        }
    )
}
