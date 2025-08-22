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
package enum SBOMDataType: String, Codable, Equatable {
    case sourceCode = "source-code"
    case configuration
    case dataset
    case definition
    case other
}
package struct SBOMData : Codable, Equatable {
    package let type: SBOMDataType
    package let name: String
}
