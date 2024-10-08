/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2014 - 2017 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import Basics
import Foundation
import Testing

#if os(Windows)
private var windows: Bool { true }
#else
private var windows: Bool { false }
#endif

struct PathTests {
    @Test
    func basics() {
        #expect(AbsolutePath("/").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/a").pathString == (windows ? #"\a"# : "/a"))
        #expect(AbsolutePath("/a/b/c").pathString == (windows ? #"\a\b\c"# : "/a/b/c"))
        #expect(RelativePath(".").pathString == ".")
        #expect(RelativePath("a").pathString == "a")
        #expect(RelativePath("a/b/c").pathString == (windows ? #"a\b\c"# : "a/b/c"))
        #expect(RelativePath("~").pathString == "~")  // `~` is not special
    }

    @Test
    func stringInitialization() throws {
        let abs1 = AbsolutePath("/")
        let abs2 = AbsolutePath(abs1, ".")
        #expect(abs1 == abs2)
        let rel3 = "."
        let abs3 = try AbsolutePath(abs2, validating: rel3)
        #expect(abs2 == abs3)
        let base = AbsolutePath("/base/path")
        let abs4 = AbsolutePath("/a/b/c", relativeTo: base)
        #expect(abs4 == AbsolutePath("/a/b/c"))
        let abs5 = AbsolutePath("./a/b/c", relativeTo: base)
        #expect(abs5 == AbsolutePath("/base/path/a/b/c"))
        let abs6 = AbsolutePath("~/bla", relativeTo: base)  // `~` isn't special
        #expect(abs6 == AbsolutePath("/base/path/~/bla"))
    }

    @Test
    func stringLiteralInitialization() {
        let abs = AbsolutePath("/")
        #expect(abs.pathString == (windows ? #"\"# : "/"))
        let rel1 = RelativePath(".")
        #expect(rel1.pathString == ".")
        let rel2 = RelativePath("~")
        #expect(rel2.pathString == "~")  // `~` is not special
    }

    @Test
    func repeatedPathSeparators() {
        #expect(AbsolutePath("/ab//cd//ef").pathString == (windows ? #"\ab\cd\ef"# : "/ab/cd/ef"))
        #expect(AbsolutePath("/ab///cd//ef").pathString == (windows ? #"\ab\cd\ef"# : "/ab/cd/ef"))
        #expect(RelativePath("ab//cd//ef").pathString == (windows ? #"ab\cd\ef"# : "ab/cd/ef"))
        #expect(RelativePath("ab//cd///ef").pathString == (windows ? #"ab\cd\ef"# : "ab/cd/ef"))
    }

    @Test
    func trailingPathSeparators() {
        #expect(AbsolutePath("/ab/cd/ef/").pathString == (windows ? #"\ab\cd\ef"# : "/ab/cd/ef"))
        #expect(AbsolutePath("/ab/cd/ef//").pathString == (windows ? #"\ab\cd\ef"# : "/ab/cd/ef"))
        #expect(RelativePath("ab/cd/ef/").pathString == (windows ? #"ab\cd\ef"# : "ab/cd/ef"))
        #expect(RelativePath("ab/cd/ef//").pathString == (windows ? #"ab\cd\ef"# : "ab/cd/ef"))
    }

    @Test
    func dotPathComponents() {
        #expect(AbsolutePath("/ab/././cd//ef").pathString == "/ab/cd/ef")
        #expect(AbsolutePath("/ab/./cd//ef/.").pathString == "/ab/cd/ef")
        #expect(RelativePath("ab/./cd/././ef").pathString == "ab/cd/ef")
        #expect(RelativePath("ab/./cd/ef/.").pathString == "ab/cd/ef")
    }

    @Test
    func dotDotPathComponents() {
        #expect(AbsolutePath("/..").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/../../../../..").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/abc/..").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/abc/../..").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/../abc").pathString == (windows ? #"\abc"# : "/abc"))
        #expect(AbsolutePath("/../abc/..").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/../abc/../def").pathString == (windows ? #"\def"# : "/def"))
        #expect(RelativePath("..").pathString == "..")
        #expect(RelativePath("../..").pathString == "../..")
        #expect(RelativePath(".././..").pathString == "../..")
        #expect(RelativePath("../abc/..").pathString == "..")
        #expect(RelativePath("../abc/.././").pathString == "..")
        #expect(RelativePath("abc/..").pathString == ".")
    }

