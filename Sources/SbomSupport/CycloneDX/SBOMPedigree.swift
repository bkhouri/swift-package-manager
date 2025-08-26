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

public enum SBOMPatchType: String, Codable, Equatable {
    case unofficial
    case monkey
    case backport
    case cherryPick = "cherry-pick"
}

public struct SBOMIdentifiableAction: Codable, Equatable {
    public let timestamp: String?
    public let name: String?
    public let email: String?
    
    public init(timestamp: String? = nil, name: String? = nil, email: String? = nil) {
        self.timestamp = timestamp
        self.name = name
        self.email = email
    }
}

public struct SBOMCommit: Codable, Equatable {
    public let uid: String?
    public let url: String?
    public let author: SBOMIdentifiableAction?
    public let committer: SBOMIdentifiableAction?
    public let message: String?
    
    public init(
        uid: String? = nil,
        url: String? = nil,
        author: SBOMIdentifiableAction? = nil,
        committer: SBOMIdentifiableAction? = nil,
        message: String? = nil
    ) {
        self.uid = uid
        self.url = url
        self.author = author
        self.committer = committer
        self.message = message
    }
}

public struct SBOMDiff: Codable, Equatable {
    public let text: SBOMAttachment?
    public let url: String?
    
    public init(text: SBOMAttachment? = nil, url: String? = nil) {
        self.text = text
        self.url = url
    }
}

public struct SBOMAttachment: Codable, Equatable {
    public let contentType: String?
    public let encoding: String?
    public let content: String
    
    public init(contentType: String? = nil, encoding: String? = nil, content: String) {
        self.contentType = contentType
        self.encoding = encoding
        self.content = content
    }
    
    private enum CodingKeys: String, CodingKey {
        case contentType
        case encoding
        case content
    }
}

public struct SBOMIssueSource: Codable, Equatable {
    public let name: String?
    public let url: String?
    
    public init(name: String? = nil, url: String? = nil) {
        self.name = name
        self.url = url
    }
}

public enum SBOMIssueType: String, Codable, Equatable {
    case defect
    case enhancement
    case security
}

public struct SBOMIssue: Codable, Equatable {
    public let type: SBOMIssueType
    public let id: String?
    public let name: String?
    public let description: String?
    public let source: SBOMIssueSource?
    public let references: [String]?
    
    public init(
        type: SBOMIssueType,
        id: String? = nil,
        name: String? = nil,
        description: String? = nil,
        source: SBOMIssueSource? = nil,
        references: [String]? = nil
    ) {
        self.type = type
        self.id = id
        self.name = name
        self.description = description
        self.source = source
        self.references = references
    }
}

public struct SBOMPatch: Codable, Equatable {
    public let type: SBOMPatchType
    public let diff: SBOMDiff?
    public let resolves: [SBOMIssue]?
    
    public init(type: SBOMPatchType, diff: SBOMDiff? = nil, resolves: [SBOMIssue]? = nil) {
        self.type = type
        self.diff = diff
        self.resolves = resolves
    }
}

public struct SBOMPedigree: Codable, Equatable {
    public let ancestors: [SBOMComponent]?
    public let descendants: [SBOMComponent]?
    public let variants: [SBOMComponent]?
    public let commits: [SBOMCommit]?
    public let patches: [SBOMPatch]?
    public let notes: String?
    
    public init(
        ancestors: [SBOMComponent]? = nil,
        descendants: [SBOMComponent]? = nil,
        variants: [SBOMComponent]? = nil,
        commits: [SBOMCommit]? = nil,
        patches: [SBOMPatch]? = nil,
        notes: String? = nil
    ) {
        self.ancestors = ancestors
        self.descendants = descendants
        self.variants = variants
        self.commits = commits
        self.patches = patches
        self.notes = notes
    }
}