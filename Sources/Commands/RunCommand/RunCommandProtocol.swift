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
import struct CoreCommands.GlobalOptions

import Basics
import CoreCommands
import Foundation
import PackageGraph
import PackageModel
import SPMBuildCore

import enum TSCBasic.ProcessEnv
import func TSCBasic.exec

import enum TSCUtility.Diagnostics

#if canImport(Android)
import Android
#endif

protocol RunCommandProtocol {
    var useBuildSystem: Bool {get}

    func run(
        swiftCommandState: SwiftCommandState,
        globalOptions: GlobalOptions,
        options: RunCommandOptions,
    ) async throws
}

extension RunCommandProtocol {
    func findProductName(in graph: ModulesGraph, executable: String?) throws -> String {
        if let executable {
            // There should be only one product with the given name in the graph
            // and it should be executable or snippet.
            guard let product = graph.product(for: executable),
                  product.type == .executable || product.type == .snippet
            else {
                throw RunError.executableNotFound(executable)
            }
            return executable
        }

        // If the executable is implicit, search through root products.
        let rootExecutables = graph.rootPackages
            .flatMap { $0.products }
            // The type checker slows down significantly when ProductTypes arent explicitly typed.
            .filter { $0.type == ProductType.executable || $0.type == ProductType.snippet }
            .map { $0.name }

        // Error out if the package contains no executables.
        guard rootExecutables.count > 0 else {
            throw RunError.noExecutableFound
        }

        // Only implicitly deduce the executable if it is the only one.
        guard rootExecutables.count == 1 else {
            throw RunError.multipleExecutables(rootExecutables)
        }

        return rootExecutables[0]
    }

    func getBuildSystem(
        swiftCommandState: SwiftCommandState,
        executable: String?,
    ) async throws -> BuildSystem {
        let asyncUnsafeGraphLoader = {
            try await swiftCommandState.loadPackageGraph(
                explicitProduct: executable,
            )
        }

        return try await swiftCommandState.createBuildSystem(
            explicitProduct: executable,
            // The package graph loader was previously only set for mode Repl
            packageGraphLoader: asyncUnsafeGraphLoader,
        )
    }

    /// Executes the executable at the specified path.
    func run(
        fileSystem: FileSystem,
        executablePath: AbsolutePath,
        originalWorkingDirectory: AbsolutePath,
        arguments: [String]
    ) throws {
        // Make sure we are running from the original working directory.
        let cwd: AbsolutePath? = fileSystem.currentWorkingDirectory
        if cwd == nil || originalWorkingDirectory != cwd {
            try ProcessEnv.chdir(originalWorkingDirectory)
        }

        let pathRelativeToWorkingDirectory = executablePath.relative(to: originalWorkingDirectory)

        let args = [pathRelativeToWorkingDirectory.pathString] + arguments
        try execute(path: executablePath.pathString, args: args)
    }


    /// A safe wrapper of TSCBasic.exec.
    fileprivate func execute(path: String, args: [String]) throws -> Never {
        #if !os(Windows)
            // Dispatch will disable almost all asynchronous signals on its worker threads, and this is called from `async`
            // context. To correctly `exec` a freshly built binary, we will need to:
            // 1. reset the signal masks
            for i in 1..<NSIG {
                signal(i, SIG_DFL)
            }
            var sig_set_all = sigset_t()
            sigfillset(&sig_set_all)
            sigprocmask(SIG_UNBLOCK, &sig_set_all, nil)

            #if os(FreeBSD) || os(OpenBSD)
                #if os(FreeBSD)
                    pthread_suspend_all_np()
                #endif
                closefrom(3)
            #else
                #if os(Android)
                    let number_fds = Int32(sysconf(_SC_OPEN_MAX))
                #else
                    let number_fds = getdtablesize()
                #endif /* os(Android) */

                // 2. set to close all file descriptors on exec
                for i in 3..<number_fds {
                    _ = fcntl(i, F_SETFD, FD_CLOEXEC)
                }
            #endif /* os(FreeBSD) || os(OpenBSD) */
        #endif

        try TSCBasic.exec(path: path, args: args)
    }

}