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

package enum SBOMLicenseEncoding: String, Codable, Equatable {
    case base64
}

package struct SBOMLicenseText: Codable, Equatable {
    package let content: String
    package let encoding: SBOMLicenseEncoding?
    package let contentType: String?
    
    package init(
        content: String,
        encoding: SBOMLicenseEncoding? = nil,
        contentType: String? = "text/plain"
    ) {
        self.content = content
        self.encoding = encoding
        self.contentType = contentType
    }
    
    private enum CodingKeys: String, CodingKey {
        case content
        case encoding
        case contentType
    }
}

package struct SBOMLicenseName: Codable, Equatable {
    package let name: String
    package let text: SBOMLicenseText?
    package let url: String?
    
    package init(
        name: String,
        text: SBOMLicenseText? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.text = text
        self.url = url
    }
}

package struct SBOMLicenseID: Codable, Equatable {
    package let id: String
    package let text: SBOMLicenseText?
    package let url: String?
    
    package init(
        id: String,
        text: SBOMLicenseText? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.text = text
        self.url = url
    }
}

package enum SBOMLicenseChoice: Codable, Equatable {
    case expression(String)
    case licenseName(SBOMLicenseName)
    case licenseID(SBOMLicenseID)
    
    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as a string first (expression)
        if let expression = try? container.decode(String.self) {
            self = .expression(expression)
            return
        }
        
        // Try to decode as different license object types
        if let licenseID = try? container.decode(SBOMLicenseID.self) {
            self = .licenseID(licenseID)
        } else if let licenseName = try? container.decode(SBOMLicenseName.self) {
            self = .licenseName(licenseName)
        } else {
            throw DecodingError.typeMismatch(SBOMLicenseChoice.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode SBOMLicenseChoice"))
        }
    }
    
    package func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
        case .expression(let expression):
            try container.encode(["expression": expression])
        case .licenseName(let licenseName):
            try container.encode(["license": licenseName])
        case .licenseID(let licenseID):
            try container.encode(["license": licenseID])
        }
    }
}