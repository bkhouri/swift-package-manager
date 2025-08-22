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

package struct SPDXDocument: Codable, Equatable {
    package let spdxVersion: String
    package let dataLicense: String
    package let spdxId: String
    package let name: String
    package let documentNamespace: String
    package let creationInfo: SPDXCreationInfo
    package let packages: [SPDXPackage]

    package init(
        spdxVersion: String,
        dataLicense: String,
        spdxId: String,
        name: String,
        documentNamespace: String,
        creationInfo: SPDXCreationInfo,
        packages: [SPDXPackage]
    ) {
        self.spdxVersion = spdxVersion
        self.dataLicense = dataLicense
        self.spdxId = spdxId
        self.name = name
        self.documentNamespace = documentNamespace
        self.creationInfo = creationInfo
        self.packages = packages
    }
}

package struct SPDXCreationInfo: Codable, Equatable {
    package let created: String
    package let creators: [String]

    package init(
        created: String,
        creators: [String]
    ) {
        self.created = created
        self.creators = creators
    }
}

package struct SPDXPackage: Codable, Equatable {
    package let spdxId: String
    package let name: String
    package let downloadLocation: String
    package let filesAnalyzed: Bool
    package let versionInfo: String
    package let licenseConcluded: String?
    package let licenseDeclared: String?

    package init(
        spdxId: String,
        name: String,
        downloadLocation: String,
        filesAnalyzed: Bool,
        versionInfo: String,
        licenseConcluded: String? = nil,
        licenseDeclared: String? = nil
    ) {
        self.spdxId = spdxId
        self.name = name
        self.downloadLocation = downloadLocation
        self.filesAnalyzed = filesAnalyzed
        self.versionInfo = versionInfo
        self.licenseConcluded = licenseConcluded
        self.licenseDeclared = licenseDeclared
    }
}
