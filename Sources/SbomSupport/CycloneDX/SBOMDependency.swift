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


package struct SBOMDependency: Codable, Equatable {
    package let ref: String
    package let dependsOn: [String]

    package init(
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