    @Test
    func combinationsAndEdgeCases() {
        #expect(AbsolutePath("///").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/./").pathString == (windows ? #"\"# : "/"))
        #expect(RelativePath("").pathString == ".")
        #expect(RelativePath(".").pathString == ".")
        #expect(RelativePath("./abc").pathString == "abc")
        #expect(RelativePath("./abc/").pathString == "abc")
        #expect(RelativePath("./abc/../bar").pathString == "bar")
        #expect(RelativePath("foo/../bar").pathString == "bar")
        #expect(RelativePath("foo///..///bar///baz").pathString == "bar/baz")
        #expect(RelativePath("foo/../bar/./").pathString == "bar")
        #expect(RelativePath("../abc/def/").pathString == "../abc/def")
        #expect(RelativePath("././././.").pathString == ".")
        #expect(RelativePath("./././../.").pathString == "..")
        #expect(RelativePath("./").pathString == ".")
        #expect(RelativePath(".//").pathString == ".")
        #expect(RelativePath("./.").pathString == ".")
        #expect(RelativePath("././").pathString == ".")
        #expect(RelativePath("../").pathString == "..")
        #expect(RelativePath("../.").pathString == "..")
        #expect(RelativePath("./..").pathString == "..")
        #expect(RelativePath("./../.").pathString == "..")
        #expect(RelativePath("./////../////./////").pathString == "..")
        #expect(RelativePath("../a").pathString == (windows ? #"..\a"# : "../a"))
        #expect(RelativePath("../a/..").pathString == "..")
        #expect(RelativePath("a/..").pathString == ".")
        #expect(RelativePath("a/../////../////./////").pathString == "..")
    }

    @Test
    func directoryNameExtraction() {
        #expect(AbsolutePath("/").dirname == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/a").dirname == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/./a").dirname == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/../..").dirname == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/ab/c//d/").dirname == (windows ? #"\ab\c"# : "/ab/c"))
        #expect(RelativePath("ab/c//d/").dirname == (windows ? #"ab\c"# : "ab/c"))
        #expect(RelativePath("../a").dirname == "..")
        #expect(RelativePath("../a/..").dirname == ".")
        #expect(RelativePath("a/..").dirname == ".")
        #expect(RelativePath("./..").dirname == ".")
        #expect(RelativePath("a/../////../////./////").dirname == ".")
        #expect(RelativePath("abc").dirname == ".")
        #expect(RelativePath("").dirname == ".")
        #expect(RelativePath(".").dirname == ".")
    }

    @Test
    func baseNameExtraction() {
        #expect(AbsolutePath("/").basename == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/a").basename == "a")
        #expect(AbsolutePath("/./a").basename == "a")
        #expect(AbsolutePath("/../..").basename == "/")
        #expect(RelativePath("../..").basename == "..")
        #expect(RelativePath("../a").basename == "a")
        #expect(RelativePath("../a/..").basename == "..")
        #expect(RelativePath("a/..").basename == ".")
        #expect(RelativePath("./..").basename == "..")
        #expect(RelativePath("a/../////../////./////").basename == "..")
        #expect(RelativePath("abc").basename == "abc")
        #expect(RelativePath("").basename == ".")
        #expect(RelativePath(".").basename == ".")
    }

    @Test
    func baseNameWithoutExt() {
        #expect(AbsolutePath("/").basenameWithoutExt == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/a").basenameWithoutExt == "a")
        #expect(AbsolutePath("/./a").basenameWithoutExt == "a")
        #expect(AbsolutePath("/../..").basenameWithoutExt == "/")
        #expect(RelativePath("../..").basenameWithoutExt == "..")
        #expect(RelativePath("../a").basenameWithoutExt == "a")
        #expect(RelativePath("../a/..").basenameWithoutExt == "..")
        #expect(RelativePath("a/..").basenameWithoutExt == ".")
        #expect(RelativePath("./..").basenameWithoutExt == "..")
        #expect(RelativePath("a/../////../////./////").basenameWithoutExt == "..")
        #expect(RelativePath("abc").basenameWithoutExt == "abc")
        #expect(RelativePath("").basenameWithoutExt == ".")
        #expect(RelativePath(".").basenameWithoutExt == ".")

        #expect(AbsolutePath("/a.txt").basenameWithoutExt == "a")
        #expect(AbsolutePath("/./a.txt").basenameWithoutExt == "a")
        #expect(RelativePath("../a.bc").basenameWithoutExt == "a")
        #expect(RelativePath("abc.swift").basenameWithoutExt == "abc")
        #expect(RelativePath("../a.b.c").basenameWithoutExt == "a.b")
        #expect(RelativePath("abc.xyz.123").basenameWithoutExt == "abc.xyz")
    }

