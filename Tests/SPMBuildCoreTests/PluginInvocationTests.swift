//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

@_spi(SwiftPMInternal)
import Basics

@_spi(DontAdoptOutsideOfSwiftPMExposedForBenchmarksAndTestsOnly)
@testable import PackageGraph

import PackageLoading

@_spi(SwiftPMInternal)
import PackageModel

@testable import SPMBuildCore
import _InternalTestSupport
import Workspace
import Testing

@testable import class Build.BuildPlan
import struct Build.PluginConfiguration

import struct TSCUtility.SerializedDiagnostics


extension Trait where Self == Testing.ConditionTrait {
    public static var foo: Self {
        .disabled("dfeskipping because test environment doesn't support concurrency")
        // disabled(if: try !UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        // .disabled(if: true, "skipping because test environment doesn't support concurrency")
    }
}

struct PluginInvocationTests {
    @Test
    func basics() async throws {
        let fileSystem = InMemoryFileSystem(emptyFiles:
            "/Foo/Plugins/FooPlugin/source.swift",
            "/Foo/Sources/FooTool/source.swift",
            "/Foo/Sources/FooToolLib/source.swift",
            "/Foo/Sources/Foo/source.swift",
            "/Foo/Sources/Foo/SomeFile.abc"
        )
        let observability = ObservabilitySystem.makeForTesting()
        let graph = try loadModulesGraph(
            fileSystem: fileSystem,
            manifests: [
                Manifest.createRootManifest(
                    displayName: "Foo",
                    path: "/Foo",
                    products: [
                        ProductDescription(
                            name: "Foo",
                            type: .library(.dynamic),
                            targets: ["Foo"]
                        )
                    ],
                    targets: [
                        TargetDescription(
                            name: "Foo",
                            type: .regular,
                            pluginUsages: [.plugin(name: "FooPlugin", package: nil)]
                        ),
                        TargetDescription(
                            name: "FooPlugin",
                            dependencies: ["FooTool"],
                            type: .plugin,
                            pluginCapability: .buildTool
                        ),
                        TargetDescription(
                            name: "FooTool",
                            dependencies: ["FooToolLib"],
                            type: .executable
                        ),
                        TargetDescription(
                            name: "FooToolLib",
                            dependencies: [],
                            type: .regular
                        ),
                    ]
                )
            ],
            observabilityScope: observability.topScope
        )

        // Check the basic integrity before running plugins.
        try requireNoDiagnostics(observability.diagnostics)
        PackageGraphTester(graph) { graph in
            graph.check(packages: "Foo")
            graph.check(modules: "Foo", "FooPlugin", "FooTool", "FooToolLib")
            graph.checkTarget("Foo") { target in
                target.check(dependencies: "FooPlugin")
            }
            graph.checkTarget("FooPlugin") { target in
                target.check(type: .plugin)
                target.check(dependencies: "FooTool")
            }
            graph.checkTarget("FooTool") { target in
                target.check(type: .executable)
                target.checkDependency("FooToolLib") { dependency in
                    dependency.checkTarget { _ in
                    }
                }
            }
        }

        // "FooTool{Lib}" duplicated as it's present for both build host and end target.
        do {
            let buildPlanResult = try await BuildPlanResult(plan: mockBuildPlan(
                graph: graph,
                linkingParameters: .init(
                    shouldLinkStaticSwiftStdlib: true
                ),
                fileSystem: fileSystem,
                observabilityScope: observability.topScope
            ))
            buildPlanResult.checkProductsCount(3)
            buildPlanResult.checkTargetsCount(5) // Note: plugins are not included here.

            buildPlanResult.check(destination: .target, for: "Foo")

            buildPlanResult.check(destination: .host, for: "FooTool")
            buildPlanResult.check(destination: .target, for: "FooTool")

            buildPlanResult.check(destination: .host, for: "FooToolLib")
            buildPlanResult.check(destination: .target, for: "FooToolLib")
        }

        // A fake PluginScriptRunner that just checks the input conditions and returns canned output.
        struct MockPluginScriptRunner: PluginScriptRunner {
            var hostTriple: Triple {
                get throws {
                    return try UserToolchain.default.targetTriple
                }
            }

            func compilePluginScript(
                sourceFiles: [AbsolutePath],
                pluginName: String,
                toolsVersion: ToolsVersion,
                observabilityScope: ObservabilityScope,
                callbackQueue: DispatchQueue,
                delegate: PluginScriptCompilerDelegate,
                completion: @escaping (Result<PluginCompilationResult, Error>) -> Void
            ) {
                callbackQueue.sync {
                    completion(.failure(StringError("unimplemented")))
                }
            }

            func runPluginScript(
                sourceFiles: [AbsolutePath],
                pluginName: String,
                initialMessage: Data,
                toolsVersion: ToolsVersion,
                workingDirectory: AbsolutePath,
                writableDirectories: [AbsolutePath],
                readOnlyDirectories: [AbsolutePath],
                allowNetworkConnections: [SandboxNetworkPermission],
                fileSystem: FileSystem,
                observabilityScope: ObservabilityScope,
                callbackQueue: DispatchQueue,
                delegate: PluginScriptCompilerDelegate & PluginScriptRunnerDelegate,
                completion: @escaping (Result<Int32, Error>) -> Void
            ) {
                // Check that we were given the right sources.
                #expect(sourceFiles == ["/Foo/Plugins/FooPlugin/source.swift"])

                do {
                    // Pretend the plugin emitted some output.
                    callbackQueue.sync {
                        delegate.handleOutput(data: Data("Hello Plugin!".utf8))
                    }

                    // Pretend it emitted a warning.
                    try callbackQueue.sync {
                        let message = Data("""
                        {   "emitDiagnostic": {
                                "severity": "warning",
                                "message": "A warning",
                                "file": "/Foo/Sources/Foo/SomeFile.abc",
                                "line": 42
                            }
                        }
                        """.utf8)
                        try delegate.handleMessage(data: message, responder: { _ in })
                    }

                    // Pretend it defined a build command.
                    try callbackQueue.sync {
                        let message = Data("""
                        {   "defineBuildCommand": {
                                "configuration": {
                                    "version": 2,
                                    "displayName": "Do something",
                                    "executable": "file:///bin/FooTool",
                                    "arguments": [
                                        "-c", "/Foo/Sources/Foo/SomeFile.abc"
                                    ],
                                    "workingDirectory": "file:///Foo/Sources/Foo",
                                    "environment": {
                                        "X": "Y"
                                    },
                                },
                                "inputFiles": [
                                ],
                                "outputFiles": [
                                ]
                            }
                        }
                        """.utf8)
                        try delegate.handleMessage(data: message, responder: { _ in })
                    }
                }
                catch {
                    callbackQueue.sync {
                        completion(.failure(error))
                    }
                    return
                }

                // If we get this far we succeeded, so invoke the completion handler.
                callbackQueue.sync {
                    completion(.success(0))
                }
            }
        }

        // Construct a canned input and run plugins using our MockPluginScriptRunner().
        let outputDir = AbsolutePath("/Foo/.build")
        let pluginRunner = MockPluginScriptRunner()
        let buildParameters = mockBuildParameters(
            destination: .host,
            environment: BuildEnvironment(platform: .macOS, configuration: .debug)
        )

        let results = try await invokeBuildToolPlugins(
            graph: graph,
            buildParameters: buildParameters,
            fileSystem: fileSystem,
            outputDir: outputDir,
            pluginScriptRunner: pluginRunner,
            observabilityScope: observability.topScope
        )
        let builtToolsDir = AbsolutePath("/path/to/build/\(buildParameters.triple)/debug")

        // Check the canned output to make sure nothing was lost in transport.
        try requireNoDiagnostics(observability.diagnostics)
        #expect(results.count == 1)
        let (_, (evalTarget, evalResults)) = try #require(results.first)
        #expect(evalTarget.name == "Foo")

        #expect(evalResults.count == 1)
        let evalFirstResult = try #require(evalResults.first)
        #expect(evalFirstResult.prebuildCommands.count == 0)
        #expect(evalFirstResult.buildCommands.count == 1)
        let evalFirstCommand = try #require(evalFirstResult.buildCommands.first)
        #expect(evalFirstCommand.configuration.displayName == "Do something")
        #expect(evalFirstCommand.configuration.executable == AbsolutePath("/bin/FooTool"))
        #expect(evalFirstCommand.configuration.arguments == ["-c", "/Foo/Sources/Foo/SomeFile.abc"])
        #expect(evalFirstCommand.configuration.environment == ["X": "Y"])
        #expect(evalFirstCommand.configuration.workingDirectory == AbsolutePath("/Foo/Sources/Foo"))
        #expect(evalFirstCommand.inputFiles == [builtToolsDir.appending("FooTool")])
        #expect(evalFirstCommand.outputFiles == [])

        #expect(evalFirstResult.diagnostics.count == 1)
        let evalFirstDiagnostic = try #require(evalFirstResult.diagnostics.first)
        #expect(evalFirstDiagnostic.severity == .warning)
        #expect(evalFirstDiagnostic.message == "A warning")
        #expect(evalFirstDiagnostic.metadata?.fileLocation == FileLocation("/Foo/Sources/Foo/SomeFile.abc", line: 42))

        #expect(evalFirstResult.textOutput == "Hello Plugin!")
    }

