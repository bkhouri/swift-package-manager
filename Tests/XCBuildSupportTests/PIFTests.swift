//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

import Testing
import Basics
import PackageModel
import SPMBuildCore
import XCBuildSupport
import _InternalTestSupport

import enum TSCBasic.JSON

struct PIFTests {
    let topLevelObject = PIF.TopLevelObject(workspace:
        PIF.Workspace(
            guid: "workspace",
            name: "MyWorkspace",
            path: "/path/to/workspace",
            projects: [
                PIF.Project(
                    guid: "project",
                    name: "MyProject",
                    path: "/path/to/workspace/project",
                    projectDirectory: "/path/to/workspace/project",
                    developmentRegion: "fr",
                    buildConfigurations: [
                        PIF.BuildConfiguration(
                            guid: "project-config-debug-guid",
                            name: "Debug",
                            buildSettings: {
                                var settings = PIF.BuildSettings()
                                settings[.PRODUCT_NAME] = "$(TARGET_NAME)"
                                settings[.SUPPORTED_PLATFORMS] = ["$(AVAILABLE_PLATFORMS)"]
                                return settings
                            }()
                        ),
                        PIF.BuildConfiguration(
                            guid: "project-config-release-guid",
                            name: "Release",
                            buildSettings: {
                                var settings = PIF.BuildSettings()
                                settings[.PRODUCT_NAME] = "$(TARGET_NAME)"
                                settings[.SUPPORTED_PLATFORMS] = ["$(AVAILABLE_PLATFORMS)"]
                                settings[.GCC_OPTIMIZATION_LEVEL] = "s"
                                return settings
                            }()
                        ),
                    ],
                    targets: [
                        PIF.Target(
                            guid: "target-exe-guid",
                            name: "MyExecutable",
                            productType: .executable,
                            productName: "MyExecutable",
                            buildConfigurations: [
                                PIF.BuildConfiguration(
                                    guid: "target-exe-config-debug-guid",
                                    name: "Debug",
                                    buildSettings: {
                                        var settings = PIF.BuildSettings()
                                        settings[.TARGET_NAME] = "MyExecutable"
                                        return settings
                                    }()
                                ),
                                PIF.BuildConfiguration(
                                    guid: "target-exe-config-release-guid",
                                    name: "Release",
                                    buildSettings: {
                                        var settings = PIF.BuildSettings()
                                        settings[.TARGET_NAME] = "MyExecutable"
                                        settings[.SKIP_INSTALL] = "NO"
                                        return settings
                                    }()
                                ),
                            ],
                            buildPhases: [
                                PIF.SourcesBuildPhase(
                                    guid: "target-exe-sources-build-phase-guid",
                                    buildFiles: [
                                        PIF.BuildFile(
                                            guid: "target-exe-sources-build-file-guid",
                                            fileGUID: "exe-file-guid",
                                            platformFilters: []
                                        )
                                    ]
                                ),
                                PIF.FrameworksBuildPhase(
                                    guid: "target-exe-frameworks-build-phase-guid",
                                    buildFiles: [
                                        PIF.BuildFile(
                                            guid: "target-exe-frameworks-build-file-guid",
                                            targetGUID: "target-lib-guid",
                                            platformFilters: []
                                        )
                                    ]
                                ),
                                PIF.HeadersBuildPhase(
                                    guid: "target-exe-headers-build-phase-guid",
                                    buildFiles: [
                                        PIF.BuildFile(
                                            guid: "target-exe-headers-build-file-guid",
                                            targetGUID: "target-lib-guid",
                                            platformFilters: [],
                                            headerVisibility: .public
                                        )
                                    ]
                                )
                            ],
                            dependencies: [
                                .init(targetGUID: "target-lib-guid")
                            ],
                            impartedBuildSettings: PIF.BuildSettings()
                        ),
                        PIF.Target(
                            guid: "target-lib-guid",
                            name: "MyLibrary",
                            productType: .objectFile,
                            productName: "MyLibrary",
                            buildConfigurations: [
                                PIF.BuildConfiguration(
                                    guid: "target-lib-config-debug-guid",
                                    name: "Debug",
                                    buildSettings: {
                                        var settings = PIF.BuildSettings()
                                        settings[.TARGET_NAME] = "MyLibrary-Debug"
                                        return settings
                                    }(),
                                    impartedBuildProperties: {
                                        var settings = PIF.BuildSettings()
                                        settings[.OTHER_CFLAGS] = ["-fmodule-map-file=modulemap", "$(inherited)"]
                                        return PIF.ImpartedBuildProperties(settings: settings)
                                    }()
                                ),
                                PIF.BuildConfiguration(
                                    guid: "target-lib-config-release-guid",
                                    name: "Release",
                                    buildSettings: {
                                        var settings = PIF.BuildSettings()
                                        settings[.TARGET_NAME] = "MyLibrary"
                                        return settings
                                    }(),
                                    impartedBuildProperties: {
                                        var settings = PIF.BuildSettings()
                                        settings[.OTHER_CFLAGS] = ["-fmodule-map-file=modulemap", "$(inherited)"]
                                        return PIF.ImpartedBuildProperties(settings: settings)
                                    }()
                                ),
                            ],
                            buildPhases: [
                                PIF.SourcesBuildPhase(
                                    guid: "target-lib-sources-build-phase-guid",
                                    buildFiles: [
                                        PIF.BuildFile(
                                            guid: "target-lib-sources-build-file-guid",
                                            fileGUID: "lib-file-guid",
                                            platformFilters: []
                                        )
                                    ]
                                )
                            ],
                            dependencies: [],
                            impartedBuildSettings: PIF.BuildSettings()
                        ),
                        PIF.AggregateTarget(
                            guid: "aggregate-target-guid",
                            name: "AggregateLibrary",
                            buildConfigurations: [
                                PIF.BuildConfiguration(
                                    guid: "aggregate-target-config-debug-guid",
                                    name: "Debug",
                                    buildSettings: PIF.BuildSettings(),
                                    impartedBuildProperties: {
                                        var settings = PIF.BuildSettings()
                                        settings[.OTHER_CFLAGS] = ["-fmodule-map-file=modulemap", "$(inherited)"]
                                        return PIF.ImpartedBuildProperties(settings: settings)
                                    }()
                                ),
                                PIF.BuildConfiguration(
                                    guid: "aggregate-target-config-release-guid",
                                    name: "Release",
                                    buildSettings: PIF.BuildSettings(),
                                    impartedBuildProperties: {
                                        var settings = PIF.BuildSettings()
                                        settings[.OTHER_CFLAGS] = ["-fmodule-map-file=modulemap", "$(inherited)"]
                                        return PIF.ImpartedBuildProperties(settings: settings)
                                    }()
                                ),
                            ],
                            buildPhases: [],
                            dependencies: [
                                .init(targetGUID: "target-lib-guid"),
                                .init(targetGUID: "target-exe-guid"),
                            ],
                            impartedBuildSettings: PIF.BuildSettings()
                        )
                    ],
                    groupTree: PIF.Group(guid: "main-group-guid", path: "", children: [
                        PIF.FileReference(guid: "exe-file-guid", path: "main.swift"),
                        PIF.FileReference(guid: "lib-file-guid", path: "lib.swift"),
                    ])
                )
            ]
        )
    )

