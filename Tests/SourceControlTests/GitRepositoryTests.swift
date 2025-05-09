//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift open source project
//
// Copyright (c) 2014-2017 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See http://swift.org/LICENSE.txt for license information
// See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Foundation

@_spi(ProcessEnvironmentBlockShim)
import Basics
@testable import SourceControl
import _InternalTestSupport
import Testing

import struct TSCBasic.FileSystemError
import func TSCBasic.makeDirectories
import class Basics.AsyncProcess

import enum TSCUtility.Git

@Suite(
    .bug("https://github.com/swiftlang/swift-package-manager/issues/8564"),
    .serialized, // because of the listed issue
)
final class GitRepositoryTests {
    init() async throws {
        // needed for submodule tests
        Git.environmentBlock = ["GIT_ALLOW_PROTOCOL": "file"]
    }

    deinit {
        Git.environmentBlock = .init(Environment.current)
    }


    /// Test the basic provider functions.
    @Test
    func repositorySpecifier() async throws {
        do {
            let s1 = RepositorySpecifier(url: "a")
            let s2 = RepositorySpecifier(url: "a")
            let s3 = RepositorySpecifier(url: "b")

            #expect(s1 == s1)
            #expect(s1 == s2)
            #expect(Set([s1]) == Set([s2]))
            #expect(s1 != s3)
            #expect(s2 != s3)
        }

        do {
            let s1 = RepositorySpecifier(path: "/A")
            let s2 = RepositorySpecifier(path: "/A")
            let s3 = RepositorySpecifier(path: "/B")

            #expect(s1 == s1)
            #expect(s1 == s2)
            #expect(Set([s1]) == Set([s2]))
            #expect(s1 != s3)
            #expect(s2 != s3)
        }
    }

