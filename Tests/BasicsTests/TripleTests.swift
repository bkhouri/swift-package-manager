//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

import Basics
import Testing



struct TripleTests {
    struct DataIsAppleIsDarwin {
        var tripleName: String
        var isApple: Bool
        var isDarwin: Bool
    }
    @Test(
        "Triple is Apple and i Darwin",
        arguments: [
            DataIsAppleIsDarwin(tripleName:"x86_64-pc-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"x86_64-pc-linux-musl", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"powerpc-bgp-linux", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"arm-none-none-eabi", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"arm-none-linux-musleabi", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"wasm32-unknown-wasi", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"riscv64-unknown-linux", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips-mti-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mipsel-img-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips64-mti-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips64el-img-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips64el-img-linux-gnuabin32", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips64-unknown-linux-gnuabi64", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips64-unknown-linux-gnuabin32", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mipsel-unknown-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"mips-unknown-linux-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"arm-oe-linux-gnueabi", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"aarch64-oe-linux", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"armv7em-unknown-none-macho", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"armv7em-apple-none-macho", isApple: true, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"armv7em-apple-none", isApple: true, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"aarch64-apple-macosx", isApple: true, isDarwin: true),
            DataIsAppleIsDarwin(tripleName:"x86_64-apple-macosx", isApple: true, isDarwin: true),
            DataIsAppleIsDarwin(tripleName:"x86_64-apple-macosx10.15", isApple: true, isDarwin: true),
            DataIsAppleIsDarwin(tripleName:"x86_64h-apple-darwin", isApple: true, isDarwin: true),
            DataIsAppleIsDarwin(tripleName:"i686-pc-windows-msvc", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"i686-pc-windows-gnu", isApple: false, isDarwin: false),
            DataIsAppleIsDarwin(tripleName:"i686-pc-windows-cygnus", isApple: false, isDarwin: false)
        ]
    )
    func isAppleIsDarwin(_ data: DataIsAppleIsDarwin) {
        guard let triple = try? Triple(data.tripleName) else {
            Issue.record("Unknown triple '\(data.tripleName)'.")
            return
        }
        #expect(
            data.isApple == triple.isApple(),
            """
            Expected triple '\(triple.tripleString)' \
            \(data.isApple ? "" : " not") to be an Apple triple.
            """
        )
        #expect(
            data.isDarwin == triple.isDarwin(),
            """
            Expected triple '\(triple.tripleString)' \
            \(data.isDarwin ? "" : " not") to be a Darwin triple.
            """
        )
    }

    @Test
    func description() throws {
        let triple = try Triple("x86_64-pc-linux-gnu")
        #expect("foo \(triple) bar" == "foo x86_64-pc-linux-gnu bar")
    }

    struct DataPlatformVersion {
        var tripleName: String
        var version: String // forPlatformVersion
        var expectedTriple: String
    }
    @Test(
        "Triple String for Platform Version",
        arguments: [
            DataPlatformVersion(tripleName: "x86_64-apple-macosx", version: "", expectedTriple: "x86_64-apple-macosx"),
            DataPlatformVersion(tripleName: "x86_64-apple-macosx", version: "13.0", expectedTriple: "x86_64-apple-macosx13.0"),
            DataPlatformVersion(tripleName: "armv7em-apple-macosx10.12", version: "", expectedTriple: "armv7em-apple-macosx"),
            DataPlatformVersion(tripleName: "armv7em-apple-macosx10.12", version: "13.0", expectedTriple: "armv7em-apple-macosx13.0"),
            DataPlatformVersion(tripleName: "powerpc-apple-macos", version: "", expectedTriple: "powerpc-apple-macos"),
            DataPlatformVersion(tripleName: "powerpc-apple-macos", version: "13.0", expectedTriple: "powerpc-apple-macos13.0"),
            DataPlatformVersion(tripleName: "i686-apple-macos10.12.0", version: "", expectedTriple: "i686-apple-macos"),
            DataPlatformVersion(tripleName: "i686-apple-macos10.12.0", version: "13.0", expectedTriple: "i686-apple-macos13.0"),
            DataPlatformVersion(tripleName: "riscv64-apple-darwin", version: "", expectedTriple: "riscv64-apple-darwin"),
            DataPlatformVersion(tripleName: "riscv64-apple-darwin", version: "22", expectedTriple: "riscv64-apple-darwin22"),
            DataPlatformVersion(tripleName: "mips-apple-darwin19", version: "", expectedTriple: "mips-apple-darwin"),
            DataPlatformVersion(tripleName: "mips-apple-darwin19", version: "22", expectedTriple: "mips-apple-darwin22"),
            DataPlatformVersion(tripleName: "arm64-apple-ios-simulator", version: "", expectedTriple: "arm64-apple-ios-simulator"),
            DataPlatformVersion(tripleName: "arm64-apple-ios-simulator", version: "13.0", expectedTriple: "arm64-apple-ios13.0-simulator"),
            DataPlatformVersion(tripleName: "arm64-apple-ios12-simulator", version: "", expectedTriple: "arm64-apple-ios-simulator"),
            DataPlatformVersion(tripleName: "arm64-apple-ios12-simulator", version: "13.0", expectedTriple: "arm64-apple-ios13.0-simulator")
        ]
    )
    func tripleStringForPlatformVersion(_ data: DataPlatformVersion) throws {
           guard let triple = try? Triple(data.tripleName) else {
                Issue.record("Unknown triple '\(data.tripleName)'.")
               return
           }
           let actualTriple = triple.tripleString(forPlatformVersion: data.version)
            #expect(
               actualTriple == data.expectedTriple,
               """
               Actual triple '\(actualTriple)' did not match expected triple \
               '\(data.expectedTriple)' for platform version '\(data.version)'.
               """
            )
   }

    struct DataKnownTripleParsing {
        var tripleName: String
        var expectedArch: Triple.Arch?
        var expectedSubArch: Triple.SubArch?
        var expectedVendor: Triple.Vendor?
        var expectedOs: Triple.OS?
        var expectedEnvironment: Triple.Environment?
        var expectedObjectFormat: Triple.ObjectFormat?
    }
    @Test(
        "Known Triple Parsing",
        arguments: [
            DataKnownTripleParsing(
                tripleName: "armv7em-apple-none-eabihf-macho",
                expectedArch: .arm,
                expectedSubArch : .arm(.v7em),
                expectedVendor: .apple,
                expectedOs: .noneOS,
                expectedEnvironment: .eabihf,
                expectedObjectFormat: .macho
            ),
            DataKnownTripleParsing(
                tripleName: "x86_64-apple-macosx",
                expectedArch: .x86_64,
                expectedSubArch: nil,
                expectedVendor: .apple,
                expectedOs: .macosx,
                expectedEnvironment: nil,
                expectedObjectFormat: .macho
            ),
            DataKnownTripleParsing(
                tripleName: "x86_64-unknown-linux-gnu",
                expectedArch: .x86_64,
                expectedSubArch: nil,
                expectedVendor: nil,
                expectedOs: .linux,
                expectedEnvironment: .gnu,
                expectedObjectFormat: .elf
            ),
            DataKnownTripleParsing(
                tripleName: "aarch64-unknown-linux-gnu",
                expectedArch: .aarch64,
                expectedSubArch: nil,
                expectedVendor: nil,
                expectedOs: .linux,
                expectedEnvironment: .gnu,
                expectedObjectFormat: .elf
            ),
            DataKnownTripleParsing(
                tripleName: "aarch64-unknown-linux-android",
                expectedArch: .aarch64,
                expectedSubArch: nil,
                expectedVendor: nil,
                expectedOs: .linux,
                expectedEnvironment: .android,
                expectedObjectFormat: .elf
            ),
            DataKnownTripleParsing(
                tripleName: "x86_64-unknown-windows-msvc",
                expectedArch: .x86_64,
                expectedSubArch: nil,
                expectedVendor: nil,
                expectedOs: .win32,
                expectedEnvironment: .msvc,
                expectedObjectFormat: .coff
            ),
            DataKnownTripleParsing(
                tripleName: "wasm32-unknown-wasi",
                expectedArch: .wasm32,
                expectedSubArch: nil,
                expectedVendor: nil,
                expectedOs: .wasi,
                expectedEnvironment: nil,
                expectedObjectFormat: .wasm
            )
        ]
    )
   func knownTripleParsing(_ data: DataKnownTripleParsing) {
            guard let triple = try? Triple(data.tripleName) else {
                Issue.record("Unknown triple '\(data.tripleName)'.")
               return
            }
            #expect(triple.arch == data.expectedArch)
            #expect(triple.subArch == data.expectedSubArch)
            #expect(triple.vendor == data.expectedVendor)
            #expect(triple.os == data.expectedOs)
            #expect(triple.environment == data.expectedEnvironment)
            #expect(triple.objectFormat == data.expectedObjectFormat)
   }

    @Test
    func tripleValidation() {
        let linux = try? Triple("x86_64-unknown-linux-gnu")
        #expect(linux != nil)
        #expect(linux!.os == .linux)
        #expect(linux!.osVersion == Triple.Version.zero)
        #expect(linux!.environment == .gnu)

        let macos = try? Triple("x86_64-apple-macosx10.15")
        #expect(macos! != nil)
        #expect(macos!.osVersion == .init(parse: "10.15"))
        let newVersion = "10.12"
        let tripleString = macos!.tripleString(forPlatformVersion: newVersion)
        #expect(tripleString == "x86_64-apple-macosx10.12")
        let macosNoX = try? Triple("x86_64-apple-macos12.2")
        #expect(macosNoX! != nil)
        #expect(macosNoX!.os == .macosx)
        #expect(macosNoX!.osVersion == .init(parse: "12.2"))

        let android = try? Triple("aarch64-unknown-linux-android24")
        #expect(android != nil)
        #expect(android!.os == .linux)
        #expect(android!.environment == .android)

        let linuxWithABIVersion = try? Triple("x86_64-unknown-linux-gnu42")
        #expect(linuxWithABIVersion!.environment == .gnu)
    }

    @Test
   func equalityOperator() throws {
       let macOSTriple = try Triple("arm64-apple-macos")
       let macOSXTriple = try Triple("arm64-apple-macosx")
        #expect(macOSTriple == macOSXTriple)

       let intelMacOSTriple = try Triple("x86_64-apple-macos")
        #expect(macOSTriple != intelMacOSTriple)

       let linuxWithoutGNUABI = try Triple("x86_64-unknown-linux")
       let linuxWithGNUABI = try Triple("x86_64-unknown-linux-gnu")
        #expect(linuxWithoutGNUABI != linuxWithGNUABI)
   }

    @Test
    func WASI() throws {
        let wasi = try Triple("wasm32-unknown-wasi")



        // WASI dynamic libraries are only experimental,
        // but SwiftPM requires this property not to crash.
        _ = wasi.dynamicLibraryExtension
    }

    struct DataNoneOsDynamicLibrary {
        var tripleName: String
        var expected: String
    }

    @Test(
        "Test dynamicLibraryExtesion attribute on Triple returns expected value",
        arguments: [
            DataNoneOsDynamicLibrary(tripleName: "armv7em-unknown-none-coff", expected: ".coff"),
            DataNoneOsDynamicLibrary(tripleName: "armv7em-unknown-none-elf", expected: ".elf"),
            DataNoneOsDynamicLibrary(tripleName: "armv7em-unknown-none-macho", expected: ".macho"),
            DataNoneOsDynamicLibrary(tripleName: "armv7em-unknown-none-wasm", expected: ".wasm"),
            DataNoneOsDynamicLibrary(tripleName: "armv7em-unknown-none-xcoff", expected: ".xcoff"),
            DataNoneOsDynamicLibrary(tripleName: "wasm32-unknown-wasi", expected: ".wasm"), // Added by bkhouri
        ]
    )
    func noneOSDynamicLibrary(_ data: DataNoneOsDynamicLibrary) throws {
        // Dynamic libraries aren't actually supported for OS none, but swiftpm
        // wants an extension to avoid crashing during build planning.
        let triple = try Triple(data.tripleName)
        #expect(triple.dynamicLibraryExtension == data.expected)
    }

    struct DataIsRuntimeCompatibleWith {
        var firstTripleName: String
        var secondTripleName: String
        var isCompatible: Bool
    }
    @Test(
        "isRuntimeCompatibleWith returns expected value",
        arguments:[
            DataIsRuntimeCompatibleWith(firstTripleName: "x86_64-apple-macosx", secondTripleName: "x86_64-apple-macosx", isCompatible: true),
            DataIsRuntimeCompatibleWith(firstTripleName: "x86_64-unknown-linux", secondTripleName: "x86_64-unknown-linux", isCompatible: true),
            DataIsRuntimeCompatibleWith(firstTripleName: "x86_64-apple-macosx", secondTripleName: "x86_64-apple-linux", isCompatible: false),
            DataIsRuntimeCompatibleWith(firstTripleName: "x86_64-apple-macosx14.0", secondTripleName: "x86_64-apple-macosx13.0", isCompatible: true),
        ]
    )
    func isRuntimeCompatibleWith(_ data: DataIsRuntimeCompatibleWith) throws {
        let triple = try Triple(data.firstTripleName)
        let other = try Triple(data.secondTripleName)
        #expect(triple.isRuntimeCompatible(with: other ) == data.isCompatible)
   }
}
