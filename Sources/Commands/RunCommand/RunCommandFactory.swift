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
import struct Basics.AbsolutePath
import protocol Basics.FileSystem
internal struct RunCommandFactory {

    static func getInstance(
        mode: RunMode,
        fileSystem: FileSystem,
        executable: String?,
    ) -> RunCommandProtocol {
        switch mode {
            case .repl:
                return RunModeRepl()
            case .debugger:
                return RunModeDebugger()
            case .run:
                var returnType: RunCommandProtocol = RunModeRunExecutable()
                do {
                    if let executable,  try RunCommandFactory.isValidSwiftFilePath(fileSystem: fileSystem, path: executable) {
                        returnType = RunModeRunFile()
                    }
                } catch {
                    // do nothing
                }
                return returnType
        }
    }

    /// Determines if a path points to a valid swift file.
    fileprivate static func isValidSwiftFilePath(fileSystem: FileSystem, path: String) throws -> Bool {
        guard path.hasSuffix(".swift") else { return false }
        //FIXME: Return false when the path is not a valid path string.
        let absolutePath: AbsolutePath
        if path.first == "/" {
            do {
                absolutePath = try AbsolutePath(validating: path)
            } catch {
                return false
            }
        } else {
            guard let cwd = fileSystem.currentWorkingDirectory else {
                return false
            }
            absolutePath = try AbsolutePath(cwd, validating: path)
        }
        return fileSystem.isFile(absolutePath)
    }

}