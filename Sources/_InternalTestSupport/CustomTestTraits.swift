/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import PackageModel
import Testing

extension Trait where Self == Testing.ConditionTrait {
    public static var requiresConcurrencySupport: Self {
        // .disabled("dfeskipping because test environment doesn't support concurrency")
        disabled(if: try !UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        // .disabled(if: true, "skipping because test environment doesn't support concurrency")
    }
}