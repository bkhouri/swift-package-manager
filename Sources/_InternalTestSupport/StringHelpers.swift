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

/// Returns a string containing all standard punctuation and basic math symbols.
/// Cross-platform (Linux, macOS, Windows) since it uses Foundation's CharacterSet + Unicode scalars.
fileprivate func allPunctuationAndMathSymbols() -> String {
    var symbols = Set<Character>()
    
    let sets: [CharacterSet] = [.punctuationCharacters, .symbols]
    
    for set in sets {
        for plane in 0...16 {
            if let bitmap = set.bitmapRepresentation as NSData? {
                // Iterate over UInt8 bytes for efficiency
                let bytes = bitmap as Data
                for (i, byte) in bytes.enumerated() where byte != 0 {
                    for bit in 0..<8 where byte & (1 << bit) != 0 {
                        let scalarValue = (i << 3) | bit
                        if let scalar = UnicodeScalar(scalarValue) {
                            symbols.insert(Character(scalar))
                        }
                    }
                }
            }
        }
    }
    
    let mathExtras: [Character] = [
        "+", "-", "=", "<", ">", "±", "×", "÷", "√", "∞", "∑", "∏", "∫", "≈", "≠", "≤", "≥"
    ]
    symbols.formUnion(mathExtras)
    
    return String(symbols.sorted { $0.unicodeScalars.first!.value < $1.unicodeScalars.first!.value })
}

public let ALL_PUNCTUATIONS = allPunctuationAndMathSymbols()
