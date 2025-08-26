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

public enum SBOMType: String, Codable, Equatable {
    case application
    case framework
    case library
    case container
    case operatingSystem = "operating-system"
    case device
    case firmware
    case file
}

public struct SBOMComponent: Codable, Equatable {
    public let type: SBOMType
    public let bomRef: String
    public let name: String
    public let version: String
    public let scope: String
    public let data: [SBOMData]?
    public let components: [SBOMComponent]?
    public let licenses: [SBOMLicenseChoice]?
    public let pedigree: SBOMPedigree?

    public init(
        type: SBOMType,
        bomRef: String,
        name: String,
        version: String,
        scope: String,
        data: [SBOMData]? = nil,
        components: [SBOMComponent]? = nil,
        licenses: [SBOMLicenseChoice]? = nil,
        pedigree: SBOMPedigree? = nil
    ) {
        self.type = type
        self.bomRef = bomRef
        self.name = name
        self.version = version
        self.scope = scope
        self.data = data
        self.components = components
        self.licenses = licenses
        self.pedigree = pedigree
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
        case pedigree
    }
}
