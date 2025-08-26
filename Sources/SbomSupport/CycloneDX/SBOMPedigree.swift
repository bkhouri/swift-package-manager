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

package enum SBOMPatchType: String, Codable, Equatable {
    case unofficial
    case monkey
    case backport
    case cherryPick = "cherry-pick"
}

package struct SBOMIdentifiableAction: Codable, Equatable {
    package let timestamp: String?
    package let name: String?
    package let email: String?
    
    package init(timestamp: String? = nil, name: String? = nil, email: String? = nil) {
        self.timestamp = timestamp
        self.name = name
        self.email = email
    }
}

package struct SBOMCommit: Codable, Equatable {
    package let uid: String?
    package let url: String?
    package let author: SBOMIdentifiableAction?
    package let committer: SBOMIdentifiableAction?
    package let message: String?
    
    package init(
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

package struct SBOMDiff: Codable, Equatable {
    package let text: SBOMAttachment?
    package let url: String?
    
    package init(text: SBOMAttachment? = nil, url: String? = nil) {
        self.text = text
        self.url = url
    }
}

package struct SBOMAttachment: Codable, Equatable {
    package let contentType: String?
    package let encoding: String?
    package let content: String
    
    package init(contentType: String? = nil, encoding: String? = nil, content: String) {
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

package struct SBOMIssueSource: Codable, Equatable {
    package let name: String?
    package let url: String?
    
    package init(name: String? = nil, url: String? = nil) {
        self.name = name
        self.url = url
    }
}

package enum SBOMIssueType: String, Codable, Equatable {
    case defect
    case enhancement
    case security
}

package struct SBOMIssue: Codable, Equatable {
    package let type: SBOMIssueType
    package let id: String?
    package let name: String?
    package let description: String?
    package let source: SBOMIssueSource?
    package let references: [String]?
    
    package init(
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

package struct SBOMPatch: Codable, Equatable {
    package let type: SBOMPatchType
    package let diff: SBOMDiff?
    package let resolves: [SBOMIssue]?
    
    package init(type: SBOMPatchType, diff: SBOMDiff? = nil, resolves: [SBOMIssue]? = nil) {
        self.type = type
        self.diff = diff
        self.resolves = resolves
    }
}

package struct SBOMPedigree: Codable, Equatable {
    package let ancestors: [SBOMComponent]?
    package let descendants: [SBOMComponent]?
    package let variants: [SBOMComponent]?
    package let commits: [SBOMCommit]?
    package let patches: [SBOMPatch]?
    package let notes: String?
    
    package init(
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