    @Test
    func suffixExtraction() {
        #expect(RelativePath("a").suffix == nil)
        #expect(RelativePath("a").extension == nil)
        #expect(RelativePath("a.").suffix == nil)
        #expect(RelativePath("a.").extension == nil)
        #expect(RelativePath(".a").suffix == nil)
        #expect(RelativePath(".a").extension == nil)
        #expect(RelativePath("").suffix == nil)
        #expect(RelativePath("").extension == nil)
        #expect(RelativePath(".").suffix == nil)
        #expect(RelativePath(".").extension == nil)
        #expect(RelativePath("..").suffix == nil)
        #expect(RelativePath("..").extension == nil)
        #expect(RelativePath("a.foo").suffix == ".foo")
        #expect(RelativePath("a.foo").extension == "foo")
        #expect(RelativePath(".a.foo").suffix == ".foo")
        #expect(RelativePath(".a.foo").extension == "foo")
        #expect(RelativePath(".a.foo.bar").suffix == ".bar")
        #expect(RelativePath(".a.foo.bar").extension == "bar")
        #expect(RelativePath("a.foo.bar").suffix == ".bar")
        #expect(RelativePath("a.foo.bar").extension == "bar")
        #expect(RelativePath(".a.foo.bar.baz").suffix == ".baz")
        #expect(RelativePath(".a.foo.bar.baz").extension == "baz")
    }

    @Test
    func parentDirectory() {
        #expect(AbsolutePath("/").parentDirectory == AbsolutePath("/"))
        #expect(AbsolutePath("/").parentDirectory.parentDirectory == AbsolutePath("/"))
        #expect(AbsolutePath("/bar").parentDirectory == AbsolutePath("/"))
        #expect(AbsolutePath("/bar/../foo/..//").parentDirectory.parentDirectory == AbsolutePath("/"))
        #expect(AbsolutePath("/bar/../foo/..//yabba/a/b").parentDirectory.parentDirectory == AbsolutePath("/yabba"))
    }

    @Test
    @available(*, deprecated)
    func concatenation() {
        #expect(AbsolutePath(AbsolutePath("/"), RelativePath("")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath(AbsolutePath("/"), RelativePath(".")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath(AbsolutePath("/"), RelativePath("..")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath(AbsolutePath("/"), RelativePath("bar")).pathString == (windows ? #"\bar"# : "/bar"))
        #expect(AbsolutePath(AbsolutePath("/foo/bar"), RelativePath("..")).pathString == (windows ? #"\foo"# : "/foo"))
        #expect(AbsolutePath(AbsolutePath("/bar"), RelativePath("../foo")).pathString == (windows ? #"\foo"# : "/foo"))
        #expect(AbsolutePath(AbsolutePath("/bar"), RelativePath("../foo/..//")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath(AbsolutePath("/bar/../foo/..//yabba/"), RelativePath("a/b")).pathString == (windows ? #"\yabba\a\b"# : "/yabba/a/b"))

        #expect(AbsolutePath("/").appending(RelativePath("")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/").appending(RelativePath(".")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/").appending(RelativePath("..")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/").appending(RelativePath("bar")).pathString == (windows ? #"\bar"# : "/bar"))
        #expect(AbsolutePath("/foo/bar").appending(RelativePath("..")).pathString == (windows ? #"\foo"# : "/foo"))
        #expect(AbsolutePath("/bar").appending(RelativePath("../foo")).pathString == (windows ? #"\foo"# : "/foo"))
        #expect(AbsolutePath("/bar").appending(RelativePath("../foo/..//")).pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/bar/../foo/..//yabba/").appending(RelativePath("a/b")).pathString == (windows ? #"\yabba\a\b"# : "/yabba/a/b"))

        #expect(AbsolutePath("/").appending(component: "a").pathString == (windows ? #"\a"# : "/a"))
        #expect(AbsolutePath("/a").appending(component: "b").pathString == (windows ? #"\a\b"# : "/a/b"))
        #expect(AbsolutePath("/").appending(components: "a", "b").pathString == (windows ? #"\a\b"# : "/a/b"))
        #expect(AbsolutePath("/a").appending(components: "b", "c").pathString == (windows ? #"\a\b\c"# : "/a/b/c"))

        #expect(AbsolutePath("/a/b/c").appending(components: "", "c").pathString == (windows ? #"\a\b\c\c"# : "/a/b/c/c"))
        #expect(AbsolutePath("/a/b/c").appending(components: "").pathString == (windows ? #"\a\b\c"# : "/a/b/c"))
        #expect(AbsolutePath("/a/b/c").appending(components: ".").pathString == (windows ? #"\a\b\c"# : "/a/b/c"))
        #expect(AbsolutePath("/a/b/c").appending(components: "..").pathString == (windows ? #"\a\b"# : "/a/b"))
        #expect(AbsolutePath("/a/b/c").appending(components: "..", "d").pathString == (windows ? #"\a\b\d"# : "/a/b/d"))
        #expect(AbsolutePath("/").appending(components: "..").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/").appending(components: ".").pathString == (windows ? #"\"# : "/"))
        #expect(AbsolutePath("/").appending(components: "..", "a").pathString == (windows ? #"\a"# : "/a"))

        #expect(RelativePath("hello").appending(components: "a", "b", "c", "..").pathString == (windows ? #"hello\a\b"# : "hello/a/b"))
        #expect(RelativePath("hello").appending(RelativePath("a/b/../c/d")).pathString == (windows ? #"hello\a\c\d"# : "hello/a/c/d"))
    }

