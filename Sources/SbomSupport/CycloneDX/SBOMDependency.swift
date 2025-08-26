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


public struct SBOMDependency: Codable, Equatable {
    public let ref: String
    public let dependsOn: [String]

    public init(
        ref: String,
        dependsOn: [String]
    ) {
        self.ref = ref
        self.dependsOn = dependsOn
    }
    
    private enum CodingKeys: String, CodingKey {
        case ref
        case dependsOn
    }
}
