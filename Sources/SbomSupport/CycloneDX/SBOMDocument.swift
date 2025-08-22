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

package struct SBOMDocument: Codable, Equatable {
    package let bomFormat: String
    package let specVersion: String
    package let serialNumber: String?
    package let version: Int
    package let metadata: SBOMMetadata?
    package let components: [SBOMComponent]?
    package let dependencies: [SBOMDependency]?

    package init(
        bomFormat: String,
        specVersion: String,
        serialNumber: String? = nil,
        version: Int,
        metadata: SBOMMetadata? = nil,
        components: [SBOMComponent]? = nil,
        dependencies: [SBOMDependency]? = nil,
    ) {
        self.bomFormat = bomFormat
        self.specVersion = specVersion
        self.serialNumber = serialNumber
        self.version = version
        self.metadata = metadata
        self.components = components
        self.dependencies = dependencies
    }
    
    private enum CodingKeys: String, CodingKey {
        case bomFormat
        case specVersion
        case serialNumber
        case version
        case metadata
        case components
        case dependencies
    }
}