    /// Test the basic provider functions.
    @Test
    func provider() throws {
        try testWithTemporaryDirectory { path in
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath, tag: "1.2.3")

            // Test the provider.
            let testCheckoutPath = path.appending("checkout")
            let provider = GitRepositoryProvider()
            #expect(try provider.workingCopyExists(at: testRepoPath))
            let repoSpec = RepositorySpecifier(path: testRepoPath)
            try provider.fetch(repository: repoSpec, to: testCheckoutPath)

            // Verify the checkout was made.
            #expect(localFileSystem.isDirectory(testCheckoutPath))

            // Test the repository interface.
            let repository = provider.open(repository: repoSpec, at: testCheckoutPath)
            let tags = try repository.getTags()
            #expect(try repository.getTags() == ["1.2.3"])

            let revision = try repository.resolveRevision(tag: tags.first ?? "<invalid>")
            // FIXME: It would be nice if we had a deterministic hash here...
            let repository_revision = try AsyncProcess.popen(
                args: Git.tool, "-C", testRepoPath.pathString, "rev-parse", "--verify", "1.2.3").utf8Output().spm_chomp()
            #expect(revision.identifier == repository_revision)
            if let revision = try? repository.resolveRevision(tag: "<invalid>") {
                Issue.record("unexpected resolution of invalid tag to \(revision)")
            }

            let main = try repository.resolveRevision(identifier: "main")
            let identifier = try AsyncProcess.checkNonZeroExit(args: Git.tool, "-C", testRepoPath.pathString, "rev-parse", "--verify", "main").spm_chomp()
            #expect(main.identifier == identifier)

            // Check that git hashes resolve to themselves.
            let mainIdentifier = try repository.resolveRevision(identifier: main.identifier)
            #expect(main.identifier == mainIdentifier.identifier)

            // Check that invalid identifier doesn't resolve.
            #expect(throws: (any Error).self, "unexpected resolution of invalid identifier to \(revision)") {
                try repository.resolveRevision(identifier: "invalid")
            }
        }
    }

    /// Check hash validation.
    @Test
    func gitRepositoryHash() async throws {
        let validHash = "0123456789012345678901234567890123456789"
        #expect(GitRepository.Hash(validHash) != nil)

        let invalidHexHash = validHash + "1"
        #expect(GitRepository.Hash(invalidHexHash) == nil)

        let invalidNonHexHash = "012345678901234567890123456789012345678!"
        #expect(GitRepository.Hash(invalidNonHexHash) == nil)
    }

    /// Check raw repository facilities.
    ///
    /// In order to be stable, this test uses a static test git repository in
    /// `Inputs`, which has known commit hashes. See the `construct.sh` script
    /// contained within it for more information.
    @Test(
        .bug("https://github.com/swiftlang/swift-package-manager/issues/8385", "test repository has non-portable file names")
    )
    func rawRepository() async throws {
        try withKnownIssue {
        try testWithTemporaryDirectory { path in
            // Unarchive the static test repository.
            let inputArchivePath = AbsolutePath(#file).parentDirectory.appending(components: "Inputs", "TestRepo.tgz")
#if os(Windows)
            try systemQuietly(["tar.exe", "-x", "-v", "-C", path.pathString, "-f", inputArchivePath.pathString])
#else
            try systemQuietly(["tar", "--no-same-owner", "-x", "-v", "-C", path.pathString, "-f", inputArchivePath.pathString])
#endif
            let testRepoPath = path.appending("TestRepo")

            // Check hash resolution.
            let repo = GitRepository(path: testRepoPath)
            let commit_hash = try repo.resolveHash(treeish: "1.0", type: "commit")
            let branch_hash = try repo.resolveHash(treeish: "master")
            #expect(commit_hash == branch_hash)

            // Get the initial commit.
            let initialCommitHash = try repo.resolveHash(treeish: "a8b9fcb")
            #expect(initialCommitHash == GitRepository.Hash("a8b9fcbf893b3b02c0196609059ebae37aeb7f0b"))

            // Check commit loading.
            let initialCommit = try repo.readCommit(hash: initialCommitHash)
            #expect(initialCommit.hash == initialCommitHash)
            #expect(initialCommit.tree == GitRepository.Hash("9d463c3b538619448c5d2ecac379e92f075a8976"))

            // Check tree loading.
            let initialTree = try repo.readTree(hash: initialCommit.tree)
            guard case .hash(let initialTreeHash) = initialTree.location else {
                Issue.record("wrong pointer")
                return
            }
            #expect(initialTreeHash == initialCommit.tree)
            #expect(initialTree.contents.count == 1)
            let readmeEntry = try #require(initialTree.contents.first)
            guard case .hash(let readmeEntryHash) = readmeEntry.location else {
                Issue.record("wrong pointer")
                return
            }
            #expect(readmeEntryHash == GitRepository.Hash("92513075b3491a54c45a880be25150d92388e7bc"))
            #expect(readmeEntry.type == .blob)
            #expect(readmeEntry.name == "README.txt")

            // Check loading of odd names.
            //
            // This is a commit which has a subdirectory 'funny-names' with
            // paths with special characters.
            let funnyNamesCommit = try repo.readCommit(hash: repo.resolveHash(treeish: "a7b19a7"))
            let funnyNamesRoot = try repo.readTree(hash: funnyNamesCommit.tree)
            #expect(funnyNamesRoot.contents.map{ $0.name } == ["README.txt", "funny-names", "subdir"])
            try #require(funnyNamesRoot.contents.count == 3)

            // FIXME: This isn't yet supported.
            let funnyNamesSubdirEntry = funnyNamesRoot.contents[1]
            #expect(funnyNamesSubdirEntry.type == .tree)
            #expect(throws: (any Error).self, "unexpected success reading tree with funny names") {
                try repo.readTree(location: funnyNamesSubdirEntry.location)
            }
        }
        } when: {
            ProcessInfo.hostOperatingSystem == .windows
        }
    }

    @Test
    func submoduleRead() async throws {
        try testWithTemporaryDirectory { path in
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)

            let repoPath = path.appending("repo")
            try makeDirectories(repoPath)
            initGitRepo(repoPath)

            try AsyncProcess.checkNonZeroExit(
                args: Git.tool, "-C", repoPath.pathString, "submodule", "add", testRepoPath.pathString,
                environment: .init(Git.environmentBlock)
            )
            let repo = GitRepository(path: repoPath)
            try repo.stageEverything()
            try repo.commit()
            // We should be able to read a repo which as a submdoule.
            _ = try repo.readTree(hash: try repo.resolveHash(treeish: "main"))
        }
    }

    /// Test the Git file system view.
    @Test
    func gitFileView() async throws {
        try testWithTemporaryDirectory { path in
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)

            // Add a few files and a directory.
            let test1FileContents = "Hello, world!"
            let test2FileContents = "Hello, happy world!"
            let test3FileContents = """
                #!/bin/sh
                set -e
                exit 0
                """
            try localFileSystem.writeFileContents(testRepoPath.appending("test-file-1.txt"), string: test1FileContents)
            try localFileSystem.createDirectory(testRepoPath.appending("subdir"))
            try localFileSystem.writeFileContents(testRepoPath.appending(components: "subdir", "test-file-2.txt"), string: test2FileContents)
            try localFileSystem.writeFileContents(testRepoPath.appending("test-file-3.sh"), string: test3FileContents)
            try localFileSystem.chmod(.executable, path: testRepoPath.appending("test-file-3.sh"), options: [])
            let testRepo = GitRepository(path: testRepoPath)
            try testRepo.stage(files: "test-file-1.txt", "subdir/test-file-2.txt", "test-file-3.sh")
            try testRepo.commit()
            try testRepo.tag(name: "test-tag")

            // Get the the repository via the provider. the provider.
            let testClonePath = path.appending("clone")
            let provider = GitRepositoryProvider()
            let repoSpec = RepositorySpecifier(path: testRepoPath)
            try provider.fetch(repository: repoSpec, to: testClonePath)
            let repository = provider.open(repository: repoSpec, at: testClonePath)

            // Get and test the file system view.
            let view = try repository.openFileView(revision: repository.resolveRevision(tag: "test-tag"))

            // Check basic predicates.
            #expect(view.isDirectory("/"))
            #expect(view.isDirectory("/subdir"))
            #expect(!view.isDirectory("/does-not-exist"))
            #expect(view.exists("/test-file-1.txt"))
            #expect(!view.exists("/does-not-exist"))
            #expect(view.isFile("/test-file-1.txt"))
            #expect(!view.isSymlink("/test-file-1.txt"))
            #expect(!view.isExecutableFile("/does-not-exist"))
#if !os(Windows)
            #expect(view.isExecutableFile("/test-file-3.sh"))
#endif

            // Check read of a directory.
            let subdirPath = AbsolutePath("/subdir")
            #expect(try view.getDirectoryContents(AbsolutePath("/")).sorted() == ["file.swift", "subdir", "test-file-1.txt", "test-file-3.sh"])
            #expect(try view.getDirectoryContents(subdirPath).sorted() == ["test-file-2.txt"])
            #expect(throws: FileSystemError(.isDirectory, subdirPath)) {
                _ = try view.readFileContents(subdirPath)
            }

            // Check read versus root.
            #expect(throws: FileSystemError(.isDirectory, AbsolutePath.root)) {
                _ = try view.readFileContents(.root)
            }

            // Check read through a non-directory.
            let notDirectoryPath1 = AbsolutePath("/test-file-1.txt")
            #expect(throws: FileSystemError(.notDirectory, notDirectoryPath1)) {
                _ = try view.getDirectoryContents(notDirectoryPath1)
            }
            let notDirectoryPath2 = AbsolutePath("/test-file-1.txt/thing")
            #expect(throws: FileSystemError(.notDirectory, notDirectoryPath2)) {
                _ = try view.readFileContents(notDirectoryPath2)
            }

            // Check read/write into a missing directory.
            let noEntryPath1 = AbsolutePath("/does-not-exist")
            #expect(throws: FileSystemError(.noEntry, noEntryPath1)) {
                _ = try view.getDirectoryContents(noEntryPath1)
            }
            let noEntryPath2 = AbsolutePath("/does/not/exist")
            #expect(throws: FileSystemError(.noEntry, noEntryPath2)) {
                _ = try view.readFileContents(noEntryPath2)
            }

            // Check read of a file.
            #expect(try view.readFileContents("/test-file-1.txt") == test1FileContents)
            #expect(try view.readFileContents("/subdir/test-file-2.txt") == test2FileContents)
            #expect(try view.readFileContents("/test-file-3.sh") == test3FileContents)
        }
    }

    /// Test the handling of local checkouts.
    @Test
    func checkouts() async throws {
        try testWithTemporaryDirectory { path in
            // Create a test repository.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath, tag: "initial")
            let initialRevision = try GitRepository(path: testRepoPath).getCurrentRevision()

            // Add a couple files and a directory.
            try localFileSystem.writeFileContents(testRepoPath.appending("test.txt"), bytes: "Hi")
            let testRepo = GitRepository(path: testRepoPath)
            try testRepo.stage(file: "test.txt")
            try testRepo.commit()
            try testRepo.tag(name: "test-tag")
            let currentRevision = try GitRepository(path: testRepoPath).getCurrentRevision()

            // Fetch the repository using the provider.
            let testClonePath = path.appending("clone")
            let provider = GitRepositoryProvider()
            let repoSpec = RepositorySpecifier(path: testRepoPath)
            try provider.fetch(repository: repoSpec, to: testClonePath)

            // Clone off a checkout.
            let checkoutPath = path.appending("checkout")
            _ = try provider.createWorkingCopy(repository: repoSpec, sourcePath: testClonePath, at: checkoutPath, editable: false)
            // The remote of this checkout should point to the clone.
            #expect(try GitRepository(path: checkoutPath).remotes()[0].url == testClonePath.pathString)

            let editsPath = path.appending("edit")
            _ = try provider.createWorkingCopy(repository: repoSpec, sourcePath: testClonePath, at: editsPath, editable: true)
            // The remote of this checkout should point to the original repo.
            #expect(try GitRepository(path: editsPath).remotes()[0].url == testRepoPath.pathString)

            // Check the working copies.
            for path in [checkoutPath, editsPath] {
                let workingCopy = try provider.openWorkingCopy(at: path)
                try workingCopy.checkout(tag: "test-tag")
                #expect(try workingCopy.getCurrentRevision() == currentRevision)
                #expect(localFileSystem.exists(path.appending("test.txt")))
                try workingCopy.checkout(tag: "initial")
                #expect(try workingCopy.getCurrentRevision() == initialRevision)
                #expect(!localFileSystem.exists(path.appending("test.txt")))
            }
        }
    }

    @Test
    func fetch() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath, tag: "1.2.3")
            let repo = GitRepository(path: testRepoPath)
            #expect(try repo.getTags() == ["1.2.3"])

            // Clone it somewhere.
            let testClonePath = path.appending("clone")
            let provider = GitRepositoryProvider()
            let repoSpec = RepositorySpecifier(path: testRepoPath)
            try provider.fetch(repository: repoSpec, to: testClonePath)
            let clonedRepo = provider.open(repository: repoSpec, at: testClonePath)
            #expect(try clonedRepo.getTags() == ["1.2.3"])

            // Clone off a checkout.
            let checkoutPath = path.appending("checkout")
            let checkoutRepo = try provider.createWorkingCopy(repository: repoSpec, sourcePath: testClonePath, at: checkoutPath, editable: false)
            #expect(try checkoutRepo.getTags() == ["1.2.3"])

            // Add a new file to original repo.
            try localFileSystem.writeFileContents(testRepoPath.appending("test.txt"), bytes: "Hi")
            let testRepo = GitRepository(path: testRepoPath)
            try testRepo.stage(file: "test.txt")
            try testRepo.commit()
            try testRepo.tag(name: "2.0.0")

            // Update the cloned repo.
            try clonedRepo.fetch()
            #expect(try clonedRepo.getTags().sorted() == ["1.2.3", "2.0.0"])

            // Update the checkout.
            try checkoutRepo.fetch()
            #expect(try checkoutRepo.getTags().sorted() == ["1.2.3", "2.0.0"])
        }
    }

    @Test
    func hasUnpushedCommits() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)

            // Create a bare clone it somewhere because we want to later push into the repo.
            let testBareRepoPath = path.appending("test-repo-bare")
            try systemQuietly([Git.tool, "clone", "--bare", testRepoPath.pathString, testBareRepoPath.pathString])

            // Clone it somewhere.
            let testClonePath = path.appending("clone")
            let provider = GitRepositoryProvider()
            let repoSpec = RepositorySpecifier(path: testBareRepoPath)
            try provider.fetch(repository: repoSpec, to: testClonePath)

            // Clone off a checkout.
            let checkoutPath = path.appending("checkout")
            let checkoutRepo = try provider.createWorkingCopy(repository: repoSpec, sourcePath: testClonePath, at: checkoutPath, editable: true)

            #expect(try checkoutRepo.hasUnpushedCommits() == false)
            // Add a new file to checkout.
            try localFileSystem.writeFileContents(checkoutPath.appending("test.txt"), bytes: "Hi")
            let checkoutTestRepo = GitRepository(path: checkoutPath)
            try checkoutTestRepo.stage(file: "test.txt")
            try checkoutTestRepo.commit()

            // We should have commits which are not pushed.
            #expect(try checkoutRepo.hasUnpushedCommits())
            // Push the changes and check again.
            try checkoutTestRepo.push(remote: "origin", branch: "main")
            #expect(try checkoutRepo.hasUnpushedCommits() == false)
        }
    }

    @Test
    func setRemote() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)
            let repo = GitRepository(path: testRepoPath)

            // There should be no remotes currently.
            #expect(try repo.remotes().isEmpty)

            // Add a remote via git cli.
            try systemQuietly([Git.tool, "-C", testRepoPath.pathString, "remote", "add", "origin", "../foo"])
            // Test if it was added.
            #expect(Dictionary(uniqueKeysWithValues: try repo.remotes().map { ($0.0, $0.1) }) == ["origin": "../foo"])
            // Change remote.
            try repo.setURL(remote: "origin", url: "../bar")
            #expect(Dictionary(uniqueKeysWithValues: try repo.remotes().map { ($0.0, $0.1) }) == ["origin": "../bar"])
            // Try changing remote of non-existent remote.
            do {
                try repo.setURL(remote: "fake", url: "../bar")
                Issue.record("unexpected success (shouldn’t have been able to set URL of missing remote)")
            }
            catch let error as GitRepositoryError {
                #expect(error.path == testRepoPath)
                #expect(error.diagnosticLocation != nil)
            }
        }
    }

    @Test
    func uncommittedChanges() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)

            // Create a file (which we will modify later).
            try localFileSystem.writeFileContents(testRepoPath.appending("test.txt"), bytes: "Hi")
            let repo = GitRepository(path: testRepoPath)

            #expect(repo.hasUncommittedChanges())

            try repo.stage(file: "test.txt")

            #expect(repo.hasUncommittedChanges())

            try repo.commit()

            #expect(!repo.hasUncommittedChanges())

            // Modify the file in the repo.
            try localFileSystem.writeFileContents(repo.path.appending("test.txt"), bytes: "Hello")
            #expect(repo.hasUncommittedChanges())
        }
    }

    @Test
    func branchOperations() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)

            let repo = GitRepository(path: testRepoPath)
            var currentRevision = try repo.getCurrentRevision()
            // This is the default branch of a new repo.
            #expect(repo.exists(revision: Revision(identifier: "main")))
            // Check a non existent revision.
            #expect(!repo.exists(revision: Revision(identifier: "nonExistent")))
            // Checkout a new branch using command line.
            try systemQuietly([Git.tool, "-C", testRepoPath.pathString, "checkout", "-b", "TestBranch1"])
            #expect(repo.exists(revision: Revision(identifier: "TestBranch1")))
            #expect(try repo.getCurrentRevision() == currentRevision)

            // Make sure we're on the new branch right now.
            #expect(try repo.currentBranch() == "TestBranch1")

            // Checkout new branch using our API.
            currentRevision = try repo.getCurrentRevision()
            try repo.checkout(newBranch: "TestBranch2")
            #expect(repo.exists(revision: Revision(identifier: "TestBranch2")))
            #expect(try repo.getCurrentRevision() == currentRevision)
            #expect(try repo.currentBranch() == "TestBranch2")
        }
    }

    @Test
    func revisionOperations() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let repositoryPath = path.appending("test-repo")
            try makeDirectories(repositoryPath)
            initGitRepo(repositoryPath)

            let repo = GitRepository(path: repositoryPath)

            do {
                let revision = try repo.getCurrentRevision()
                #expect(repo.exists(revision: revision))
            }

            do {
                #expect(!repo.exists(revision: Revision(identifier: UUID().uuidString)))

                let tag = UUID().uuidString
                try repo.tag(name: tag)
                let revision = try repo.resolveRevision(tag: tag)
                #expect(repo.exists(revision: revision))
            }
        }
    }

    @Test
    func checkoutRevision() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)
            let repo = GitRepository(path: testRepoPath)

            func createAndStageTestFile() throws {
                try localFileSystem.writeFileContents(testRepoPath.appending("test.txt"), bytes: "Hi")
                try repo.stage(file: "test.txt")
            }

            try repo.checkout(revision: Revision(identifier: "main"))
            // Current branch must be main.
            #expect(try repo.currentBranch() == "main")
            // Create a new branch.
            try repo.checkout(newBranch: "TestBranch")
            #expect(try repo.currentBranch() == "TestBranch")
            // Create some random file.
            try createAndStageTestFile()
            #expect(repo.hasUncommittedChanges())
            // Checkout current revision again, the test file should go away.
            let currentRevision = try repo.getCurrentRevision()
            try repo.checkout(revision: currentRevision)
            #expect(!repo.hasUncommittedChanges())
            // We should be on detached head.
            #expect(try repo.currentBranch() == "HEAD")

            // Try again and checkout to a previous branch.
            try createAndStageTestFile()
            #expect(repo.hasUncommittedChanges())
            try repo.checkout(revision: Revision(identifier: "TestBranch"))
            #expect(!repo.hasUncommittedChanges())
            #expect(try repo.currentBranch() == "TestBranch")

            do {
                try repo.checkout(revision: Revision(identifier: "nonExistent"))
                Issue.record("Unexpected checkout success on non existent branch")
            } catch {}
        }
    }

    @Test
    func submodules() async throws {
        try testWithTemporaryDirectory { path in
            let provider = GitRepositoryProvider()

            // Create repos: foo and bar, foo will have bar as submodule and then later
            // the submodule ref will be updated in foo.
            let fooPath = path.appending("foo-original")
            let fooSpecifier = RepositorySpecifier(path: fooPath)
            let fooRepoPath = path.appending("foo-repo")
            let fooWorkingPath = path.appending("foo-working")
            let barPath = path.appending("bar-original")
            let bazPath = path.appending("baz-original")
            // Create the repos and add a file.
            for path in [fooPath, barPath, bazPath] {
                try makeDirectories(path)
                initGitRepo(path)
                try localFileSystem.writeFileContents(path.appending("hello.txt"), bytes: "hello")
                let repo = GitRepository(path: path)
                try repo.stageEverything()
                try repo.commit()
            }
            let foo = GitRepository(path: fooPath)
            let bar = GitRepository(path: barPath)
            // The tag 1.0.0 does not contain the submodule.
            try foo.tag(name: "1.0.0")

            // Fetch and clone repo foo.
            try provider.fetch(repository: fooSpecifier, to: fooRepoPath)
            _ = try provider.createWorkingCopy(repository: fooSpecifier, sourcePath: fooRepoPath, at: fooWorkingPath, editable: false)

            let fooRepo = GitRepository(path: fooRepoPath, isWorkingRepo: false)
            let fooWorkingRepo = GitRepository(path: fooWorkingPath)

            // Checkout the first tag which doesn't has submodule.
            try fooWorkingRepo.checkout(tag: "1.0.0")
            #expect(!localFileSystem.exists(fooWorkingPath.appending("bar")))

            // Add submodule to foo and tag it as 1.0.1
            try foo.checkout(newBranch: "submodule")
            try AsyncProcess.checkNonZeroExit(
                args: Git.tool, "-C", fooPath.pathString, "submodule", "add", barPath.pathString, "bar",
                environment: .init(Git.environmentBlock)
            )

            try foo.stageEverything()
            try foo.commit()
            try foo.tag(name: "1.0.1")

            // Update our bare and working repos.
            try fooRepo.fetch()
            try fooWorkingRepo.fetch()
            // Checkout the tag with submodule and expect submodules files to be present.
            try fooWorkingRepo.checkout(tag: "1.0.1")
            #expect(localFileSystem.exists(fooWorkingPath.appending(components: "bar", "hello.txt")))
            // Checkout the tag without submodule and ensure that the submodule files are gone.
            try fooWorkingRepo.checkout(tag: "1.0.0")
            #expect(!localFileSystem.exists(fooWorkingPath.appending(components: "bar")))

            // Add something to bar.
            try localFileSystem.writeFileContents(barPath.appending("bar.txt"), bytes: "hello")
            // Add a submodule too to check for recursive submodules.
            try AsyncProcess.checkNonZeroExit(
                args: Git.tool, "-C", barPath.pathString, "submodule", "add", bazPath.pathString, "baz",
                environment: .init(Git.environmentBlock)
            )

            try bar.stageEverything()
            try bar.commit()

            // Update the ref of bar in foo and tag as 1.0.2
            try systemQuietly([Git.tool, "-C", fooPath.appending("bar").pathString, "pull"])
            try foo.stageEverything()
            try foo.commit()
            try foo.tag(name: "1.0.2")

            try fooRepo.fetch()
            try fooWorkingRepo.fetch()
            // We should see the new file we added in the submodule.
            try fooWorkingRepo.checkout(tag: "1.0.2")
            #expect(localFileSystem.exists(fooWorkingPath.appending(components: "bar", "hello.txt")))
            #expect(localFileSystem.exists(fooWorkingPath.appending(components: "bar", "bar.txt")))
            #expect(localFileSystem.exists(fooWorkingPath.appending(components: "bar", "baz", "hello.txt")))

            // Double check.
            try fooWorkingRepo.checkout(tag: "1.0.0")
            #expect(!localFileSystem.exists(fooWorkingPath.appending(components: "bar")))
        }
    }

    @Test
    func alternativeObjectStoreValidation() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath, tag: "1.2.3")
            let repo = GitRepository(path: testRepoPath)
            #expect(try repo.getTags() == ["1.2.3"])

            // Clone it somewhere.
            let testClonePath = path.appending("clone")
            let provider = GitRepositoryProvider()
            let repoSpec = RepositorySpecifier(path: testRepoPath)
            try provider.fetch(repository: repoSpec, to: testClonePath)
            let clonedRepo = provider.open(repository: repoSpec, at: testClonePath)
            #expect(try clonedRepo.getTags() == ["1.2.3"])

            // Clone off a checkout.
            let checkoutPath = path.appending("checkout")
            let checkoutRepo = try provider.createWorkingCopy(repository: repoSpec, sourcePath: testClonePath, at: checkoutPath, editable: false)

            // The object store should be valid.
            #expect(checkoutRepo.isAlternateObjectStoreValid(expected: testClonePath))

            // Wrong path
            #expect(!checkoutRepo.isAlternateObjectStoreValid(expected: testClonePath.appending(UUID().uuidString)))

            // Delete the clone (alternative object store).
            try localFileSystem.removeFileTree(testClonePath)
            #expect(!checkoutRepo.isAlternateObjectStoreValid(expected: testClonePath))
        }
    }

    @Test
    func areIgnored() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test_repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)
            let repo = GitRepository(path: testRepoPath)

            // Add a .gitignore
            try localFileSystem.writeFileContents(testRepoPath.appending(".gitignore"), bytes: "ignored_file1\nignored file2")

            let ignored = try repo.areIgnored([testRepoPath.appending("ignored_file1"), testRepoPath.appending("ignored file2"), testRepoPath.appending("not ignored")])
            #expect(ignored[0])
            #expect(ignored[1])
            #expect(!ignored[2])

            let notIgnored = try repo.areIgnored([testRepoPath.appending("not_ignored")])
            #expect(!notIgnored[0])
        }
    }

    @Test
    func areIgnoredWithSpaceInRepoPath() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repo.
            let testRepoPath = path.appending("test repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)
            let repo = GitRepository(path: testRepoPath)

            // Add a .gitignore
            try localFileSystem.writeFileContents(testRepoPath.appending(".gitignore"), bytes: "ignored_file1")

            let ignored = try repo.areIgnored([testRepoPath.appending("ignored_file1")])
            #expect(ignored[0])
        }
    }

    @Test
    func missingDefaultBranch() async throws {
        try testWithTemporaryDirectory { path in
            // Create a repository.
            let testRepoPath = path.appending("test-repo")
            try makeDirectories(testRepoPath)
            initGitRepo(testRepoPath)
            let repo = GitRepository(path: testRepoPath)

            // Create a `newMain` branch and remove `main`.
            try repo.checkout(newBranch: "newMain")
            try systemQuietly([Git.tool, "-C", testRepoPath.pathString, "branch", "-D", "main"])

            // Change the branch name to something non-existent.
            try systemQuietly([Git.tool, "-C", testRepoPath.pathString, "symbolic-ref", "HEAD", "refs/heads/_non_existent_branch_"])

            // Clone it somewhere.
            let testClonePath = path.appending("clone")
            let provider = GitRepositoryProvider()
            let repoSpec = RepositorySpecifier(path: testRepoPath)
            try provider.fetch(repository: repoSpec, to: testClonePath)
            let clonedRepo = provider.open(repository: repoSpec, at: testClonePath)
            #expect(try clonedRepo.getTags() == [])

            // Clone off a checkout.
            let checkoutPath = path.appending("checkout")
            let checkoutRepo = try provider.createWorkingCopy(repository: repoSpec, sourcePath: testClonePath, at: checkoutPath, editable: false)
            #expect(!localFileSystem.exists(checkoutPath.appending("file.swift")))

            // Try to check out the `main` branch.
            try checkoutRepo.checkout(revision: Revision(identifier: "newMain"))
            #expect(localFileSystem.exists(checkoutPath.appending("file.swift")))

            // The following will throw if HEAD was set incorrectly and we didn't do a no-checkout clone.
            #expect(throws: Never.self) {
                try checkoutRepo.getCurrentRevision()
            }
        }
    }

    @Test
    func validDirectoryLocalRelativeOrigin() async throws {
        try testWithTemporaryDirectory { tmpDir in
            // Create a repository.
            let packageDir = tmpDir.appending("SomePackage")
            try localFileSystem.createDirectory(packageDir)

            // Create a repository manager for it.
            let repoProvider = GitRepositoryProvider()
            let repositoryManager = RepositoryManager(
                fileSystem: localFileSystem,
                path: packageDir,
                provider: repoProvider,
                delegate: .none
            )

            let customRemote = "../OriginOfSomePackage.git"

            // Before initializing the directory with a git repo, it is never valid.
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir)
            }
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString)))
            }
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemote)))
            }

            initGitRepo(packageDir)
            // Set the remote.
            try systemQuietly([Git.tool, "-C", packageDir.pathString, "remote", "add", "origin", customRemote])
            #expect(try repositoryManager.isValidDirectory(packageDir))

            let customRemoteWithoutPathExtension = (customRemote as NSString).deletingPathExtension
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemote))))
            // We consider the directory valid even if the remote does not have the same path extension - in this case we expected '.git'.
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemoteWithoutPathExtension))))
            // We consider the directory valid even if the remote does not have the same path extension - in this case we expected '.git'.
            #expect(try repositoryManager.isValidDirectory(packageDir, for:  RepositorySpecifier(url: SourceControlURL((customRemote as NSString).deletingPathExtension + "/"))))

            // The following ensure that are actually checking the remote's origin.
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: AbsolutePath(validating: "/"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL("/"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: packageDir)) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: packageDir.appending(extension: "git"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString.appending(".git")))) == false)

            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL("https://mycustomdomain/some-package.git"))) == false)
        }
    }

    @Test
    func validDirectoryLocalAbsoluteOrigin() async throws {
        try testWithTemporaryDirectory { tmpDir in
            // Create a repository.
            let packageDir = tmpDir.appending("SomePackage")
            try localFileSystem.createDirectory(packageDir)

            // Create a repository manager for it.
            let repoProvider = GitRepositoryProvider()
            let repositoryManager = RepositoryManager(
                fileSystem: localFileSystem,
                path: packageDir,
                provider: repoProvider,
                delegate: .none
            )

            let customRemote = tmpDir.appending("OriginOfSomePackage.git")

            // Before initializing the directory with a git repo, it is never valid.
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir)
            }
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString)))
            }
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemote.pathString)))
            }

            initGitRepo(packageDir)
            // Set the remote.
            try systemQuietly([Git.tool, "-C", packageDir.pathString, "remote", "add", "origin", customRemote.pathString])
            #expect(try repositoryManager.isValidDirectory(packageDir))

            let customRemotePath = customRemote.pathString
            let customRemotePathWithoutPathExtension = (customRemotePath as NSString).deletingPathExtension
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: customRemote)))
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemotePath))))
            // We consider the directory valid even if the remote does not have the same path extension - in this case we expected '.git'.
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: try AbsolutePath(validating: customRemotePathWithoutPathExtension))))
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemotePathWithoutPathExtension))))
            // We consider the directory valid even if the remote does not have the same path extension - in this case we expected '.git'.
            #expect(try repositoryManager.isValidDirectory(packageDir, for:  RepositorySpecifier(path: try AbsolutePath(validating: customRemotePathWithoutPathExtension + "/"))))
            #expect(try repositoryManager.isValidDirectory(packageDir, for:  RepositorySpecifier(url: SourceControlURL((customRemotePath as NSString).deletingPathExtension + "/"))))

            // The following ensure that are actually checking the remote's origin.
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: AbsolutePath(validating: "/"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL("/"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: packageDir)) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: packageDir.appending(extension: "git"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString.appending(".git")))) == false)

            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL("https://mycustomdomain/some-package.git"))) == false)
        }
    }

    @Test
    func validDirectoryRemoteOrigin() async throws {
        try testWithTemporaryDirectory { tmpDir in
            // Create a repository.
            let packageDir = tmpDir.appending("SomePackage")
            try localFileSystem.createDirectory(packageDir)

            // Create a repository manager for it.
            let repoProvider = GitRepositoryProvider()
            let repositoryManager = RepositoryManager(
                fileSystem: localFileSystem,
                path: packageDir,
                provider: repoProvider,
                delegate: .none
            )

            let customRemote = try #require(URL(string: "https://mycustomdomain/some-package.git"))

            // Before initializing the directory with a git repo, it is never valid.
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir)
            }
            #expect(throws: (any Error).self) {
                try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemote)))
            }

            initGitRepo(packageDir)
            // Set the remote.
            try systemQuietly([Git.tool, "-C", packageDir.pathString, "remote", "add", "origin", customRemote.absoluteString])
            #expect(try repositoryManager.isValidDirectory(packageDir))

            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(customRemote))))
            // We consider the directory valid even if the remote does not have the same path extension - in this case we expected '.git'.
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL("https://mycustomdomain/some-package"))))
            // We consider the directory valid even if the remote does not have the same path extension - in this case we expected '.git'.
            #expect(try repositoryManager.isValidDirectory(packageDir, for:  RepositorySpecifier(url: SourceControlURL("https://mycustomdomain/some-package/"))))

            // The following ensure that are actually checking the remote's origin.
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: AbsolutePath(validating: "/"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL("/"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: packageDir)) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(path: packageDir.appending(extension: "git"))) == false)
            #expect(try repositoryManager.isValidDirectory(packageDir, for: RepositorySpecifier(url: SourceControlURL(packageDir.pathString.appending(".git")))) == false)
        }
    }
}