    @Test
    func roundTrip() throws {
        let encoder = JSONEncoder.makeWithDefaults()
        if #available(macOS 10.13, *) {
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        }

        let workspace = topLevelObject.workspace
        let encodedData = try encoder.encode(workspace)
        let decodedWorkspace = try JSONDecoder.makeWithDefaults().decode(PIF.Workspace.self, from: encodedData)

        let originalPIF = try encoder.encode(workspace)
        let decodedPIF = try encoder.encode(decodedWorkspace)

        let originalString = String(decoding: originalPIF, as: UTF8.self)
        let decodedString = String(decoding: decodedPIF, as: UTF8.self)

        #expect(originalString == decodedString)
    }

    @Test
    func encodable() throws {
        let encoder = JSONEncoder.makeWithDefaults()
        encoder.userInfo[.encodeForXCBuild] = true
        try PIF.sign(topLevelObject.workspace)
        let data = try encoder.encode(topLevelObject)
        let json = try JSON(data: data)

        guard case .array(let objects) = json else {
            Issue.record("invalid json type")
            return
        }

        try #require(objects.count == 5, "invalid number of objects")

        let workspace = objects[0]
        let workspaceContents = try #require(workspace["contents"], "missing workspace contents")
        // guard let workspaceContents = workspace["contents"] else {
        //     Issue.record("missing workspace contents")
        //     return
        // }

        let project = objects[1]
        guard let projectContents = project["contents"] else {
            Issue.record("missing project contents")
            return
        }

        let exeTarget = objects[2]
        guard let exeTargetContents = exeTarget["contents"] else {
            Issue.record("missing exe target contents")
            return
        }

        let libTarget = objects[3]
        guard let libTargetContents = libTarget["contents"] else {
            Issue.record("missing lib target contents")
            return
        }

        let aggregateTarget = objects[4]
        guard let aggregateTargetContents = aggregateTarget["contents"] else {
            Issue.record("missing aggregate target contents")
            return
        }

        #expect(workspace["type"]?.string == "workspace")
        #expect(workspaceContents["guid"]?.string == "workspace@11")
        #expect(workspaceContents["path"]?.string == AbsolutePath("/path/to/workspace").pathString)
        #expect(workspaceContents["name"]?.string == "MyWorkspace")
        #expect(workspaceContents["projects"]?.array == [project["signature"]!])

        #expect(project["type"]?.string == "project")
        #expect(projectContents["guid"]?.string == "project@11")
        #expect(projectContents["path"]?.string == AbsolutePath("/path/to/workspace/project").pathString)
        #expect(projectContents["projectDirectory"]?.string == AbsolutePath("/path/to/workspace/project").pathString)
        #expect(projectContents["projectName"]?.string == "MyProject")
        #expect(projectContents["projectIsPackage"]?.string == "true")
        #expect(projectContents["developmentRegion"]?.string == "fr")
        #expect(projectContents["defaultConfigurationName"]?.string == "Release")
        #expect(projectContents["targets"]?.array == [
            exeTarget["signature"]!,
            libTarget["signature"]!,
            aggregateTarget["signature"]!,
        ])

        if let configurations = projectContents["buildConfigurations"]?.array, configurations.count == 2 {
            let debugConfiguration = configurations[0]
            #expect(debugConfiguration["guid"]?.string == "project-config-debug-guid")
            #expect(debugConfiguration["name"]?.string == "Debug")
            let debugSettings = debugConfiguration["buildSettings"]
            #expect(debugSettings?["PRODUCT_NAME"]?.string == "$(TARGET_NAME)")
            #expect(debugSettings?["SUPPORTED_PLATFORMS"]?.array == [.string("$(AVAILABLE_PLATFORMS)")])

            let releaseConfiguration = configurations[1]
            #expect(releaseConfiguration["guid"]?.string == "project-config-release-guid")
            #expect(releaseConfiguration["name"]?.string == "Release")
            let releaseSettings = releaseConfiguration["buildSettings"]
            #expect(releaseSettings?["PRODUCT_NAME"]?.string == "$(TARGET_NAME)")
            #expect(releaseSettings?["SUPPORTED_PLATFORMS"]?.array == [.string("$(AVAILABLE_PLATFORMS)")])
        } else {
            Issue.record("invalid number of build configurations")
        }

        if let groupTree = projectContents["groupTree"] {
            #expect(groupTree["guid"]?.string == "main-group-guid")
            #expect(groupTree["sourceTree"]?.string == "<group>")
            #expect(groupTree["path"]?.string == "")
            #expect(groupTree["name"]?.string == "")

            if let children = groupTree["children"]?.array, children.count == 2 {
                let file1 = children[0]
                #expect(file1["guid"]?.string == "exe-file-guid")
                #expect(file1["sourceTree"]?.string == "<group>")
                #expect(file1["path"]?.string == "main.swift")
                #expect(file1["name"]?.string == "main.swift")

                let file2 = children[1]
                #expect(file2["guid"]?.string == "lib-file-guid")
                #expect(file2["sourceTree"]?.string == "<group>")
                #expect(file2["path"]?.string == "lib.swift")
                #expect(file2["name"]?.string == "lib.swift")
            } else {
                Issue.record("invalid number of groupTree children")
            }
        } else {
            Issue.record("missing project groupTree")
        }

        #expect(exeTarget["type"]?.string == "target")
        #expect(exeTargetContents["guid"]?.string == "target-exe-guid@11")
        #expect(exeTargetContents["name"]?.string == "MyExecutable")
        #expect(exeTargetContents["dependencies"]?.array == [JSON(["guid": "target-lib-guid@11"])])
        #expect(exeTargetContents["type"]?.string == "standard")
        #expect(exeTargetContents["productTypeIdentifier"]?.string == "com.apple.product-type.tool")
        #expect(exeTargetContents["buildRules"]?.array == [])

        #expect(exeTargetContents["productReference"] == JSON([
            "type": "file",
            "guid": "PRODUCTREF-target-exe-guid",
            "name": "MyExecutable"
        ]))

        if let configurations = exeTargetContents["buildConfigurations"]?.array, configurations.count == 2 {
            let debugConfiguration = configurations[0]
            #expect(debugConfiguration["guid"]?.string == "target-exe-config-debug-guid")
            #expect(debugConfiguration["name"]?.string == "Debug")
            let debugSettings = debugConfiguration["buildSettings"]
            #expect(debugSettings?["TARGET_NAME"]?.string == "MyExecutable")
            #expect(debugConfiguration["impartedBuildProperties"]?.dictionary == ["buildSettings": JSON([:])])

            let releaseConfiguration = configurations[1]
            #expect(releaseConfiguration["guid"]?.string == "target-exe-config-release-guid")
            #expect(releaseConfiguration["name"]?.string == "Release")
            let releaseSettings = releaseConfiguration["buildSettings"]
            #expect(releaseSettings?["TARGET_NAME"]?.string == "MyExecutable")
            #expect(releaseSettings?["SKIP_INSTALL"]?.string == "NO")
            #expect(releaseConfiguration["impartedBuildProperties"]?.dictionary == ["buildSettings": JSON([:])])
        } else {
            Issue.record("invalid number of build configurations")
        }

        if let buildPhases = exeTargetContents["buildPhases"]?.array, buildPhases.count == 3 {
            let buildPhase1 = buildPhases[0]
            #expect(buildPhase1["guid"]?.string == "target-exe-sources-build-phase-guid")
            #expect(buildPhase1["type"]?.string == "com.apple.buildphase.sources")
            if let sources = buildPhase1["buildFiles"]?.array, sources.count == 1 {
                #expect(sources[0]["guid"]?.string == "target-exe-sources-build-file-guid")
                #expect(sources[0]["fileReference"]?.string == "exe-file-guid")
            } else {
                Issue.record("invalid number of build files")
            }

            let buildPhase2 = buildPhases[1]
            #expect(buildPhase2["guid"]?.string == "target-exe-frameworks-build-phase-guid")
            #expect(buildPhase2["type"]?.string == "com.apple.buildphase.frameworks")
            if let frameworks = buildPhase2["buildFiles"]?.array, frameworks.count == 1 {
                #expect(frameworks[0]["guid"]?.string == "target-exe-frameworks-build-file-guid")
                #expect(frameworks[0]["targetReference"]?.string == "target-lib-guid@11")
            } else {
                Issue.record("invalid number of build files")
            }

            let buildPhase3 = buildPhases[2]
            #expect(buildPhase3["guid"]?.string == "target-exe-headers-build-phase-guid")
            #expect(buildPhase3["type"]?.string == "com.apple.buildphase.headers")
            if let frameworks = buildPhase3["buildFiles"]?.array, frameworks.count == 1 {
                #expect(frameworks[0]["guid"]?.string == "target-exe-headers-build-file-guid")
                #expect(frameworks[0]["targetReference"]?.string == "target-lib-guid@11")
                #expect(frameworks[0]["headerVisibility"]?.string == "public")
            } else {
                Issue.record("invalid number of build files")
            }
        } else {
            Issue.record("invalid number of build configurations")
        }

        #expect(libTarget["type"]?.string == "target")
        #expect(libTargetContents["guid"]?.string == "target-lib-guid@11")
        #expect(libTargetContents["name"]?.string == "MyLibrary")
        #expect(libTargetContents["dependencies"]?.array == [])
        #expect(libTargetContents["type"]?.string == "standard")
        #expect(libTargetContents["productTypeIdentifier"]?.string == "com.apple.product-type.objfile")
        #expect(libTargetContents["buildRules"]?.array == [])

        #expect(libTargetContents["productReference"] == JSON([
            "type": "file",
            "guid": "PRODUCTREF-target-lib-guid",
            "name": "MyLibrary"
        ]))

        if let configurations = libTargetContents["buildConfigurations"]?.array, configurations.count == 2 {
            let debugConfiguration = configurations[0]
            #expect(debugConfiguration["guid"]?.string == "target-lib-config-debug-guid")
            #expect(debugConfiguration["name"]?.string == "Debug")
            let debugSettings = debugConfiguration["buildSettings"]
            #expect(debugSettings?["TARGET_NAME"]?.string == "MyLibrary-Debug")
            #expect(debugConfiguration["impartedBuildProperties"]?["buildSettings"]?["OTHER_CFLAGS"]?.array == [.string("-fmodule-map-file=modulemap"), .string("$(inherited)")])

            let releaseConfiguration = configurations[1]
            #expect(releaseConfiguration["guid"]?.string == "target-lib-config-release-guid")
            #expect(releaseConfiguration["name"]?.string == "Release")
            let releaseSettings = releaseConfiguration["buildSettings"]
            #expect(releaseSettings?["TARGET_NAME"]?.string == "MyLibrary")
            #expect(releaseConfiguration["impartedBuildProperties"]?["buildSettings"]?["OTHER_CFLAGS"]?.array == [.string("-fmodule-map-file=modulemap"), .string("$(inherited)")])
        } else {
            Issue.record("invalid number of build configurations")
        }

        if let buildPhases = libTargetContents["buildPhases"]?.array, buildPhases.count == 1 {
            let buildPhase1 = buildPhases[0]
            #expect(buildPhase1["guid"]?.string == "target-lib-sources-build-phase-guid")
            #expect(buildPhase1["type"]?.string == "com.apple.buildphase.sources")
            if let sources = buildPhase1["buildFiles"]?.array, sources.count == 1 {
                #expect(sources[0]["guid"]?.string == "target-lib-sources-build-file-guid")
                #expect(sources[0]["fileReference"]?.string == "lib-file-guid")
            } else {
                Issue.record("invalid number of build files")
            }
        } else {
            Issue.record("invalid number of build configurations")
        }

        #expect(aggregateTarget["type"]?.string == "target")
        #expect(aggregateTargetContents["guid"]?.string == "aggregate-target-guid@11")
        #expect(aggregateTargetContents["type"]?.string == "aggregate")
        #expect(aggregateTargetContents["name"]?.string == "AggregateLibrary")
        #expect(aggregateTargetContents["dependencies"]?.array == [
            JSON(["guid": "target-lib-guid@11"]),
            JSON(["guid": "target-exe-guid@11"]),
        ])
        #expect(aggregateTargetContents["buildRules"] == nil)

        if let configurations = aggregateTargetContents["buildConfigurations"]?.array, configurations.count == 2 {
            let debugConfiguration = configurations[0]
            #expect(debugConfiguration["guid"]?.string == "aggregate-target-config-debug-guid")
            #expect(debugConfiguration["name"]?.string == "Debug")
            let debugSettings = debugConfiguration["buildSettings"]
            #expect(debugSettings != nil)
            #expect(debugConfiguration["impartedBuildProperties"]?["buildSettings"]?["OTHER_CFLAGS"]?.array == [.string("-fmodule-map-file=modulemap"), .string("$(inherited)")])

            let releaseConfiguration = configurations[1]
            #expect(releaseConfiguration["guid"]?.string == "aggregate-target-config-release-guid")
            #expect(releaseConfiguration["name"]?.string == "Release")
            let releaseSettings = releaseConfiguration["buildSettings"]
            #expect(releaseSettings != nil)
            #expect(releaseConfiguration["impartedBuildProperties"]?["buildSettings"]?["OTHER_CFLAGS"]?.array == [.string("-fmodule-map-file=modulemap"), .string("$(inherited)")])
        } else {
            Issue.record("invalid number of build configurations")
        }

        if let buildPhases = aggregateTargetContents["buildPhases"]?.array, buildPhases.count == 0 {
        } else {
            Issue.record("invalid number of build configurations")
        }
    }
}