    @Test
    func compilationDiagnostics() async throws {
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library target and a plugin.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(packageDir.appending("Package.swift"), string: """
                // swift-tools-version: 5.6
                import PackageDescription
                let package = Package(
                    name: "MyPackage",
                    targets: [
                        .target(
                            name: "MyLibrary",
                            plugins: [
                                "MyPlugin",
                            ]
                        ),
                        .plugin(
                            name: "MyPlugin",
                            capability: .buildTool()
                        ),
                    ]
                )
                """)

            let myLibraryTargetDir = packageDir.appending(components: "Sources", "MyLibrary")
            try localFileSystem.createDirectory(myLibraryTargetDir, recursive: true)
            try localFileSystem.writeFileContents(myLibraryTargetDir.appending("library.swift"), string: """
                public func Foo() { }
                """)

            let myPluginTargetDir = packageDir.appending(components: "Plugins", "MyPlugin")
            try localFileSystem.createDirectory(myPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: """
                import PackagePlugin
                @main struct MyBuildToolPlugin: BuildToolPlugin {
                    func createBuildCommands(
                        context: PluginContext,
                        target: Target
                    ) throws -> [Command] {
                        // missing return statement
                    }
                }
                """)

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            #expect(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            try requireNoDiagnostics(observability.diagnostics)
            #expect(packageGraph.packages.count == 1, "\(packageGraph.packages)")

            // Find the build tool plugin.
            let buildToolPlugin = try #require(packageGraph.packages.first?.modules.map(\.underlying).first{ $0.name == "MyPlugin" } as? PluginModule)
            #expect(buildToolPlugin.name == "MyPlugin")
            #expect(buildToolPlugin.capability == .buildTool)

            // Create a plugin script runner for the duration of the test.
            let pluginCacheDir = tmpPath.appending("plugin-cache")
            let pluginScriptRunner = DefaultPluginScriptRunner(
                fileSystem: localFileSystem,
                cacheDir: pluginCacheDir,
                toolchain: try UserToolchain.default
            )

            // Define a plugin compilation delegate that just captures the passed information.
            class Delegate: PluginScriptCompilerDelegate {
                var commandLine: [String]? 
                var environment: Environment?
                var compiledResult: PluginCompilationResult?
                var cachedResult: PluginCompilationResult?
                init() {
                }
                func willCompilePlugin(commandLine: [String], environment: [String: String]) {
                    self.commandLine = commandLine
                    self.environment = .init(environment)
                }
                func didCompilePlugin(result: PluginCompilationResult) {
                    self.compiledResult = result
                }
                func skippedCompilingPlugin(cachedResult: PluginCompilationResult) {
                    self.cachedResult = cachedResult
                }
            }

            // Try to compile the broken plugin script.
            do {
                let delegate = Delegate()
                let result = try await pluginScriptRunner.compilePluginScript(
                    sourceFiles: buildToolPlugin.sources.paths,
                    pluginName: buildToolPlugin.name,
                    toolsVersion: buildToolPlugin.apiVersion,
                    observabilityScope: observability.topScope,
                    callbackQueue: DispatchQueue.sharedConcurrent,
                    delegate: delegate
                )

                // This should invoke the compiler but should fail.
                #expect(result.succeeded == false)
                #expect(result.cached == false)
                #expect(result.commandLine.contains(result.executableFile.pathString), "\(result.commandLine)")
                #expect(result.executableFile.components.contains("plugin-cache"), "\(result.executableFile.pathString)")
                #expect(result.compilerOutput.contains("error: missing return"), "\(result.compilerOutput)")
                #expect(result.diagnosticsFile.suffix == ".dia", "\(result.diagnosticsFile.pathString)")

                // Check the delegate callbacks.
                #expect(delegate.commandLine == result.commandLine)
                #expect(delegate.environment != nil)
                #expect(delegate.compiledResult == result)
                #expect(delegate.cachedResult == nil)

                // Check the serialized diagnostics. We should have an error.
                let diaFileContents = try localFileSystem.readFileContents(result.diagnosticsFile)
                let diagnosticsSet = try SerializedDiagnostics(bytes: diaFileContents)
                #expect(diagnosticsSet.diagnostics.count == 1)
                let errorDiagnostic = try #require(diagnosticsSet.diagnostics.first)
                #expect(errorDiagnostic.text.hasPrefix("missing return"), "\(errorDiagnostic)")

                // Check that the executable file doesn't exist.
                #expect(!localFileSystem.exists(result.executableFile), "\(result.executableFile.pathString)")
            }

            // Now replace the plugin script source with syntactically valid contents that still produces a warning.
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: """
                import PackagePlugin
                @main struct MyBuildToolPlugin: BuildToolPlugin {
                    func createBuildCommands(
                        context: PluginContext,
                        target: Target
                    ) throws -> [Command] {
                        var unused: Int
                        return []
                    }
                }
                """)