    @Test
    func pathComponents() {
        #expect(AbsolutePath("/").components == ["/"])
        #expect(AbsolutePath("/.").components == ["/"])
        #expect(AbsolutePath("/..").components == ["/"])
        #expect(AbsolutePath("/bar").components == ["/", "bar"])
        #expect(AbsolutePath("/foo/bar/..").components == ["/", "foo"])
        #expect(AbsolutePath("/bar/../foo").components == ["/", "foo"])
        #expect(AbsolutePath("/bar/../foo/..//").components == ["/"])
        #expect(AbsolutePath("/bar/../foo/..//yabba/a/b/").components == ["/", "yabba", "a", "b"])

        #expect(RelativePath("").components == ["."])
        #expect(RelativePath(".").components == ["."])
        #expect(RelativePath("..").components == [".."])
        #expect(RelativePath("bar").components == ["bar"])
        #expect(RelativePath("foo/bar/..").components == ["foo"])
        #expect(RelativePath("bar/../foo").components == ["foo"])
        #expect(RelativePath("bar/../foo/..//").components == ["."])
        #expect(RelativePath("bar/../foo/..//yabba/a/b/").components == ["yabba", "a", "b"])
        #expect(RelativePath("../..").components == ["..", ".."])
        #expect(RelativePath(".././/..").components == ["..", ".."])
        #expect(RelativePath("../a").components == ["..", "a"])
        #expect(RelativePath("../a/..").components == [".."])
        #expect(RelativePath("a/..").components == ["."])
        #expect(RelativePath("./..").components == [".."])
        #expect(RelativePath("a/../////../////./////").components == [".."])
        #expect(RelativePath("abc").components == ["abc"])
    }

    @Test
    func relativePathFromAbsolutePaths() {
        #expect(AbsolutePath("/").relative(to: AbsolutePath("/")) == RelativePath("."));
        #expect(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/")) == RelativePath("a/b/c/d"));
        #expect(AbsolutePath("/").relative(to: AbsolutePath("/a/b/c")) == RelativePath("../../.."));
        #expect(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/a/b")) == RelativePath("c/d"));
        #expect(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/a/b/c")) == RelativePath("d"));
        #expect(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/a/c/d")) == RelativePath("../../b/c/d"));
        #expect(AbsolutePath("/a/b/c/d").relative(to: AbsolutePath("/b/c/d")) == RelativePath("../../../a/b/c/d"));
    }

    @Test
    func comparison() {
        #expect(AbsolutePath("/") <= AbsolutePath("/"));
        #expect(AbsolutePath("/abc") < AbsolutePath("/def"));
        #expect(AbsolutePath("/2") <= AbsolutePath("/2.1"));
        #expect(AbsolutePath("/3.1") > AbsolutePath("/2"));
        #expect(AbsolutePath("/2") >= AbsolutePath("/2"));
        #expect(AbsolutePath("/2.1") >= AbsolutePath("/2"));
    }

