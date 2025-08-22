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

package enum SBOMType: String, Codable, Equatable {
    case application
    case framework
    case library
    case container
    case operatingSystem = "operating-system"
    case device
    case firmware
    case file
}

package struct SBOMComponent: Codable, Equatable {
    package let type: SBOMType
    package let bomRef: String
    package let name: String
    package let version: String
    package let scope: String
    package let data: [SBOMData]?
    package let components: [SBOMComponent]?
    package let licenses: [SBOMLicenseChoice]?

    package init(
        type: SBOMType,
        bomRef: String,
        name: String,
        version: String,
        scope: String,
        data: [SBOMData]? = nil,
        components: [SBOMComponent]? = nil,
        licenses: [SBOMLicenseChoice]? = nil
    ) {
        self.type = type
        self.bomRef = bomRef
        self.name = name
        self.version = version
        self.scope = scope
        self.data = data
        self.components = components
        self.licenses = licenses
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case bomRef = "bom-ref"
        case name
        case version
        case scope
        case data
        case components
        case licenses
    }
}
