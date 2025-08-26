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

@testable import SbomSupport
import Foundation
import Testing

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct SBOMLicenseChoiceTests {
    
    // MARK: - Initialization Tests
    
    @Test
    func init_expressionCase() throws {
        let licenseChoice = SBOMLicenseChoice.expression("MIT")
        
        if case .expression(let expression) = licenseChoice {
            #expect(expression == "MIT")
        } else {
            Issue.record("Expected expression case")
        }
    }
    
    @Test
    func init_licenseIDCase() throws {
        let license = SBOMLicenseID(
            id: "Apache-2.0",
            text: SBOMLicenseText(content: "Apache license content"),
            url: "https://apache.org/licenses/LICENSE-2.0"
        )
        let licenseChoice = SBOMLicenseChoice.licenseID(license)
        
        if case .licenseID(let licenseObj) = licenseChoice {
            #expect(licenseObj.id == "Apache-2.0")
            #expect(licenseObj.url == "https://apache.org/licenses/LICENSE-2.0")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func init_licenseNameCase() throws {
        let license = SBOMLicenseName(
            name: "Apache License 2.0",
            text: SBOMLicenseText(content: "Apache license content"),
            url: "https://apache.org/licenses/LICENSE-2.0"
        )
        let licenseChoice = SBOMLicenseChoice.licenseName(license)
        
        if case .licenseName(let licenseObj) = licenseChoice {
            #expect(licenseObj.name == "Apache License 2.0")
            #expect(licenseObj.url == "https://apache.org/licenses/LICENSE-2.0")
        } else {
            Issue.record("Expected licenseName case")
        }
    }
    
    // MARK: - Decoding Tests
    
    @Test
    func decode_fromStringExpression() throws {
        let jsonData = "\"MIT\"".data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let licenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        if case .expression(let expression) = licenseChoice {
            #expect(expression == "MIT")
        } else {
            Issue.record("Expected expression case")
        }
    }
    
    @Test
    func decode_fromLicenseIDObject() throws {
        let jsonString = """
        {
            "id": "Apache-2.0",
            "text": {
                "content": "Apache license content",
                "contentType": "text/plain"
            },
            "url": "https://apache.org/licenses/LICENSE-2.0"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let licenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        if case .licenseID(let license) = licenseChoice {
            #expect(license.id == "Apache-2.0")
            #expect(license.url == "https://apache.org/licenses/LICENSE-2.0")
            #expect(license.text?.content == "Apache license content")
            #expect(license.text?.contentType == "text/plain")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func decode_fromLicenseNameObject() throws {
        let jsonString = """
        {
            "name": "MIT License",
            "url": "https://opensource.org/licenses/MIT"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let licenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        if case .licenseName(let license) = licenseChoice {
            #expect(license.name == "MIT License")
            #expect(license.url == "https://opensource.org/licenses/MIT")
            #expect(license.text == nil)
        } else {
            Issue.record("Expected licenseName case")
        }
    }
    
    @Test
    func decode_fromLicenseIDObjectMinimal() throws {
        let jsonString = """
        {
            "id": "MIT"
        }
        """
        let jsonData = jsonString.data(using: .utf8)!
        let decoder = JSONDecoder()
        
        let licenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        if case .licenseID(let license) = licenseChoice {
            #expect(license.id == "MIT")
            #expect(license.url == nil)
            #expect(license.text == nil)
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    // MARK: - Encoding Tests
    
    @Test
    func encode_expressionCase() throws {
        let licenseChoice = SBOMLicenseChoice.expression("MIT")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let jsonData = try encoder.encode(licenseChoice)
        
        // Parse the JSON to verify structure - expressions are wrapped in an "expression" key
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        #expect(jsonObject["expression"] as? String == "MIT")
    }
    
    @Test
    func encode_licenseIDCase() throws {
        let license = SBOMLicenseID(
            id: "Apache-2.0",
            text: SBOMLicenseText(content: "Apache license content"),
            url: "https://apache.org/licenses/LICENSE-2.0"
        )
        let licenseChoice = SBOMLicenseChoice.licenseID(license)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let jsonData = try encoder.encode(licenseChoice)
        
        // Parse the JSON to verify structure - license objects are wrapped in a "license" key
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let licenseObject = jsonObject["license"] as! [String: Any]
        #expect(licenseObject["id"] as? String == "Apache-2.0")
        #expect(licenseObject["url"] as? String == "https://apache.org/licenses/LICENSE-2.0")
        
        let textObject = licenseObject["text"] as! [String: Any]
        #expect(textObject["content"] as? String == "Apache license content")
        #expect(textObject["contentType"] as? String == "text/plain")
    }
    
    @Test
    func encode_licenseNameCase() throws {
        let license = SBOMLicenseName(
            name: "MIT License",
            url: "https://opensource.org/licenses/MIT"
        )
        let licenseChoice = SBOMLicenseChoice.licenseName(license)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let jsonData = try encoder.encode(licenseChoice)
        
        // Parse the JSON to verify structure - license objects are wrapped in a "license" key
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let licenseObject = jsonObject["license"] as! [String: Any]
        #expect(licenseObject["name"] as? String == "MIT License")
        #expect(licenseObject["url"] as? String == "https://opensource.org/licenses/MIT")
        #expect(licenseObject["text"] == nil)
    }
    
    @Test
    func encode_licenseIDCaseMinimal() throws {
        let license = SBOMLicenseID(id: "MIT")
        let licenseChoice = SBOMLicenseChoice.licenseID(license)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let jsonData = try encoder.encode(licenseChoice)
        
        // Parse the JSON to verify structure - license objects are wrapped in a "license" key
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as! [String: Any]
        let licenseObject = jsonObject["license"] as! [String: Any]
        #expect(licenseObject["id"] as? String == "MIT")
        #expect(licenseObject["url"] == nil)
        #expect(licenseObject["text"] == nil)
    }
    
    // MARK: - Round-trip Tests (Encode then Decode)
    
    @Test
    func roundTrip_expressionCase() throws {
        let originalLicenseChoice = SBOMLicenseChoice.expression("GPL-3.0")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let jsonData = try encoder.encode(originalLicenseChoice)
        let decodedLicenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        #expect(originalLicenseChoice == decodedLicenseChoice)
        
        if case .expression(let expression) = decodedLicenseChoice {
            #expect(expression == "GPL-3.0")
        } else {
            Issue.record("Expected expression case after round-trip")
        }
    }
    
    @Test
    func roundTrip_licenseIDCase() throws {
        let originalLicense = SBOMLicenseID(
            id: "BSD-3-Clause",
            text: SBOMLicenseText(
                content: "BSD license content",
                encoding: .base64,
                contentType: "text/plain"
            ),
            url: "https://opensource.org/licenses/BSD-3-Clause"
        )
        let originalLicenseChoice = SBOMLicenseChoice.licenseID(originalLicense)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let jsonData = try encoder.encode(originalLicenseChoice)
        let decodedLicenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        #expect(originalLicenseChoice == decodedLicenseChoice)
        
        if case .licenseID(let license) = decodedLicenseChoice {
            #expect(license.id == "BSD-3-Clause")
            #expect(license.url == "https://opensource.org/licenses/BSD-3-Clause")
            #expect(license.text?.content == "BSD license content")
            #expect(license.text?.encoding == .base64)
            #expect(license.text?.contentType == "text/plain")
        } else {
            Issue.record("Expected licenseID case after round-trip")
        }
    }
    
    @Test
    func roundTrip_licenseNameCase() throws {
        let originalLicense = SBOMLicenseName(
            name: "ISC License",
            url: "https://opensource.org/licenses/ISC"
        )
        let originalLicenseChoice = SBOMLicenseChoice.licenseName(originalLicense)
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        let jsonData = try encoder.encode(originalLicenseChoice)
        let decodedLicenseChoice = try decoder.decode(SBOMLicenseChoice.self, from: jsonData)
        
        #expect(originalLicenseChoice == decodedLicenseChoice)
        
        if case .licenseName(let license) = decodedLicenseChoice {
            #expect(license.name == "ISC License")
            #expect(license.url == "https://opensource.org/licenses/ISC")
            #expect(license.text == nil)
        } else {
            Issue.record("Expected licenseName case after round-trip")
        }
    }
    
    // MARK: - Error Handling Tests
    
    @Test
    func decode_invalidJSON() throws {
        let invalidJsonData = "invalid json".data(using: .utf8)!
        let decoder = JSONDecoder()
        
        #expect(throws: DecodingError.self) {
            try decoder.decode(SBOMLicenseChoice.self, from: invalidJsonData)
        }
    }
    
    @Test
    func decode_emptyObject() throws {
        let emptyObjectData = "{}".data(using: .utf8)!
        let decoder = JSONDecoder()
        
        // This should fail because both SBOMLicenseID and SBOMLicenseName require their respective required fields
        #expect(throws: Error.self) {
            try decoder.decode(SBOMLicenseChoice.self, from: emptyObjectData)
        }
    }
    
    // MARK: - Equality Tests
    
    @Test
    func equality_expressionCases() throws {
        let choice1 = SBOMLicenseChoice.expression("MIT")
        let choice2 = SBOMLicenseChoice.expression("MIT")
        let choice3 = SBOMLicenseChoice.expression("Apache-2.0")
        
        #expect(choice1 == choice2)
        #expect(choice1 != choice3)
    }
    
    @Test
    func equality_licenseIDCases() throws {
        let license1 = SBOMLicenseID(id: "MIT", url: "https://opensource.org/licenses/MIT")
        let license2 = SBOMLicenseID(id: "MIT", url: "https://opensource.org/licenses/MIT")
        let license3 = SBOMLicenseID(id: "Apache-2.0", url: "https://apache.org/licenses/LICENSE-2.0")
        
        let choice1 = SBOMLicenseChoice.licenseID(license1)
        let choice2 = SBOMLicenseChoice.licenseID(license2)
        let choice3 = SBOMLicenseChoice.licenseID(license3)
        
        #expect(choice1 == choice2)
        #expect(choice1 != choice3)
    }
    
    @Test
    func equality_licenseNameCases() throws {
        let license1 = SBOMLicenseName(name: "MIT License", url: "https://opensource.org/licenses/MIT")
        let license2 = SBOMLicenseName(name: "MIT License", url: "https://opensource.org/licenses/MIT")
        let license3 = SBOMLicenseName(name: "Apache License 2.0", url: "https://apache.org/licenses/LICENSE-2.0")
        
        let choice1 = SBOMLicenseChoice.licenseName(license1)
        let choice2 = SBOMLicenseChoice.licenseName(license2)
        let choice3 = SBOMLicenseChoice.licenseName(license3)
        
        #expect(choice1 == choice2)
        #expect(choice1 != choice3)
    }
    
    @Test
    func equality_mixedCases() throws {
        let expressionChoice = SBOMLicenseChoice.expression("MIT")
        let licenseID = SBOMLicenseID(id: "MIT")
        let licenseName = SBOMLicenseName(name: "MIT License")
        let licenseIDChoice = SBOMLicenseChoice.licenseID(licenseID)
        let licenseNameChoice = SBOMLicenseChoice.licenseName(licenseName)
        
        #expect(expressionChoice != licenseIDChoice)
        #expect(expressionChoice != licenseNameChoice)
        #expect(licenseIDChoice != licenseNameChoice)
    }
}