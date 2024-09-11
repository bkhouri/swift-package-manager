//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

//protocol ProgressAnimationProtocol3 {
//    func update(
//        state: borrowing ProgressState,
//        task: ProgressAnimation2Task,
//        event: ProgressAnimation2TaskEvent,
//        at time: ContinuousClock.Instant)
//
//    /// Complete the animation.
//    func complete(state: borrowing ProgressState)
//
//    /// Draw the animation.
//    func draw(state: borrowing ProgressState)
//
//    /// Clear the animation.
//    func clear(state: borrowing ProgressState)
//}