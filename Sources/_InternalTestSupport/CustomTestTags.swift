/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/
import Testing

extension Tag {
    enum TestSize { }
}

extension Tag.TestSize {
    @Tag static var small: Tag
    @Tag static var medium: Tag
    @Tag static var large: Tag
}