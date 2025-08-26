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
struct PedigreeTests {
    
    @Test
    func generateSBOM_withUnknownVersionInGitRepo_includesPedigree() throws {
        // Create a temporary git repository for testing
        let tempDir = try withTemporaryDirectory { tempDir in
            // Initialize git repo
            let gitInitProcess = AsyncProcess(
                arguments: ["git", "init"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try gitInitProcess.launch()
            _ = try gitInitProcess.waitUntilExit()
            
            // Configure git user
            let configNameProcess = AsyncProcess(
                arguments: ["git", "config", "user.name", "SBOM Test"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try configNameProcess.launch()
            _ = try configNameProcess.waitUntilExit()
            
            let configEmailProcess = AsyncProcess(
                arguments: ["git", "config", "user.email", "sbom@test.com"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try configEmailProcess.launch()
            _ = try configEmailProcess.waitUntilExit()
            
            // Create source structure
            let sourcesDir = tempDir.appending("Sources").appending("TestApp")
            try localFileSystem.createDirectory(sourcesDir, recursive: true)
            try localFileSystem.writeFileContents(sourcesDir.appending("main.swift"), string: "print(\"Hello\")")
            
            // Add and commit
            let addProcess = AsyncProcess(
                arguments: ["git", "add", "."],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try addProcess.launch()
            _ = try addProcess.waitUntilExit()
            
            let commitProcess = AsyncProcess(
                arguments: ["git", "commit", "-m", "Initial app commit"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try commitProcess.launch()
            _ = try commitProcess.waitUntilExit()
            
            return tempDir
        }
        
        // Create a graph with unknown version using the git repo path
        let graph = try createMockModulesGraphWithGitRepo(
            rootPackageName: "TestApp",
            rootPackageVersion: nil, // This will result in "unknown"
            rootPackagePath: tempDir
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify the root component has pedigree information
        let components = try #require(sbom.components)
        let rootComponent = components.first { $0.name == "testapp" }!
        #expect(rootComponent.version == "unknown")
        
        let pedigree = try #require(rootComponent.pedigree)
        #expect(pedigree.notes == "HEAD commit information for package without version")
        
        let commits = try #require(pedigree.commits)
        #expect(commits.count == 1)
        
        let commit = commits.first!
        #expect(commit.uid != nil)
        #expect(commit.author?.name == "SBOM Test")
        #expect(commit.author?.email == "sbom@test.com")
        #expect(commit.message == "Initial app commit")
    }
    
    @Test
    func generateSBOM_withUnknownVersionInNonGitRepo_noPedigree() throws {
        // Create a temporary directory without git
        let tempDir = try withTemporaryDirectory { tempDir in
            // Create source structure but no git repo
            let sourcesDir = tempDir.appending("Sources").appending("TestApp")
            try localFileSystem.createDirectory(sourcesDir, recursive: true)
            try localFileSystem.writeFileContents(sourcesDir.appending("main.swift"), string: "print(\"Hello\")")
            
            return tempDir
        }
        
        // Test through SBOM generation - should not have pedigree for non-git repos
        let graph = try createMockModulesGraphWithGitRepo(
            rootPackageName: "TestApp",
            rootPackageVersion: nil, // This will result in "unknown"
            rootPackagePath: tempDir
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify the component does NOT have pedigree information for non-git repos
        let components = try #require(sbom.components)
        #expect(components.count >= 1, "Should have at least one component")
        
        // Find the root component (it should be the one with version "unknown")
        let rootComponent = components.first { $0.version == "unknown" }
        let actualComponent = try #require(rootComponent, "Should find a component with unknown version")
        #expect(actualComponent.pedigree == nil) // No pedigree for non-git repos
    }
    
    @Test
    func generateSBOM_withKnownVersions_noPedigree() throws {
        // Create a regular graph with known versions
        let graph = try createMockModulesGraph(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0"
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify the root component does NOT have pedigree information
        let components = try #require(sbom.components)
        let rootComponent = components.first { $0.name == "testapp" }!
        #expect(rootComponent.version == "1.0.0")
        #expect(rootComponent.pedigree == nil)
    }
    
    @Test
    func generateSBOM_withMixedVersions_selectivePedigree() throws {
        // Create a git repo for one dependency
        let gitDepDir = try withTemporaryDirectory { tempDir in
            // Initialize git repo
            let gitInitProcess = AsyncProcess(
                arguments: ["git", "init"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try gitInitProcess.launch()
            _ = try gitInitProcess.waitUntilExit()
            
            // Configure git user
            let configNameProcess = AsyncProcess(
                arguments: ["git", "config", "user.name", "Dep Author"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try configNameProcess.launch()
            _ = try configNameProcess.waitUntilExit()
            
            let configEmailProcess = AsyncProcess(
                arguments: ["git", "config", "user.email", "dep@example.com"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try configEmailProcess.launch()
            _ = try configEmailProcess.waitUntilExit()
            
            // Create source structure
            let sourcesDir = tempDir.appending("Sources").appending("GitDep")
            try localFileSystem.createDirectory(sourcesDir, recursive: true)
            try localFileSystem.writeFileContents(sourcesDir.appending("GitDep.swift"), string: "public struct GitDep {}")
            
            // Add and commit
            let addProcess = AsyncProcess(
                arguments: ["git", "add", "."],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try addProcess.launch()
            _ = try addProcess.waitUntilExit()
            
            let commitProcess = AsyncProcess(
                arguments: ["git", "commit", "-m", "Git dependency commit"],
                environment: .current,
                workingDirectory: tempDir,
                outputRedirection: .collect
            )
            try commitProcess.launch()
            _ = try commitProcess.waitUntilExit()
            
            return tempDir
        }
        
        // Create a graph with mixed versions - one with known version, one unknown in git repo
        let graph = try createMockModulesGraphWithMixedVersions(
            rootPackageName: "TestApp",
            rootPackageVersion: "1.0.0", // Known version
            gitDependency: (name: "GitDep", path: gitDepDir, version: nil) // Unknown version in git repo
        )
        
        let sbom = try generateSBOM(from: graph)
        
        // Verify selective pedigree application
        let components = try #require(sbom.components)
        
        // Root component has known version - no pedigree
        let rootComponent = components.first { $0.name == "testapp" }!
        #expect(rootComponent.version == "1.0.0")
        #expect(rootComponent.pedigree == nil)
        
        // Git dependency has unknown version - should have pedigree
        let gitDepComponent = components.first { $0.name == "gitdep" }!
        #expect(gitDepComponent.version == "unknown")
        let pedigree = try #require(gitDepComponent.pedigree)
        #expect(pedigree.notes == "HEAD commit information for package without version")
        
        let commits = try #require(pedigree.commits)
        #expect(commits.count == 1)
        let commit = commits.first!
        #expect(commit.author?.name == "Dep Author")
        #expect(commit.message == "Git dependency commit")
    }
    
    @Test
    func sbomPedigree_codableRoundTrip() throws {
        // Test that SBOMPedigree can be encoded and decoded properly
        let commit = SBOMCommit(
            uid: "abc123def456",
            url: "https://github.com/example/repo/commit/abc123def456",
            author: SBOMIdentifiableAction(
                timestamp: "2025-01-01T12:00:00Z",
                name: "John Doe",
                email: "john@example.com"
            ),
            committer: SBOMIdentifiableAction(
                timestamp: "2025-01-01T12:05:00Z",
                name: "Jane Smith",
                email: "jane@example.com"
            ),
            message: "Fix critical bug"
        )
        
        let pedigree = SBOMPedigree(
            ancestors: nil,
            descendants: nil,
            variants: nil,
            commits: [commit],
            patches: nil,
            notes: "Test pedigree information"
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(pedigree)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedPedigree = try decoder.decode(SBOMPedigree.self, from: jsonData)
        
        // Verify the decoded pedigree matches the original
        #expect(decodedPedigree.notes == pedigree.notes)
        #expect(decodedPedigree.commits?.count == 1)
        
        let decodedCommit = decodedPedigree.commits?.first
        #expect(decodedCommit?.uid == commit.uid)
        #expect(decodedCommit?.url == commit.url)
        #expect(decodedCommit?.message == commit.message)
        #expect(decodedCommit?.author?.name == commit.author?.name)
        #expect(decodedCommit?.author?.email == commit.author?.email)
        #expect(decodedCommit?.committer?.name == commit.committer?.name)
    }
}

// MARK: - Helper Functions

private func createMockModulesGraphWithGitRepo(
    rootPackageName: String,
    rootPackageVersion: String?,
    rootPackagePath: AbsolutePath
) throws -> ModulesGraph {
    // Create manifest for the root package at the git repo path
    let rootManifest = Manifest.createRootManifest(
        displayName: rootPackageName,
        path: rootPackagePath,
        version: rootPackageVersion.map { Version($0)! },
        toolsVersion: .v5_5,
        targets: [
            try TargetDescription(name: rootPackageName)
        ]
    )
    
    let observability = ObservabilitySystem.makeForTesting()
    return try loadModulesGraph(
        fileSystem: localFileSystem,
        manifests: [rootManifest],
        observabilityScope: observability.topScope
    )
}

private func createMockModulesGraphWithMixedVersions(
    rootPackageName: String,
    rootPackageVersion: String,
    gitDependency: (name: String, path: AbsolutePath, version: String?)
) throws -> ModulesGraph {
    // Create file system with proper source file structure
    var emptyFiles: [String] = []
    
    // Add source files for root package
    emptyFiles.append("/\(rootPackageName)/Sources/\(rootPackageName)/\(rootPackageName).swift")
    
    let fs = InMemoryFileSystem(emptyFiles: emptyFiles)
    
    // Create root package manifest
    let rootManifest = Manifest.createRootManifest(
        displayName: rootPackageName,
        path: "/\(rootPackageName)",
        version: Version(rootPackageVersion)!,
        toolsVersion: .v5_5,
        dependencies: [.fileSystem(path: gitDependency.path)],
        targets: [
            try TargetDescription(name: rootPackageName, dependencies: [.product(name: gitDependency.name, package: gitDependency.name)])
        ]
    )
    
    // Create git dependency manifest using the actual git repo path
    let gitDepManifest = Manifest.createFileSystemManifest(
        displayName: gitDependency.name,
        path: gitDependency.path,
        version: gitDependency.version.map { Version($0)! },
        toolsVersion: .v5_5,
        products: [
            try ProductDescription(name: gitDependency.name, type: .library(.automatic), targets: [gitDependency.name])
        ],
        targets: [
            try TargetDescription(name: gitDependency.name)
        ]
    )
    
    let observability = ObservabilitySystem.makeForTesting()
    return try loadModulesGraph(
        fileSystem: fs,
        manifests: [rootManifest, gitDepManifest],
        observabilityScope: observability.topScope
    )
}