            // Try to compile the fixed plugin.
            let firstExecModTime: Date
            do {
                let delegate = Delegate()
                let result = try await pluginScriptRunner.compilePluginScript(
                    sourceFiles: buildToolPlugin.sources.paths,
                    pluginName: buildToolPlugin.name,
                    toolsVersion: buildToolPlugin.apiVersion,
                    observabilityScope: observability.topScope,
                    callbackQueue: DispatchQueue.sharedConcurrent,
                    delegate: delegate
                )

                // This should invoke the compiler and this time should succeed.
                #expect(result.succeeded == true)
                #expect(result.cached == false)
                #expect(result.commandLine.contains(result.executableFile.pathString), "\(result.commandLine)")
                #expect(result.executableFile.components.contains("plugin-cache"), "\(result.executableFile.pathString)")
                #expect(result.compilerOutput.contains("warning: variable 'unused' was never used"), "\(result.compilerOutput)")
                #expect(result.diagnosticsFile.suffix == ".dia", "\(result.diagnosticsFile.pathString)")

                // Check the delegate callbacks.
                #expect(delegate.commandLine == result.commandLine)
                #expect(delegate.environment != nil)
                #expect(delegate.compiledResult == result)
                #expect(delegate.cachedResult == nil)

                if try UserToolchain.default.supportsSerializedDiagnostics() {
                    // Check the serialized diagnostics. We should no longer have an error but now have a warning.
                    let diaFileContents = try localFileSystem.readFileContents(result.diagnosticsFile)
                    let diagnosticsSet = try SerializedDiagnostics(bytes: diaFileContents)
                    let hasExpectedDiagnosticsCount = diagnosticsSet.diagnostics.count == 1
                    let warningDiagnosticText = diagnosticsSet.diagnostics.first?.text ?? ""
                    let hasExpectedWarningText = warningDiagnosticText.hasPrefix("variable \'unused\' was never used")
                    if hasExpectedDiagnosticsCount && hasExpectedWarningText {
                        #expect(hasExpectedDiagnosticsCount, "unexpected diagnostics count in \(diagnosticsSet.diagnostics) from \(result.diagnosticsFile.pathString)")
                        #expect(hasExpectedWarningText, "\(warningDiagnosticText)")
                    } else {
                        print("bytes of serialized diagnostics file `\(result.diagnosticsFile.pathString)`: \(diaFileContents.contents)")
                        try #require(Bool(false), "failed because of unknown serialized diagnostics issue")
                    }
                }

                // Check that the executable file exists.
                #expect(localFileSystem.exists(result.executableFile), "\(result.executableFile.pathString)")

                // Capture the timestamp of the executable so we can compare it later.
                firstExecModTime = try localFileSystem.getFileInfo(result.executableFile).modTime
            }

            // Recompile the command plugin again without changing its source code.
            let secondExecModTime: Date
            do {
                let delegate = Delegate()
                let result = try await pluginScriptRunner.compilePluginScript(
                    sourceFiles: buildToolPlugin.sources.paths,
                    pluginName: buildToolPlugin.name,
                    toolsVersion: buildToolPlugin.apiVersion,
                    observabilityScope: observability.topScope,
                    callbackQueue: DispatchQueue.sharedConcurrent,
                    delegate: delegate
                )

                // This should not invoke the compiler (just reuse the cached executable).
                #expect(result.succeeded == true)
                #expect(result.cached == true)
                #expect(result.commandLine.contains(result.executableFile.pathString), "\(result.commandLine)")
                #expect(result.executableFile.components.contains("plugin-cache"), "\(result.executableFile.pathString)")
                #expect(result.compilerOutput.contains("warning: variable 'unused' was never used"), "\(result.compilerOutput)")
                #expect(result.diagnosticsFile.suffix == ".dia", "\(result.diagnosticsFile.pathString)")

                // Check the delegate callbacks. Note that the nil command line and environment indicates that we didn't get the callback saying that compilation will start; this is expected when the cache is reused. This is a behaviour of our test delegate. The command line is available in the cached result.
                #expect(delegate.commandLine == nil)
                #expect(delegate.environment == nil)
                #expect(delegate.compiledResult == nil)
                #expect(delegate.cachedResult == result)

                if try UserToolchain.default.supportsSerializedDiagnostics() {
                    // Check that the diagnostics still have the same warning as before.
                    let diaFileContents = try localFileSystem.readFileContents(result.diagnosticsFile)
                    let diagnosticsSet = try SerializedDiagnostics(bytes: diaFileContents)
                    #expect(diagnosticsSet.diagnostics.count == 1)
                    let warningDiagnostic = try #require(diagnosticsSet.diagnostics.first)
                    #expect(warningDiagnostic.text.hasPrefix("variable \'unused\' was never used"), "\(warningDiagnostic)")
                }

                // Check that the executable file exists.
                #expect(localFileSystem.exists(result.executableFile), "\(result.executableFile.pathString)")

                // Check that the timestamp hasn't changed (at least a mild indication that it wasn't recompiled).
                secondExecModTime = try localFileSystem.getFileInfo(result.executableFile).modTime
                #expect(secondExecModTime == firstExecModTime, "firstExecModTime: \(firstExecModTime), secondExecModTime: \(secondExecModTime)")
            }

