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
import Foundation
import Testing

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct PedigreeDataStructuresTests {
    
    @Test
    func sbomIdentifiableAction_initialization() throws {
        let action = SBOMIdentifiableAction(
            timestamp: "2025-01-01T12:00:00Z",
            name: "John Doe",
            email: "john@example.com"
        )
        
        #expect(action.timestamp == "2025-01-01T12:00:00Z")
        #expect(action.name == "John Doe")
        #expect(action.email == "john@example.com")
    }
    
    @Test
    func sbomIdentifiableAction_codableRoundTrip() throws {
        let action = SBOMIdentifiableAction(
            timestamp: "2025-01-01T12:00:00Z",
            name: "Jane Smith",
            email: "jane@example.com"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(action)
        
        let decoder = JSONDecoder()
        let decodedAction = try decoder.decode(SBOMIdentifiableAction.self, from: jsonData)
        
        #expect(decodedAction.timestamp == action.timestamp)
        #expect(decodedAction.name == action.name)
        #expect(decodedAction.email == action.email)
    }
    
    @Test
    func sbomCommit_initialization() throws {
        let author = SBOMIdentifiableAction(
            timestamp: "2025-01-01T12:00:00Z",
            name: "Author Name",
            email: "author@example.com"
        )
        
        let committer = SBOMIdentifiableAction(
            timestamp: "2025-01-01T12:05:00Z",
            name: "Committer Name",
            email: "committer@example.com"
        )
        
        let commit = SBOMCommit(
            uid: "abc123def456789",
            url: "https://github.com/example/repo/commit/abc123def456789",
            author: author,
            committer: committer,
            message: "Fix critical security issue"
        )
        
        #expect(commit.uid == "abc123def456789")
        #expect(commit.url == "https://github.com/example/repo/commit/abc123def456789")
        #expect(commit.message == "Fix critical security issue")
        #expect(commit.author?.name == "Author Name")
        #expect(commit.committer?.name == "Committer Name")
    }
    
    @Test
    func sbomCommit_codableRoundTrip() throws {
        let commit = SBOMCommit(
            uid: "def456abc123",
            url: "https://gitlab.com/example/project/commit/def456abc123",
            author: SBOMIdentifiableAction(
                timestamp: "2025-02-01T10:30:00Z",
                name: "Developer",
                email: "dev@example.com"
            ),
            committer: nil,
            message: "Add new feature"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(commit)
        
        let decoder = JSONDecoder()
        let decodedCommit = try decoder.decode(SBOMCommit.self, from: jsonData)
        
        #expect(decodedCommit.uid == commit.uid)
        #expect(decodedCommit.url == commit.url)
        #expect(decodedCommit.message == commit.message)
        #expect(decodedCommit.author?.name == commit.author?.name)
        #expect(decodedCommit.committer == nil)
    }
    
    @Test
    func sbomAttachment_initialization() throws {
        let attachment = SBOMAttachment(
            contentType: "text/plain",
            encoding: "base64",
            content: "SGVsbG8gV29ybGQ="
        )
        
        #expect(attachment.contentType == "text/plain")
        #expect(attachment.encoding == "base64")
        #expect(attachment.content == "SGVsbG8gV29ybGQ=")
    }
    
    @Test
    func sbomAttachment_codableRoundTrip() throws {
        let attachment = SBOMAttachment(
            contentType: "application/json",
            encoding: nil,
            content: "{\"key\": \"value\"}"
        )
        
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(attachment)
        
        let decoder = JSONDecoder()
        let decodedAttachment = try decoder.decode(SBOMAttachment.self, from: jsonData)
        
        #expect(decodedAttachment.contentType == attachment.contentType)
        #expect(decodedAttachment.encoding == attachment.encoding)
        #expect(decodedAttachment.content == attachment.content)
    }
    
    @Test
    func sbomPatchType_allCases() throws {
        let allTypes: [SBOMPatchType] = [.unofficial, .monkey, .backport, .cherryPick]
        
        #expect(allTypes.count == 4)
        #expect(SBOMPatchType.cherryPick.rawValue == "cherry-pick")
        #expect(SBOMPatchType.unofficial.rawValue == "unofficial")
        #expect(SBOMPatchType.monkey.rawValue == "monkey")
        #expect(SBOMPatchType.backport.rawValue == "backport")
    }
    
    @Test
    func sbomPatchType_codableRoundTrip() throws {
        let patchTypes: [SBOMPatchType] = [.unofficial, .monkey, .backport, .cherryPick]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for patchType in patchTypes {
            let jsonData = try encoder.encode(patchType)
            let decodedType = try decoder.decode(SBOMPatchType.self, from: jsonData)
            #expect(decodedType == patchType)
        }
    }
    
    @Test
    func sbomIssueType_allCases() throws {
        let allTypes: [SBOMIssueType] = [.defect, .enhancement, .security]
        
        #expect(allTypes.count == 3)
        #expect(SBOMIssueType.defect.rawValue == "defect")
        #expect(SBOMIssueType.enhancement.rawValue == "enhancement")
        #expect(SBOMIssueType.security.rawValue == "security")
    }
    
    @Test
    func sbomIssue_initialization() throws {
        let source = SBOMIssueSource(
            name: "GitHub Issues",
            url: "https://github.com/example/repo/issues"
        )
        
        let issue = SBOMIssue(
            type: .security,
            id: "CVE-2025-1234",
            name: "Security Vulnerability",
            description: "Critical security issue found",
            source: source,
            references: ["https://nvd.nist.gov/vuln/detail/CVE-2025-1234"]
        )
        
        #expect(issue.type == .security)
        #expect(issue.id == "CVE-2025-1234")
        #expect(issue.name == "Security Vulnerability")
        #expect(issue.description == "Critical security issue found")
        #expect(issue.source?.name == "GitHub Issues")
        #expect(issue.references?.count == 1)
    }
    
    @Test
    func sbomPatch_initialization() throws {
        let diff = SBOMDiff(
            text: SBOMAttachment(content: "--- a/file.txt\n+++ b/file.txt\n@@ -1 +1 @@\n-old\n+new"),
            url: "https://github.com/example/repo/commit/abc123.patch"
        )
        
        let issue = SBOMIssue(
            type: .defect,
            id: "BUG-456",
            name: "Fix null pointer",
            description: nil,
            source: nil,
            references: nil
        )
        
        let patch = SBOMPatch(
            type: .unofficial,
            diff: diff,
            resolves: [issue]
        )
        
        #expect(patch.type == .unofficial)
        #expect(patch.diff?.url == "https://github.com/example/repo/commit/abc123.patch")
        #expect(patch.resolves?.count == 1)
        #expect(patch.resolves?.first?.id == "BUG-456")
    }
    
    @Test
    func sbomPedigree_fullInitialization() throws {
        let ancestorComponent = SBOMComponent(
            type: .library,
            bomRef: "ancestor-lib",
            name: "AncestorLib",
            version: "1.0.0",
            scope: "required"
        )
        
        let commit = SBOMCommit(
            uid: "commit123",
            url: nil,
            author: SBOMIdentifiableAction(
                timestamp: "2025-01-01T00:00:00Z",
                name: "Developer",
                email: "dev@example.com"
            ),
            committer: nil,
            message: "Initial fork"
        )
        
        let patch = SBOMPatch(
            type: .backport,
            diff: nil,
            resolves: nil
        )
        
        let pedigree = SBOMPedigree(
            ancestors: [ancestorComponent],
            descendants: nil,
            variants: nil,
            commits: [commit],
            patches: [patch],
            notes: "Forked from original library with security patches"
        )
        
        #expect(pedigree.ancestors?.count == 1)
        #expect(pedigree.ancestors?.first?.name == "AncestorLib")
        #expect(pedigree.descendants == nil)
        #expect(pedigree.variants == nil)
        #expect(pedigree.commits?.count == 1)
        #expect(pedigree.patches?.count == 1)
        #expect(pedigree.notes == "Forked from original library with security patches")
    }
    
    @Test
    func sbomPedigree_codableRoundTrip() throws {
        let pedigree = SBOMPedigree(
            ancestors: nil,
            descendants: nil,
            variants: nil,
            commits: [
                SBOMCommit(
                    uid: "abc123",
                    url: "https://example.com/commit/abc123",
                    author: SBOMIdentifiableAction(
                        timestamp: "2025-01-01T12:00:00Z",
                        name: "Test Author",
                        email: "test@example.com"
                    ),
                    committer: nil,
                    message: "Test commit"
                )
            ],
            patches: nil,
            notes: "Test pedigree"
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(pedigree)
        
        let decoder = JSONDecoder()
        let decodedPedigree = try decoder.decode(SBOMPedigree.self, from: jsonData)
        
        #expect(decodedPedigree.notes == pedigree.notes)
        #expect(decodedPedigree.commits?.count == 1)
        #expect(decodedPedigree.commits?.first?.uid == "abc123")
        #expect(decodedPedigree.commits?.first?.author?.name == "Test Author")
    }
    
    @Test
    func sbomComponent_withPedigree_codableRoundTrip() throws {
        let pedigree = SBOMPedigree(
            ancestors: nil,
            descendants: nil,
            variants: nil,
            commits: [
                SBOMCommit(
                    uid: "def456",
                    url: nil,
                    author: SBOMIdentifiableAction(
                        timestamp: "2025-01-01T15:30:00Z",
                        name: "Component Author",
                        email: "author@component.com"
                    ),
                    committer: nil,
                    message: "Component commit"
                )
            ],
            patches: nil,
            notes: "Component pedigree information"
        )
        
        let component = SBOMComponent(
            type: .library,
            bomRef: "test-component",
            name: "TestComponent",
            version: "unknown",
            scope: "required",
            data: nil,
            components: nil,
            licenses: nil,
            pedigree: pedigree
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(component)
        
        let decoder = JSONDecoder()
        let decodedComponent = try decoder.decode(SBOMComponent.self, from: jsonData)
        
        #expect(decodedComponent.name == component.name)
        #expect(decodedComponent.version == component.version)
        #expect(decodedComponent.pedigree?.notes == pedigree.notes)
        #expect(decodedComponent.pedigree?.commits?.count == 1)
        #expect(decodedComponent.pedigree?.commits?.first?.uid == "def456")
    }
}