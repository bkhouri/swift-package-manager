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

public enum SBOMLicenseEncoding: String, Codable, Equatable {
    case base64
}

public struct SBOMLicenseText: Codable, Equatable {
    public let content: String
    public let encoding: SBOMLicenseEncoding?
    public let contentType: String?
    
    public init(
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

public struct SBOMLicenseName: Codable, Equatable {
    public let name: String
    public let text: SBOMLicenseText?
    public let url: String?
    
    public init(
        name: String,
        text: SBOMLicenseText? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.text = text
        self.url = url
    }
}

public struct SBOMLicenseID: Codable, Equatable {
    public let id: String
    public let text: SBOMLicenseText?
    public let url: String?
    
    public init(
        id: String,
        text: SBOMLicenseText? = nil,
        url: String? = nil
    ) {
        self.id = id
        self.text = text
        self.url = url
    }
}

public enum SBOMLicenseChoice: Codable, Equatable {
    case expression(String)
    case licenseName(SBOMLicenseName)
    case licenseID(SBOMLicenseID)
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try to decode as a string first (expression - for backward compatibility)
        if let expression = try? container.decode(String.self) {
            self = .expression(expression)
            return
        }
        
        // Try to decode as wrapped dictionary format (current encoding format)
        let keyedContainer = try decoder.container(keyedBy: CodingKeys.self)
        
        if let expression = try? keyedContainer.decode(String.self, forKey: .expression) {
            self = .expression(expression)
        } else if keyedContainer.contains(.license) {
            // Try to decode as SBOMLicenseID first, then SBOMLicenseName
            if let licenseID = try? keyedContainer.decode(SBOMLicenseID.self, forKey: .license) {
                self = .licenseID(licenseID)
            } else if let licenseName = try? keyedContainer.decode(SBOMLicenseName.self, forKey: .license) {
                self = .licenseName(licenseName)
            } else {
                throw DecodingError.typeMismatch(SBOMLicenseChoice.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode license object"))
            }
        } else {
            // Try to decode as different license object types directly (for backward compatibility)
            let singleContainer = try decoder.singleValueContainer()
            if let licenseID = try? singleContainer.decode(SBOMLicenseID.self) {
                self = .licenseID(licenseID)
            } else if let licenseName = try? singleContainer.decode(SBOMLicenseName.self) {
                self = .licenseName(licenseName)
            } else {
                throw DecodingError.typeMismatch(SBOMLicenseChoice.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode SBOMLicenseChoice"))
            }
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case expression
        case license
    }
    
    public func encode(to encoder: Encoder) throws {
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