            // Now replace the plugin script source with syntactically valid contents that no longer produces a warning.
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: """
                import PackagePlugin
                @main struct MyBuildToolPlugin: BuildToolPlugin {
                    func createBuildCommands(
                        context: PluginContext,
                        target: Target
                    ) throws -> [Command] {
                        return []
                    }
                }
                """)

            // NTFS does not have nanosecond granularity (nor is this is a guaranteed file
            // system feature on all file systems). Add a sleep before the execution to ensure that we have sufficient
            // precision to read a difference.
            try await Task.sleep(nanoseconds: UInt64(SendableTimeInterval.seconds(1).nanoseconds()!))

            // Recompile the plugin again.
            let thirdExecModTime: Date
            do {
                let delegate = Delegate()
                let result = try await pluginScriptRunner.compilePluginScript(
                    sourceFiles: buildToolPlugin.sources.paths,
                    pluginName: buildToolPlugin.name,
                    toolsVersion: buildToolPlugin.apiVersion,
                    observabilityScope: observability.topScope,
                    callbackQueue: DispatchQueue.sharedConcurrent,
                    delegate: delegate
                )

                // This should invoke the compiler and not use the cache.
                #expect(result.succeeded == true)
                #expect(result.cached == false)
                #expect(result.commandLine.contains(result.executableFile.pathString), "\(result.commandLine)")
                #expect(result.executableFile.components.contains("plugin-cache"), "\(result.executableFile.pathString)")
                #expect(!result.compilerOutput.contains("warning:"), "\(result.compilerOutput)")
                #expect(result.diagnosticsFile.suffix == ".dia", "\(result.diagnosticsFile.pathString)")

                // Check the delegate callbacks.
                #expect(delegate.commandLine == result.commandLine)
                #expect(delegate.environment != nil)
                #expect(delegate.compiledResult == result)
                #expect(delegate.cachedResult == nil)

                // Check that the diagnostics no longer have a warning.
                let diaFileContents = try localFileSystem.readFileContents(result.diagnosticsFile)
                let diagnosticsSet = try SerializedDiagnostics(bytes: diaFileContents)
                #expect(diagnosticsSet.diagnostics.count == 0)

                // Check that the executable file exists.
                #expect(localFileSystem.exists(result.executableFile), "\(result.executableFile.pathString)")

                // Check that the timestamp has changed (at least a mild indication that it was recompiled).
                thirdExecModTime = try localFileSystem.getFileInfo(result.executableFile).modTime
                #expect(thirdExecModTime != firstExecModTime, "thirdExecModTime: \(thirdExecModTime), firstExecModTime: \(firstExecModTime)")
                #expect(thirdExecModTime != secondExecModTime, "thirdExecModTime: \(thirdExecModTime), secondExecModTime: \(secondExecModTime)")
            }

            // Now replace the plugin script source with a broken one again.
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: """
                import PackagePlugin
                @main struct MyBuildToolPlugin: BuildToolPlugin {
                    func createBuildCommands(
                        context: PluginContext,
                        target: Target
                    ) throws -> [Command] {
                        return nil  // returning the wrong type
                    }
                }
                """)

            // Recompile the plugin again.
            do {
                let delegate = Delegate()
                let result = try await pluginScriptRunner.compilePluginScript(
                    sourceFiles: buildToolPlugin.sources.paths,
                    pluginName: buildToolPlugin.name,
                    toolsVersion: buildToolPlugin.apiVersion,
                    observabilityScope: observability.topScope,
                    callbackQueue: DispatchQueue.sharedConcurrent,
                    delegate: delegate
                )

                // This should again invoke the compiler but should fail.
                #expect(result.succeeded == false)
                #expect(result.cached == false)
                #expect(result.commandLine.contains(result.executableFile.pathString), "\(result.commandLine)")
                #expect(result.executableFile.components.contains("plugin-cache"), "\(result.executableFile.pathString)")
                #expect(result.compilerOutput.contains("error: 'nil' is incompatible with return type"), "\(result.compilerOutput)")
                #expect(result.diagnosticsFile.suffix == ".dia", "\(result.diagnosticsFile.pathString)")

                // Check the delegate callbacks.
                #expect(delegate.commandLine == result.commandLine)
                #expect(delegate.environment != nil)
                #expect(delegate.compiledResult == result)
                #expect(delegate.cachedResult == nil)

                // Check the diagnostics. We should have a different error than the original one.
                let diaFileContents = try localFileSystem.readFileContents(result.diagnosticsFile)
                let diagnosticsSet = try SerializedDiagnostics(bytes: diaFileContents)
                #expect(diagnosticsSet.diagnostics.count == 1)
                let errorDiagnostic = try #require(diagnosticsSet.diagnostics.first)
                #expect(errorDiagnostic.text.hasPrefix("'nil' is incompatible with return type"), "\(errorDiagnostic)")

                // Check that the executable file no longer exists.
                #expect(!localFileSystem.exists(result.executableFile), "\(result.executableFile.pathString)")
            }
        }
    }

    @Test(
        .disabled(if: !UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
    )
    func unsupportedDependencyProduct() async throws {        
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library product and a plugin.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(packageDir.appending("Package.swift"), string: """
            // swift-tools-version: 5.7
            import PackageDescription
            let package = Package(
                name: "MyPackage",
                dependencies: [
                  .package(path: "../FooPackage"),
                ],
                targets: [
                    .plugin(
                        name: "MyPlugin",
                        capability: .buildTool(),
                        dependencies: [
                            .product(name: "FooLib", package: "FooPackage"),
                        ]
                    ),
                ]
            )
            """)

            let myPluginTargetDir = packageDir.appending(components: "Plugins", "MyPlugin")
            try localFileSystem.createDirectory(myPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: """
                  import PackagePlugin
                  import Foo
                  @main struct MyBuildToolPlugin: BuildToolPlugin {
                      func createBuildCommands(
                          context: PluginContext,
                          target: Target
                      ) throws -> [Command] { }
                  }
                  """)

            let fooPkgDir = tmpPath.appending(components: "FooPackage")
            try localFileSystem.createDirectory(fooPkgDir, recursive: true)
            try localFileSystem.writeFileContents(fooPkgDir.appending("Package.swift"), string: """
                // swift-tools-version: 5.7
                import PackageDescription
                let package = Package(
                    name: "FooPackage",
                    products: [
                        .library(name: "FooLib",
                                 targets: ["Foo"]),
                    ],
                    targets: [
                        .target(
                            name: "Foo",
                            dependencies: []
                        ),
                    ]
                )
                """)
            let fooTargetDir = fooPkgDir.appending(components: "Sources", "Foo")
            try localFileSystem.createDirectory(fooTargetDir, recursive: true)
            try localFileSystem.writeFileContents(fooTargetDir.appending("file.swift"), string: """
                  public func foo() { }
                  """)

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            #expect(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            await #expect {
                try await workspace.loadPackageGraph(
                    rootInput: rootInput,
                    observabilityScope: observability.topScope
                )
            } throws: { error in
                var diagnosed = false
                if let realError = error as? PackageGraphError,
                   realError.description == "plugin 'MyPlugin' cannot depend on 'FooLib' of type 'library' from package 'foopackage'; this dependency is unsupported" {
                    diagnosed = true
                }
                #expect(diagnosed)
            }
        }
    }

    @Test(
        // .disabled(if: !UserToolchain.default.supportsSwiftConcurrency(), "skipping because test environment doesn't support concurrency")
        // .requiresConcurrencySupport
        .foo
    )
    func unsupportedDependencyTarget() async throws {
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library target and a plugin.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(packageDir.appending("Package.swift"), string: """
                // swift-tools-version: 5.7
                import PackageDescription
                let package = Package(
                    name: "MyPackage",
                    targets: [
                        .target(
                            name: "MyLibrary",
                            dependencies: []
                        ),
                        .plugin(
                            name: "MyPlugin",
                            capability: .buildTool(),
                            dependencies: [
                                "MyLibrary"
                            ]
                        ),
                    ]
                )
                """)

            let myLibraryTargetDir = packageDir.appending(components: "Sources", "MyLibrary")
            try localFileSystem.createDirectory(myLibraryTargetDir, recursive: true)
            try localFileSystem.writeFileContents(myLibraryTargetDir.appending("library.swift"), string: """
                    public func hello() { }
                    """)
            let myPluginTargetDir = packageDir.appending(components: "Plugins", "MyPlugin")
            try localFileSystem.createDirectory(myPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: """
                  import PackagePlugin
                  import MyLibrary
                  @main struct MyBuildToolPlugin: BuildToolPlugin {
                      func createBuildCommands(
                          context: PluginContext,
                          target: Target
                      ) throws -> [Command] { }
                  }
                  """)

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            #expect(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            await #expect {
                try await workspace.loadPackageGraph(
                   rootInput: rootInput,
                    observabilityScope: observability.topScope
            ) } throws: { error in
                var diagnosed = false
                if let realError = error as? PackageGraphError,
                   realError.description == "plugin 'MyPlugin' cannot depend on 'MyLibrary' of type 'library'; this dependency is unsupported" {
                    diagnosed = true
                }
                #expect(diagnosed)
            }
        }
    }

    @Test(
        .requiresConcurrencySupport
    )
    func prebuildPluginShouldNotUseExecTarget() async throws {
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library target and a plugin.
            let packageDir = tmpPath.appending(components: "mypkg")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(packageDir.appending("Package.swift"), string: """
                // swift-tools-version:5.7

                import PackageDescription

                let package = Package(
                    name: "mypkg",
                    products: [
                        .library(
                            name: "MyLib",
                            targets: ["MyLib"])
                    ],
                    targets: [
                        .target(
                            name: "MyLib",
                            plugins: [
                                .plugin(name: "X")
                            ]),
                        .plugin(
                            name: "X",
                            capability: .buildTool(),
                            dependencies: [ "Y" ]
                        ),
                        .executableTarget(
                            name: "Y",
                            dependencies: []),
                    ]
                )
                """)

            let libTargetDir = packageDir.appending(components: "Sources", "MyLib")
            try localFileSystem.createDirectory(libTargetDir, recursive: true)
            try localFileSystem.writeFileContents(libTargetDir.appending("file.swift"), string: """
                public struct MyUtilLib {
                    public let strings: [String]
                    public init(args: [String]) {
                        self.strings = args
                    }
                }
            """)

            let depTargetDir = packageDir.appending(components: "Sources", "Y")
            try localFileSystem.createDirectory(depTargetDir, recursive: true)
            try localFileSystem.writeFileContents(depTargetDir.appending("main.swift"), string: """
                struct Y {
                    func run() {
                        print("You passed us two arguments, argumentOne, and argumentTwo")
                    }
                }
                Y.main()
            """)

            let pluginTargetDir = packageDir.appending(components: "Plugins", "X")
            try localFileSystem.createDirectory(pluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(pluginTargetDir.appending("plugin.swift"), string: """
                  import PackagePlugin
                  @main struct X: BuildToolPlugin {
                      func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
                          [
                              Command.prebuildCommand(
                                  displayName: "X: Running Y before the build...",
                                  executable: try context.tool(named: "Y").path,
                                  arguments: [ "ARGUMENT_ONE", "ARGUMENT_TWO" ],
                                  outputFilesDirectory: context.pluginWorkDirectory.appending("OUTPUT_FILES_DIRECTORY")
                              )
                          ]
                      }
                  }
                  """)

            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            #expect(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            try requireNoDiagnostics(observability.diagnostics)
            #expect(packageGraph.packages.count == 1, "\(packageGraph.packages)")

            // Find the build tool plugin.
            let buildToolPlugin = try #require(packageGraph.packages.first?.modules.map(\.underlying).filter{ $0.name == "X" }.first as? PluginModule)
            #expect(buildToolPlugin.name == "X")
            #expect(buildToolPlugin.capability == .buildTool)

            // Create a plugin script runner for the duration of the test.
            let pluginCacheDir = tmpPath.appending("plugin-cache")
            let pluginScriptRunner = DefaultPluginScriptRunner(
                fileSystem: localFileSystem,
                cacheDir: pluginCacheDir,
                toolchain: try UserToolchain.default
            )

            // Invoke build tool plugin
            do {
                let outputDir = packageDir.appending(".build")
                let buildParameters = mockBuildParameters(
                    destination: .host,
                    environment: BuildEnvironment(platform: .macOS, configuration: .debug)
                )

                let result = try await invokeBuildToolPlugins(
                    graph: packageGraph,
                    buildParameters: buildParameters,
                    fileSystem: localFileSystem,
                    outputDir: outputDir,
                    pluginScriptRunner: pluginScriptRunner,
                    observabilityScope: observability.topScope
                )

                let diags = result.flatMap(\.value.results).flatMap(\.diagnostics)
                testDiagnostics(diags) { result in
                    let msg = "a prebuild command cannot use executables built from source, including executable target 'Y'"
                    result.check(diagnostic: .contains(msg), severity: .error)
                }
            }
        }
    }

    @Test(
        .requiresConcurrencySupport
    )
    func scanImportsInPluginTargets() async throws {
        try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library target and a plugin.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(packageDir.appending("Package.swift"), string: """
                // swift-tools-version: 5.7
                import PackageDescription
                let package = Package(
                    name: "MyPackage",
                    dependencies: [
                      .package(path: "../OtherPackage"),
                    ],
                    targets: [
                        .target(
                            name: "MyLibrary",
                            dependencies: [.product(name: "OtherPlugin", package: "OtherPackage")]
                        ),
                        .plugin(
                            name: "XPlugin",
                            capability: .buildTool()
                        ),
                        .plugin(
                            name: "YPlugin",
                            capability: .command(
                               intent: .custom(verb: "YPlugin", description: "Plugin example"),
                               permissions: []
                            )
                        )
                    ]
                )
                """)

            let myLibraryTargetDir = packageDir.appending(components: "Sources", "MyLibrary")
            try localFileSystem.createDirectory(myLibraryTargetDir, recursive: true)
            try localFileSystem.writeFileContents(myLibraryTargetDir.appending("library.swift"), string: """
                    public func hello() { }
                    """)
            let xPluginTargetDir = packageDir.appending(components: "Plugins", "XPlugin")
            try localFileSystem.createDirectory(xPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(xPluginTargetDir.appending("plugin.swift"), string: """
                  import PackagePlugin
                  import XcodeProjectPlugin
                  @main struct XBuildToolPlugin: BuildToolPlugin {
                      func createBuildCommands(
                          context: PluginContext,
                          target: Target
                      ) throws -> [Command] { }
                  }
                  """)
            let yPluginTargetDir = packageDir.appending(components: "Plugins", "YPlugin")
            try localFileSystem.createDirectory(yPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(yPluginTargetDir.appending("plugin.swift"), string: """
                     import PackagePlugin
                     import Foundation
                     @main struct YPlugin: BuildToolPlugin {
                         func createBuildCommands(
                             context: PluginContext,
                             target: Target
                         ) throws -> [Command] { }
                     }
                     """)


            //////

            let otherPackageDir = tmpPath.appending(components: "OtherPackage")
            try localFileSystem.createDirectory(otherPackageDir, recursive: true)
            try localFileSystem.writeFileContents(otherPackageDir.appending("Package.swift"), string: """
                // swift-tools-version: 5.7
                import PackageDescription
                let package = Package(
                    name: "OtherPackage",
                    products: [
                        .plugin(
                            name: "OtherPlugin",
                            targets: ["QPlugin"])
                    ],
                    targets: [
                        .plugin(
                            name: "QPlugin",
                            capability: .buildTool()
                        ),
                        .plugin(
                            name: "RPlugin",
                            capability: .command(
                               intent: .custom(verb: "RPlugin", description: "Plugin example"),
                               permissions: []
                            )
                        )
                    ]
                )
                """)

            let qPluginTargetDir = otherPackageDir.appending(components: "Plugins", "QPlugin")
            try localFileSystem.createDirectory(qPluginTargetDir, recursive: true)
            try localFileSystem.writeFileContents(qPluginTargetDir.appending("plugin.swift"), string: """
                  import PackagePlugin
                  import XcodeProjectPlugin
                  #if canImport(ModuleFoundViaExtraSearchPaths)
                  import ModuleFoundViaExtraSearchPaths
                  #endif
                  @main struct QBuildToolPlugin: BuildToolPlugin {
                      func createBuildCommands(
                          context: PluginContext,
                          target: Target
                      ) throws -> [Command] { }
                  }
                  """)

            // Create a valid swift interface file that can be detected via `canImport()`.
            let fakeExtraModulesDir = tmpPath.appending("ExtraModules")
            try localFileSystem.createDirectory(fakeExtraModulesDir, recursive: true)
            let fakeExtraModuleFile = fakeExtraModulesDir.appending("ModuleFoundViaExtraSearchPaths.swiftinterface")
            try localFileSystem.writeFileContents(fakeExtraModuleFile, string: """
                  // swift-interface-format-version: 1.0
                  // swift-module-flags: -module-name ModuleFoundViaExtraSearchPaths
                  """)

            /////////
            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let environment = Environment.current
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                location: try Workspace.Location(forRootPackage: packageDir, fileSystem: localFileSystem),
                customHostToolchain: UserToolchain(
                    swiftSDK: .hostSwiftSDK(
                        environment: environment
                    ),
                    environment: environment,
                    customLibrariesLocation: .init(manifestLibraryPath: fakeExtraModulesDir, pluginLibraryPath: fakeExtraModulesDir)
                ),
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            #expect(rootManifests.count == 1, "\(rootManifests)")

            let graph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            let dict = try await workspace.loadPluginImports(packageGraph: graph)

            var count = 0
            for (pkg, entry) in dict {
                if pkg.description == "mypackage" {
                    #expect(entry["XPlugin"] != nil)
                    let XPluginPossibleImports1 = ["PackagePlugin", "XcodeProjectPlugin"]
                    let XPluginPossibleImports2 = ["PackagePlugin", "XcodeProjectPlugin", "_SwiftConcurrencyShims"]
                    #expect(entry["XPlugin"] == XPluginPossibleImports1 ||
                            entry["XPlugin"] == XPluginPossibleImports2)

                    let YPluginPossibleImports1 = ["PackagePlugin", "Foundation"]
                    let YPluginPossibleImports2 = ["PackagePlugin", "Foundation", "_SwiftConcurrencyShims"]
                    #expect(entry["YPlugin"] == YPluginPossibleImports1 ||
                            entry["YPlugin"] == YPluginPossibleImports2)
                    count += 1
                } else if pkg.description == "otherpackage" {
                    #expect(dict[pkg]?["QPlugin"] != nil)

                    let possibleImports1 = ["PackagePlugin", "XcodeProjectPlugin", "ModuleFoundViaExtraSearchPaths"]
                    let possibleImports2 = ["PackagePlugin", "XcodeProjectPlugin", "ModuleFoundViaExtraSearchPaths", "_SwiftConcurrencyShims"]
                    #expect(entry["QPlugin"] == possibleImports1 ||
                            entry["QPlugin"] == possibleImports2)
                    count += 1
                }
            }

            #expect(count == 2)
        }
    }

    func checkParseArtifactsPlatformCompatibility(
        artifactSupportedTriples: [Triple],
        hostTriple: Triple
    ) async throws -> [ResolvedModule.ID: [BuildToolPluginInvocationResult]]  {
        // Any test that call this required needs to support Swift concurrency (which the plugin APIs require).

        return try await testWithTemporaryDirectory { tmpPath in
            // Create a sample package with a library target and a plugin.
            let packageDir = tmpPath.appending(components: "MyPackage")
            try localFileSystem.createDirectory(packageDir, recursive: true)
            try localFileSystem.writeFileContents(packageDir.appending("Package.swift"), string: """
                   // swift-tools-version: 5.7
                   import PackageDescription
                   let package = Package(
                       name: "MyPackage",
                       dependencies: [
                       ],
                       targets: [
                           .target(
                               name: "MyLibrary",
                               plugins: [
                                   "Foo",
                               ]
                           ),
                           .plugin(
                               name: "Foo",
                               capability: .buildTool(),
                               dependencies: [
                                   .target(name: "LocalBinaryTool"),
                               ]
                            ),
                           .binaryTarget(
                               name: "LocalBinaryTool",
                               path: "Binaries/LocalBinaryTool.\(artifactBundleExtension)"
                           ),
                        ]
                   )
                   """)

            let libDir = packageDir.appending(components: "Sources", "MyLibrary")
            try localFileSystem.createDirectory(libDir, recursive: true)
            try localFileSystem.writeFileContents(
                libDir.appending(components: "library.swift"),
                string: """
                public func myLib() { }
                """
            )

            let myPluginTargetDir = packageDir.appending(components: "Plugins", "Foo")
            try localFileSystem.createDirectory(myPluginTargetDir, recursive: true)
            let content = """
                 import PackagePlugin
                 @main struct FooPlugin: BuildToolPlugin {
                     func createBuildCommands(
                         context: PluginContext,
                         target: Target
                     ) throws -> [Command] {
                        print("Looking for LocalBinaryTool...")
                        let localBinaryTool = try context.tool(named: "LocalBinaryTool")
                        print("... found it at \\(localBinaryTool.path)")
                        return [.buildCommand(displayName: "", executable: localBinaryTool.path, arguments: [], inputFiles: [], outputFiles: [])]
                    }
                 }
            """
            try localFileSystem.writeFileContents(myPluginTargetDir.appending("plugin.swift"), string: content)
            let artifactVariants = artifactSupportedTriples.map {
                """
                { "path": "LocalBinaryTool\($0.tripleString).sh", "supportedTriples": ["\($0.tripleString)"] }
                """
            }

            let bundleMetadataPath = packageDir.appending(
                components: "Binaries",
                "LocalBinaryTool.artifactbundle",
                "info.json"
            )
            try localFileSystem.createDirectory(bundleMetadataPath.parentDirectory, recursive: true)
            try localFileSystem.writeFileContents(
                bundleMetadataPath,
                string: """
                {   "schemaVersion": "1.0",
                    "artifacts": {
                        "LocalBinaryTool": {
                            "type": "executable",
                            "version": "1.2.3",
                            "variants": [
                                \(artifactVariants.joined(separator: ","))
                            ]
                        }
                    }
                }
                """
            )
            // Load a workspace from the package.
            let observability = ObservabilitySystem.makeForTesting()
            let workspace = try Workspace(
                fileSystem: localFileSystem,
                forRootPackage: packageDir,
                customManifestLoader: ManifestLoader(toolchain: UserToolchain.default),
                delegate: MockWorkspaceDelegate()
            )

            // Load the root manifest.
            let rootInput = PackageGraphRootInput(packages: [packageDir], dependencies: [])
            let rootManifests = try await workspace.loadRootManifests(
                packages: rootInput.packages,
                observabilityScope: observability.topScope
            )
            #expect(rootManifests.count == 1, "\(rootManifests)")

            // Load the package graph.
            let packageGraph = try await workspace.loadPackageGraph(
                rootInput: rootInput,
                observabilityScope: observability.topScope
            )
            try requireNoDiagnostics(observability.diagnostics)

            // Find the build tool plugin.
            let buildToolPlugin = try #require(packageGraph.packages.first?.modules
                .map(\.underlying)
                .filter { $0.name == "Foo" }
                .first as? PluginModule)
            #expect(buildToolPlugin.name == "Foo")
            #expect(buildToolPlugin.capability == .buildTool)

            // Construct a toolchain with a made-up host/target triple
            let swiftSDK = try SwiftSDK.default
            let toolchain = try UserToolchain(
                swiftSDK: SwiftSDK(
                    hostTriple: hostTriple,
                    targetTriple: hostTriple,
                    toolset: swiftSDK.toolset,
                    pathsConfiguration: swiftSDK.pathsConfiguration
                ),
                environment: .current
            )

            // Create a plugin script runner for the duration of the test.
            let pluginCacheDir = tmpPath.appending("plugin-cache")
            let pluginScriptRunner = DefaultPluginScriptRunner(
                fileSystem: localFileSystem,
                cacheDir: pluginCacheDir,
                toolchain: toolchain
            )

            // Invoke build tool plugin
            let outputDir = packageDir.appending(".build")
            let buildParameters = mockBuildParameters(
                destination: .host,
                environment: BuildEnvironment(platform: .macOS, configuration: .debug)
            )

            return try await invokeBuildToolPlugins(
                graph: packageGraph,
                buildParameters: buildParameters,
                fileSystem: localFileSystem,
                outputDir: outputDir,
                pluginScriptRunner: pluginScriptRunner,
                observabilityScope: observability.topScope
            ).mapValues(\.results)
        }
    }

    @Test(
        .requiresConcurrencySupport
    )
    func parseArtifactNotSupportedOnTargetPlatform() async throws {
        let hostTriple = try UserToolchain.default.targetTriple
        let artifactSupportedTriples = try [Triple("riscv64-apple-windows-android")]

        var checked = false
        let result = try await self.checkParseArtifactsPlatformCompatibility(artifactSupportedTriples: artifactSupportedTriples, hostTriple: hostTriple)
        if let pluginResult = result.first,
           let diag = pluginResult.value.first?.diagnostics,
           diag.description == "[[error]: Tool ‘LocalBinaryTool’ is not supported on the target platform]" {
            checked = true
        }
        #expect(checked)
    }

    @Test(
        .disabled(if: !isMacOS(), "platform versions are only available if the host is macOS")
    )
    func parseArtifactsDoesNotCheckPlatformVersion() async throws {
        let hostTriple = try UserToolchain.default.targetTriple
        let artifactSupportedTriples = try [Triple("\(hostTriple.withoutVersion().tripleString)20.0")]

        let result = try await self.checkParseArtifactsPlatformCompatibility(artifactSupportedTriples: artifactSupportedTriples, hostTriple: hostTriple)
        result.forEach {
            $0.value.forEach {
                #expect($0.succeeded, "plugin unexpectedly failed")
                #expect($0.diagnostics.map { $0.message } == [])
            }
        }
    }

    @Test(
        .requiresConcurrencySupport
    )
    func parseArtifactsConsidersAllSupportedTriples() async throws {
        let hostTriple = try UserToolchain.default.targetTriple
        let artifactSupportedTriples = [hostTriple, try Triple("riscv64-apple-windows-android")]

        let result = try await self.checkParseArtifactsPlatformCompatibility(artifactSupportedTriples: artifactSupportedTriples, hostTriple: hostTriple)
        result.forEach {
            $0.value.forEach {
                #expect($0.succeeded, "plugin unexpectedly failed")
                #expect($0.diagnostics.map { $0.message } == [])
                #expect($0.buildCommands.first?.configuration.executable.basename == "LocalBinaryTool\(hostTriple.tripleString).sh")
            }
        }
    }

    private func invokeBuildToolPlugins(
        graph: ModulesGraph,
        buildParameters: BuildParameters,
        fileSystem: any FileSystem,
        outputDir: AbsolutePath,
        pluginScriptRunner: PluginScriptRunner,
        observabilityScope: ObservabilityScope
    ) async throws -> [ResolvedModule.ID: (target: ResolvedModule, results: [BuildToolPluginInvocationResult])] {
        let pluginsPerModule = graph.pluginsPerModule(
            satisfying: buildParameters.buildEnvironment
        )

        let plugins = pluginsPerModule.values.reduce(into: IdentifiableSet<ResolvedModule>()) { result, plugins in
            plugins.forEach { result.insert($0) }
        }

        var pluginInvocationResults: [ResolvedModule.ID: (
            target: ResolvedModule,
            results: [BuildToolPluginInvocationResult]
        )] = [:]

        let pluginConfiguration = PluginConfiguration(
            scriptRunner: pluginScriptRunner,
            workDirectory: outputDir.parentDirectory,
            disableSandbox: false
        )

        for (moduleID, _) in pluginsPerModule {
            let module = graph.allModules[moduleID]!

            let results = try await BuildPlan.invokeBuildToolPlugins(
                for: module,
                destination: .target,
                configuration: pluginConfiguration,
                buildParameters: buildParameters,
                modulesGraph: graph,
                tools: mockPluginTools(
                    plugins: plugins,
                    fileSystem: fileSystem,
                    buildParameters: buildParameters,
                    hostTriple: hostTriple
                ),
                additionalFileRules: [],
                pkgConfigDirectories: [],
                fileSystem: fileSystem,
                observabilityScope: observabilityScope
            )

            pluginInvocationResults[moduleID] = (target: module, results: results)
        }

        return pluginInvocationResults
    }
}

extension BuildPlanResult {
    func check(
        destination: BuildParameters.Destination,
        for target: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let targets = self.targetMap.filter {
            $0.module.name == target && $0.destination == destination
        }
        #expect(targets.count == 1)
    }    
}