    @Test
    func ancestry() {
        #expect(AbsolutePath("/a/b/c/d/e/f").isDescendantOfOrEqual(to: AbsolutePath("/a/b/c/d")))
        #expect(AbsolutePath("/a/b/c/d/e/f.swift").isDescendantOfOrEqual(to: AbsolutePath("/a/b/c")))
        #expect(AbsolutePath("/").isDescendantOfOrEqual(to: AbsolutePath("/")))
        #expect(AbsolutePath("/foo/bar").isDescendantOfOrEqual(to: AbsolutePath("/")))
        #expect(!AbsolutePath("/foo/bar").isDescendantOfOrEqual(to: AbsolutePath("/foo/bar/baz")))
        #expect(!AbsolutePath("/foo/bar").isDescendantOfOrEqual(to: AbsolutePath("/bar")))

        #expect(!AbsolutePath("/foo/bar").isDescendant(of: AbsolutePath("/foo/bar")))
        #expect(AbsolutePath("/foo/bar").isDescendant(of: AbsolutePath("/foo")))

        #expect(AbsolutePath("/a/b/c/d").isAncestorOfOrEqual(to: AbsolutePath("/a/b/c/d/e/f")))
        #expect(AbsolutePath("/a/b/c").isAncestorOfOrEqual(to: AbsolutePath("/a/b/c/d/e/f.swift")))
        #expect(AbsolutePath("/").isAncestorOfOrEqual(to: AbsolutePath("/")))
        #expect(AbsolutePath("/").isAncestorOfOrEqual(to: AbsolutePath("/foo/bar")))
        #expect(!AbsolutePath("/foo/bar/baz").isAncestorOfOrEqual(to: AbsolutePath("/foo/bar")))
        #expect(!AbsolutePath("/bar").isAncestorOfOrEqual(to: AbsolutePath("/foo/bar")))

        #expect(!AbsolutePath("/foo/bar").isAncestor(of: AbsolutePath("/foo/bar")))
        #expect(AbsolutePath("/foo").isAncestor(of: AbsolutePath("/foo/bar")))
    }

    @Test
    func absolutePathValidation() {
        #expect(throws: Never.self) {
            try AbsolutePath(validating: "/a/b/c/d")
        }

        #expect {try AbsolutePath(validating: "~/a/b/d")} throws: { error in
            ("\(error)" == "invalid absolute path '~/a/b/d'; absolute path must begin with '/'")
        }

        #expect {try AbsolutePath(validating: "a/b/d") } throws: { error in
            ("\(error)" == "invalid absolute path 'a/b/d'")
        }
    }

    @Test
    func relativePathValidation() {
        #expect(throws: Never.self) {
            try RelativePath(validating: "a/b/c/d")
        }

        #expect {try RelativePath(validating: "/a/b/d")} throws: { error in
            ("\(error)" == "invalid relative path '/a/b/d'; relative path should not begin with '/'")
            //XCTAssertEqual("\(error)", "invalid relative path '/a/b/d'; relative path should not begin with '/' or '~'")
        }

    }

    @Test
    func codable() throws {
        struct Foo: Codable, Equatable {
            var path: AbsolutePath
        }

        struct Bar: Codable, Equatable {
            var path: RelativePath
        }

        struct Baz: Codable, Equatable {
            var path: String
        }

        do {
            let foo = Foo(path: "/path/to/foo")
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            #expect(foo == decodedFoo)
        }

        do {
            let foo = Foo(path: "/path/to/../to/foo")
            let data = try JSONEncoder().encode(foo)
            let decodedFoo = try JSONDecoder().decode(Foo.self, from: data)
            #expect(foo == decodedFoo)
            #expect(foo.path.pathString == (windows ? #"\path\to\foo"# : "/path/to/foo"))
            #expect(decodedFoo.path.pathString == (windows ? #"\path\to\foo"# : "/path/to/foo"))
        }

        do {
            let bar = Bar(path: "path/to/bar")
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            #expect(bar == decodedBar)
        }

        do {
            let bar = Bar(path: "path/to/../to/bar")
            let data = try JSONEncoder().encode(bar)
            let decodedBar = try JSONDecoder().decode(Bar.self, from: data)
            #expect(bar == decodedBar)
            #expect(bar.path.pathString == "path/to/bar")
            #expect(decodedBar.path.pathString == "path/to/bar")
        }

        do {
            let data = try JSONEncoder().encode(Baz(path: ""))
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(Foo.self, from: data)
            }
            #expect(throws: Never.self) {
                try JSONDecoder().decode(Bar.self, from: data)
            } // empty string is a valid relative path
        }

        do {
            let data = try JSONEncoder().encode(Baz(path: "foo"))
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(Foo.self, from: data)
            }
        }

        do {
            let data = try JSONEncoder().encode(Baz(path: "/foo"))
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(Bar.self, from: data)
            }
        }
    }

    // FIXME: We also need tests for join() operations.

    // FIXME: We also need tests for dirname, basename, suffix, etc.

    // FIXME: We also need test for stat() operations.
}
