//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2025 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Foundation

import Basics
import Commands
import struct SPMBuildCore.BuildSystemProvider
import PackageModel
import _InternalTestSupport
import TSCTestSupport
import Testing

@Suite(
    .serialized, // to limit the number of swift executable running.
    .tags(
        Tag.TestSize.large,
        Tag.Feature.Command.Test,
    )
)
struct TestCommandTestCase {

    private func execute(
        _ args: [String],
        packagePath: AbsolutePath? = nil,
        configuration: BuildConfiguration = .debug,
        buildSystem: BuildSystemProvider.Kind,
        throwIfCommandFails: Bool = true
    ) async throws -> (stdout: String, stderr: String) {
        try await executeSwiftTest(
            packagePath,
            configuration: configuration,
            extraArgs: args,
            throwIfCommandFails: throwIfCommandFails,
            buildSystem: buildSystem,
        )
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func usage(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        let stdout = try await execute(["-help"], buildSystem: buildSystem).stdout
        #expect(stdout.contains("USAGE: swift test"), "got stdout:\n\(stdout)")
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func experimentalXunitMessageFailureArgumentIsHidden(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        let stdout = try await execute(["--help"], buildSystem: buildSystem).stdout
        #expect(
            !stdout.contains("--experimental-xunit-message-failure"),
            "got stdout:\n\(stdout)",
        )
        #expect(
            !stdout.contains("When Set, enabled an experimental message failure content (XCTest only)."),
            "got stdout:\n\(stdout)",
        )
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func seeAlso(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        let stdout = try await execute(["--help"], buildSystem: buildSystem).stdout
        #expect(stdout.contains("SEE ALSO: swift build, swift run, swift package"), "got stdout:\n\(stdout)")
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func version(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        let stdout = try await execute(["--version"], buildSystem: buildSystem).stdout
        let versionRegex = try Regex(#"Swift Package Manager -( \w+ )?\d+.\d+.\d+(-\w+)?"#)
        #expect(stdout.contains(versionRegex))
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func toolsetRunner(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/EchoExecutable") { fixturePath in
            #if os(Windows)
                let win32 = ".win32"
            #else
                let win32 = ""
            #endif
            let (stdout, stderr) = try await execute(
                    ["--toolset", "\(fixturePath.appending("toolset\(win32).json").pathString)"],
                    packagePath: fixturePath,
                    buildSystem: buildSystem,
                )
            // We only expect tool's output on the stdout stream.
            #expect(stdout.contains("sentinel"))
            #expect(stdout.contains("\(fixturePath)"))

            // swift-build-tool output should go to stderr.
            withKnownIssue {
                #expect(stderr.contains("Compiling"))
            } when: { buildSystem == .swiftbuild}

            withKnownIssue {
                #expect(stderr.contains("Linking"))
            } when: { buildSystem == .swiftbuild}
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testNumWorkersParallelRequirement(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/EchoExecutable") { fixturePath in
            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--num-workers", "1"],
                    packagePath: fixturePath,
                    buildSystem: buildSystem,
                )
            }
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }

            #expect(
                stderr.contains("error: --num-workers must be used with --parallel"),
                "got stdout: \(stdout), stderr: \(stderr)",
            )
        }
    }

//     func testNumWorkersValue() async throws {
//         #if !os(macOS)
//         // Running swift-test fixtures on linux is not yet possible.
//         try XCTSkipIf(true, "test is only supported on macOS")
//         #endif
//         try await fixture(name: "Miscellaneous/EchoExecutable") { fixturePath in
//             await XCTAssertThrowsCommandExecutionError(try await execute(["--parallel", "--num-workers", "0"])) { error in
//                 XCTAssertMatch(error.stderr, .contains("error: '--num-workers' must be greater than zero"))
//             }
//         }
//     }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms, BuildConfiguration.allCases,
    )
    func enableDisableTestabilityDefaultShouldRunWithTestability(
        buildSystem: BuildSystemProvider.Kind,
        configuration: BuildConfiguration,
    ) async throws {
        // default should run with testability
        try await fixture(name: "Miscellaneous/TestableExe") { fixturePath in
            let result = try await execute(
                ["--vv"],
                packagePath: fixturePath,
                configuration: configuration,
                buildSystem: buildSystem,
            )
            #expect(result.stderr.contains("-enable-testing"))
        }
    }

    @Test(
        .SWBINTTODO("Test currently fails due to 'error: build failed'"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func enableDisableTestabilityDisabled(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        // disabled
        try await fixture(name: "Miscellaneous/TestableExe") { fixturePath in
        //     await XCTAssertThrowsCommandExecutionError(try await execute(["--disable-testable-imports", "--vv"], packagePath: fixturePath, buildSystem: buildSystem)) { error in
        //         XCTAssertMatch(error.stderr, .contains("was not compiled for testing"))
        //     }

            let error = await #expect(throws: SwiftPMError.self ) {
                try await execute(
                    ["--disable-testable-imports", "--vv"],
                    packagePath: fixturePath,
                    buildSystem: buildSystem,
                )
            }
            guard case SwiftPMError.executionFailure(_, _, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }

            #expect(
                stderr.contains("was not compiled for testing"),
                "got stdout: \(stdout), stderr: \(stderr)",
            )
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func enableDisableTestabilityEnabled(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        // enabled
        try await fixture(name: "Miscellaneous/TestableExe") { fixturePath in
            let result = try await execute(["--enable-testable-imports", "--vv"], packagePath: fixturePath, buildSystem: buildSystem)
            #expect(result.stderr.contains("-enable-testing"))
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func swiftTestParallel_SerialTesting(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/ParallelTestsPkg") { fixturePath in
            // First try normal serial testing.
            let error = await #expect(throws: SwiftPMError.self) {
                try await executeSwiftTest(fixturePath, extraArgs: [], buildSystem: buildSystem)
            }
            guard case SwiftPMError.executionFailure(_, let stdout, _) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stdout.contains("Executed 2 tests"))
            #expect(!stdout.contains("[3/3]"))
            // try await executeSwiftTest(fixturePath, throwIfCommandFails: false, buildSystem: buildSystem,)
            // await XCTAssertThrowsCommandExecutionError() { error in
            //     // in "swift test" test output goes to stdout
            //     XCTAssertMatch(error.stdout, .contains("Executed 2 tests"))
            //     XCTAssertNoMatch(error.stdout, .contains("[3/3]"))
            // }
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func swiftTestParallel_NoParallelArgument(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/ParallelTestsPkg") { fixturePath in
            // Try --no-parallel.
            let error = await #expect(throws: SwiftPMError.self) {
                try await execute(["--no-parallel"], packagePath: fixturePath, buildSystem: buildSystem)
            }
            guard case SwiftPMError.executionFailure(_, let stdout, _) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stdout.contains("Executed 2 tests"))
            #expect(!stdout.contains("[3/3]"))

            // await XCTAssertThrowsCommandExecutionError(try await execute(["--no-parallel"], packagePath: fixturePath, buildSystem: buildSystem)) { error in
            //     // in "swift test" test output goes to stdout
            //     XCTAssertMatch(error.stdout, .contains("Executed 2 tests"))
            //     XCTAssertNoMatch(error.stdout, .contains("[3/3]"))
            // }
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func swiftTestParallel_ParallelArgument(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/ParallelTestsPkg") { fixturePath in
            // Run tests in parallel.
            let error = await #expect(throws: SwiftPMError.self) {
                try await execute(["--parallel"], packagePath: fixturePath, buildSystem: buildSystem)
            }
            guard case SwiftPMError.executionFailure(_, let stdout, _) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stdout.contains("testExample1"))
            #expect(stdout.contains("testExample2"))
            #expect(!stdout.contains("'ParallelTestsTests' passed"))
            #expect(stdout.contains("'ParallelTestsFailureTests' failed"))
            #expect(stdout.contains("[3/3]"))

            // await XCTAssertThrowsCommandExecutionError(try await execute(["--parallel"], packagePath: fixturePath, buildSystem: buildSystem)) { error in
            //     // in "swift test" test output goes to stdout
            //     XCTAssertMatch(error.stdout, .contains("testExample1"))
            //     XCTAssertMatch(error.stdout, .contains("testExample2"))
            //     XCTAssertNoMatch(error.stdout, .contains("'ParallelTestsTests' passed"))
            //     XCTAssertMatch(error.stdout, .contains("'ParallelTestsFailureTests' failed"))
            //     XCTAssertMatch(error.stdout, .contains("[3/3]"))
            // }
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func swiftTestParallel_ParallelArgumentWithXunitOutputGeneration(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/ParallelTestsPkg") { fixturePath in
            let xUnitOutput = fixturePath.appending("result.xml")
            // Run tests in parallel with verbose output.
            let error = await #expect(throws: SwiftPMError.self) {
                try await execute(
                    [
                        "--parallel",
                        "--verbose",
                        "--xunit-output",
                        xUnitOutput.pathString,
                    ],
                    packagePath: fixturePath,
                    buildSystem: buildSystem,
                )
            }
            guard case SwiftPMError.executionFailure(_, let stdout, _) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(stdout.contains("testExample1"))
            #expect(stdout.contains("testExample2"))
            #expect(stdout.contains("'ParallelTestsTests' passed"))
            #expect(stdout.contains("'ParallelTestsFailureTests' failed"))
            #expect(stdout.contains("[3/3]"))

            // Check the xUnit output.
            #expect(localFileSystem.exists(xUnitOutput), "\(xUnitOutput) does not exist")
            let contents: String = try localFileSystem.readFileContents(xUnitOutput)
            #expect(contents.contains("tests=\"3\" failures=\"1\""))
            let timeRegex = try Regex("time=\"[0-9]+\\.[0-9]+\"")
            #expect(contents.contains(timeRegex))
            #expect(!contents.contains("time=\"0.0\""))
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func swiftTestXMLOutputWhenEmpty(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/EmptyTestsPkg") { fixturePath in
            let xUnitOutput = fixturePath.appending("result.xml")
            // Run tests in parallel with verbose output.
            _ = try await execute(
                ["--parallel", "--verbose", "--xunit-output", xUnitOutput.pathString],
                packagePath: fixturePath,
                buildSystem: buildSystem,
            ).stdout

            // Check the xUnit output.
            #expect(localFileSystem.exists(xUnitOutput))
            let contents: String = try localFileSystem.readFileContents(xUnitOutput)
            #expect(contents.contains("tests=\"0\" failures=\"0\""))
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    enum TestRunner {
        case XCTest
        case SwiftTesting

        var fileSuffix: String {
            switch self {
                case .XCTest: return ""
                case .SwiftTesting: return "-swift-testing"
            }
        }
    }

    public typealias SwiftTestXMLOutputData = (
        fixtureName: String,
        testRunner: TestRunner,
        enableExperimentalFlag: Bool,
        matchesPattern: [String]
    )

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms.filter { $0 != .xcode }, [
            (
                fixtureName: "Miscellaneous/TestSingleFailureXCTest",
                testRunner: TestRunner.XCTest,
                enableExperimentalFlag: true,
                matchesPattern: ["Purposely failing &amp; validating XML espace &quot;'&lt;&gt;"],
            ),
            (
                fixtureName: "Miscellaneous/TestSingleFailureSwiftTesting",
                testRunner: TestRunner.SwiftTesting,
                enableExperimentalFlag: true,
                matchesPattern: ["Purposely failing &amp; validating XML espace &quot;'&lt;&gt;"]
            ),
            (
                fixtureName: "Miscellaneous/TestSingleFailureXCTest",
                testRunner: TestRunner.XCTest,
                enableExperimentalFlag: false,
                matchesPattern: ["failure"]
            ),
            (
                fixtureName: "Miscellaneous/TestSingleFailureSwiftTesting",
                testRunner: TestRunner.SwiftTesting,
                enableExperimentalFlag: false,
                matchesPattern: ["Purposely failing &amp; validating XML espace &quot;'&lt;&gt;"]
            ),
            (
                fixtureName: "Miscellaneous/TestMultipleFailureXCTest",
                testRunner: TestRunner.XCTest,
                enableExperimentalFlag: true,
                matchesPattern: [
                    "Test failure 1",
                    "Test failure 2",
                    "Test failure 3",
                    "Test failure 4",
                    "Test failure 5",
                    "Test failure 6",
                    "Test failure 7",
                    "Test failure 8",
                    "Test failure 9",
                    "Test failure 10",
                ],
            ),
            (
                fixtureName: "Miscellaneous/TestMultipleFailureSwiftTesting",
                testRunner: TestRunner.SwiftTesting,
                enableExperimentalFlag: true,
                matchesPattern: [
                    "ST Test failure 1",
                    "ST Test failure 2",
                    "ST Test failure 3",
                    "ST Test failure 4",
                    "ST Test failure 5",
                    "ST Test failure 6",
                    "ST Test failure 7",
                    "ST Test failure 8",
                    "ST Test failure 9",
                    "ST Test failure 10",
                ]
            ),
            (
                fixtureName: "Miscellaneous/TestMultipleFailureXCTest",
                testRunner: TestRunner.XCTest,
                enableExperimentalFlag: false,
                matchesPattern: [
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                    "failure",
                ]
            ),
            (
                fixtureName: "Miscellaneous/TestMultipleFailureSwiftTesting",
                testRunner: TestRunner.SwiftTesting,
                enableExperimentalFlag: false,
                matchesPattern: [
                    "ST Test failure 1",
                    "ST Test failure 2",
                    "ST Test failure 3",
                    "ST Test failure 4",
                    "ST Test failure 5",
                    "ST Test failure 6",
                    "ST Test failure 7",
                    "ST Test failure 8",
                    "ST Test failure 9",
                    "ST Test failure 10",
                ]
            ),
        ]
    )
    func swiftTestXMLOutputFailureMessage(
        buildSystem: BuildSystemProvider.Kind,
        tcdata: SwiftTestXMLOutputData,
    ) async throws {
        try await withKnownIssue {
            try await fixture(name: tcdata.fixtureName) { fixturePath in
                // GIVEN we have a Package with a failing \(testRunner) test cases
                let xUnitOutput = fixturePath.appending("result.xml")
                let xUnitUnderTest = fixturePath.appending("result\(tcdata.testRunner.fileSuffix).xml")

                // WHEN we execute swift-test in parallel while specifying xUnit generation
                let extraCommandArgs = tcdata.enableExperimentalFlag ? ["--experimental-xunit-message-failure"]: []
                let (stdout, stderr) = try await execute(
                    [
                        "--parallel",
                        "--verbose",
                        "--enable-swift-testing",
                        "--enable-xctest",
                        "--xunit-output",
                        xUnitOutput.pathString
                    ] + extraCommandArgs,
                    packagePath: fixturePath,
                    buildSystem: buildSystem,
                    throwIfCommandFails: false,
                )

                if !FileManager.default.fileExists(atPath: xUnitUnderTest.pathString) {
                    // If the build failed then produce a output dump of what happened during the execution
                    print("\(stdout)")
                    print("\(stderr)")
                }

                // THEN we expect \(xUnitUnderTest) to exists
                #expect(FileManager.default.fileExists(atPath: xUnitUnderTest.pathString))
                let contents: String = try localFileSystem.readFileContents(xUnitUnderTest)
                // AND that the xUnit file has the expected contents
                for match in tcdata.matchesPattern {
                    #expect(contents.contains(match))
                }
            } 
        } when: {
            (buildSystem == .swiftbuild && tcdata.testRunner == .SwiftTesting) || ProcessInfo.hostOperatingSystem == .windows
        }
    }


    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func swiftTestFilter(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        // SwiftBuild: skip test is not on macOS
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/SkipTests") { fixturePath in
            let (stdout, _) = try await execute(["--filter", ".*1"], packagePath: fixturePath, buildSystem: buildSystem)
            // in "swift test" test output goes to stdout
            #expect(stdout.contains("testExample1"))
            #expect(!stdout.contains("testExample2"))
            #expect(!stdout.contains("testExample3"))
            #expect(!stdout.contains("testExample4"))
        }

        try await fixture(name: "Miscellaneous/SkipTests") { fixturePath in
            let (stdout, _) = try await execute(["--filter", "SomeTests", "--skip", ".*1", "--filter", "testExample3"], packagePath: fixturePath, buildSystem: buildSystem)
            // in "swift test" test output goes to stdout
            #expect(!stdout.contains("testExample1"))
            #expect(stdout.contains("testExample2"))
            #expect(stdout.contains("testExample3"))
            #expect(!stdout.contains("testExample4"))
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8479", relationship: .defect),
        .SWBINTTODO("Result XML could not be found. The build fails because of missing test helper generation logic for non-macOS platforms"),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testSwiftTestSkip(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/SkipTests") { fixturePath in
            let (stdout, _) = try await execute(["--skip", "SomeTests"], packagePath: fixturePath, buildSystem: buildSystem)
            // in "swift test" test output goes to stdout
            #expect(!stdout.contains("testExample1"))
            #expect(!stdout.contains("testExample2"))
            #expect(stdout.contains("testExample3"))
            #expect(stdout.contains("testExample4"))
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }

        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/SkipTests") { fixturePath in
            let (stdout, _) = try await execute(
                [
                    "--filter",
                    "ExampleTests",
                    "--skip",
                    ".*2",
                    "--filter",
                    "MoreTests",
                    "--skip", "testExample3",
                ],
                packagePath: fixturePath,
                buildSystem: buildSystem,
            )
            // in "swift test" test output goes to stdout
            #expect(stdout.contains("testExample1"))
            #expect(!stdout.contains("testExample2"))
            #expect(!stdout.contains("testExample3"))
            #expect(stdout.contains("testExample4"))
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }

        try await withKnownIssue {
        try await fixture(name: "Miscellaneous/SkipTests") { fixturePath in
            let (stdout, _) = try await execute(["--skip", "Tests"], packagePath: fixturePath, buildSystem: buildSystem)
            // in "swift test" test output goes to stdout
            #expect(!stdout.contains("testExample1"))
            #expect(!stdout.contains("testExample2"))
            #expect(!stdout.contains("testExample3"))
            #expect(!stdout.contains("testExample4"))
        }
        } when: {
            [.linux, .windows].contains(ProcessInfo.hostOperatingSystem) && buildSystem == .swiftbuild
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testEnableTestDiscoveryDeprecation(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        let compilerDiagnosticFlags = ["-Xswiftc", "-Xfrontend", "-Xswiftc", "-Rmodule-interface-rebuild"]
        // should emit when LinuxMain is present
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            let (_, stderr) = try await execute(["--enable-test-discovery"] + compilerDiagnosticFlags, packagePath: fixturePath, buildSystem: buildSystem)
            #expect(stderr.contains("warning: '--enable-test-discovery' option is deprecated"))
        }

        #if canImport(Darwin)
        let expected = true
        // should emit when LinuxMain is not present
        #else
        // should not emit when LinuxMain is present
        let expected = false
        #endif
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            try localFileSystem.writeFileContents(fixturePath.appending(components: "Tests", SwiftModule.defaultTestEntryPointName), bytes: "fatalError(\"boom\")")
            let (_, stderr) = try await execute(["--enable-test-discovery"] + compilerDiagnosticFlags, packagePath: fixturePath, buildSystem: buildSystem)
            #expect(stderr.contains("warning: '--enable-test-discovery' option is deprecated") == expected)
        }
    }

    @Test(
        .tags(
            Tag.Feature.Command.Build,
        ),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testListWithoutBuildingFirst(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            let (stdout, stderr) = try await execute(["list"], packagePath: fixturePath, buildSystem: buildSystem)
            // build was run
            #expect(stderr.contains("Build complete!"))
            // getting the lists
            #expect(stdout.contains("SimpleTests.SimpleTests/testExample1"))
            #expect(stdout.contains("SimpleTests.SimpleTests/test_Example2"))
            #expect(stdout.contains("SimpleTests.SimpleTests/testThrowing"))
        }
    }

    @Test(
        .tags(
            Tag.Feature.Command.Build,
        ),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testListBuildFirstThenList(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            // build first
            let (buildStdout, _) = try await executeSwiftBuild(fixturePath, extraArgs: ["--build-tests"], buildSystem: buildSystem)
            #expect(buildStdout.contains("Build complete!"))

            // list
            let (listStdout, listStderr) = try await execute(["list"], packagePath: fixturePath, buildSystem: buildSystem)
            // build was run
            #expect(listStderr.contains("Build complete!"))
            // getting the lists
            #expect(listStdout.contains("SimpleTests.SimpleTests/testExample1"))
            #expect(listStdout.contains("SimpleTests.SimpleTests/test_Example2"))
            #expect(listStdout.contains("SimpleTests.SimpleTests/testThrowing"))
        }
    }

    @Test(
        .tags(
            Tag.Feature.Command.Build,
        ),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testListBuildFirstThenListWhileSkippingBuild(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            // build first
            let (buildStdout, _) = try await executeSwiftBuild(fixturePath, extraArgs: ["--build-tests"], buildSystem: buildSystem)
            #expect(buildStdout.contains("Build complete!"))

            // list while skipping build
            let (listStdout, listStderr) = try await execute(["list", "--skip-build"], packagePath: fixturePath, buildSystem: buildSystem)
            // build was not run
            #expect(!listStderr.contains("Build complete!"))
            // getting the lists
            #expect(listStdout.contains("SimpleTests.SimpleTests/testExample1"))
            #expect(listStdout.contains("SimpleTests.SimpleTests/test_Example2"))
            #expect(listStdout.contains("SimpleTests.SimpleTests/testThrowing"))
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testListWithSkipBuildAndNoBuildArtifacts(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            let error = await #expect(throws: SwiftPMError.self) {
                try await execute(
                    ["list", "--skip-build"],
                    packagePath: fixturePath,
                    buildSystem: buildSystem,
                    throwIfCommandFails: true,
                )
            }
            guard case SwiftPMError.executionFailure(_, let stdout, let stderr) = try #require(error) else {
                Issue.record("Incorrect error was raised.")
                return
            }
            #expect(
                stderr.contains("Test build artifacts were not found in the build folder"),
                "got stdout: \(stdout), stderr: \(stderr)",
            )
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testBasicSwiftTestingIntegration(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/TestDiscovery/SwiftTesting") { fixturePath in
            let (stdout, _) = try await execute(
                ["--enable-swift-testing", "--disable-xctest"],
                packagePath: fixturePath,
                buildSystem: buildSystem,
            )
            #expect(stdout.contains(#"Test "SOME TEST FUNCTION" started"#))
        }
    }

    @Test(
        .skipHostOS(.macOS), // because this was guarded with `#if !canImport(Darwin)`
        .SWBINTTODO("This is a PIF builder missing GUID problem. Further investigation is needed."),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func generatedMainIsConcurrencySafe_XCTest(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        let strictConcurrencyFlags = ["-Xswiftc", "-strict-concurrency=complete"]
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            let (_, stderr) = try await execute(strictConcurrencyFlags, packagePath: fixturePath, buildSystem: buildSystem)
            #expect(!stderr.contains("is not concurrency-safe"))
        }
        } when: {
            buildSystem == .swiftbuild
        }
    }
    @Test(
        .skipHostOS(.macOS), // because this was guarded with `#if !canImport(Darwin)`
        .SWBINTTODO("This is a PIF builder missing GUID problem. Further investigation is needed."),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func generatedMainIsExistentialAnyClean(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue {
        let existentialAnyFlags = ["-Xswiftc", "-enable-upcoming-feature", "-Xswiftc", "ExistentialAny"]
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            let (_, stderr) = try await execute(existentialAnyFlags, packagePath: fixturePath, buildSystem: buildSystem)
            #expect(!stderr.contains("error: use of protocol"))
        }
        } when: {
            buildSystem == .swiftbuild
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func testLibraryEnvironmentVariable(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await withKnownIssue("produces a filepath that is too long, needs investigation") {
            try await fixture(name: "Miscellaneous/CheckTestLibraryEnvironmentVariable") { fixturePath in
                var extraEnv = Environment()
                if try UserToolchain.default.swiftTestingPath != nil {
                    extraEnv["CONTAINS_SWIFT_TESTING"] = "1"
                }
                await #expect(throws: Never.self) {
                    try await executeSwiftTest(fixturePath, env: extraEnv, buildSystem: buildSystem)
                }
            }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows
        }
    }

    @Test(
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
    func XCTestOnlyDoesNotLogAboutNoMatchingTests(
        buildSystem: BuildSystemProvider.Kind,
    ) async throws {
        try await fixture(name: "Miscellaneous/TestDiscovery/Simple") { fixturePath in
            let (_, stderr) = try await execute(["--disable-swift-testing"], packagePath: fixturePath, buildSystem: buildSystem)
            #expect(!stderr.contains("No matching test cases were run"))
        }
    }

     @Test(
        .issue("https://github.com/swiftlang/swift-package-manager/issues/6605", relationship: .verifies),
        .issue("https://github.com/swiftlang/swift-package-manager/issues/8602", relationship: .defect),
        arguments: SupportedBuildSystemOnAllPlatforms,
    )
   func fatalErrorDisplayedCorrectNumberOfTimesWhenSingleXCTestHasFatalErrorInBuildCompilation(
        buildSystem: BuildSystemProvider.Kind,
   ) async throws {
        try await withKnownIssue {
            // GIVEN we have a Swift Package that has a fatalError building the tests
            let expected = 1
            try await fixture(name: "Miscellaneous/Errors/FatalErrorInSingleXCTest/TypeLibrary") { fixturePath in
                // WHEN swift-test is executed
                let error = await #expect(throws: SwiftPMError.self) {
                    try await self.execute(
                        [],
                        packagePath: fixturePath,
                        buildSystem: buildSystem,
                    )
                }

                // THEN I expect a failure
                guard case SwiftPMError.executionFailure(_, let stdout, let stderr) = try #require(error) else {
                    Issue.record("Building the package was expected to fail, but it was successful.")
                    return
                }

                let matchString = "error: fatalError"
                let stdoutMatches = getNumberOfMatches(of: matchString, in: stdout)
                let stderrMatches = getNumberOfMatches(of: matchString, in: stderr)
                let actualNumMatches = stdoutMatches + stderrMatches

                // AND a fatal error message is printed \(expected) times
                let expectationMessage = [
                        "Actual (\(actualNumMatches)) is not as expected (\(expected))",
                        "stdout: \(stdout.debugDescription)",
                        "stderr: \(stderr.debugDescription)"
                    ].joined(separator: "\n")
                #expect(
                    actualNumMatches == expected,
                    "\(expectationMessage)",
                )
            }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows || isInCiEnvironment
        }
    }

}
