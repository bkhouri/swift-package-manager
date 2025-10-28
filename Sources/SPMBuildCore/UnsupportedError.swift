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
import Foundation

public enum Unsupported: Error, CustomStringConvertible {
    case debugInfoFormat(BuildParameters.DebugInfoFormat)

    public var description: String {
        switch self {
        case .debugInfoFormat(let format):
            return "Unsupported debug info format: \(format)"
        }
    }
}
