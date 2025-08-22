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

@testable import SbomSupport
import Basics
import Foundation
import PackageModel
import Testing
import _InternalTestSupport

@Suite(
    .tags(
        .TestSize.small,
        .Feature.Sbom,
    ),
)
struct LicenseExtractionTests {
    
    // MARK: - detectLicenseFromContent Tests
    
    @Test
    func detectLicenseFromContent_MIT() throws {
        let mitLicenseContent = """
        MIT License
        
        Copyright (c) 2023 Test Author
        
        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:
        
        The above copyright notice and this permission notice shall be included in all
        copies or substantial portions of the Software.
        """
        
        let result = detectLicenseFromContent(mitLicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "MIT")
            #expect(license.text?.content == mitLicenseContent)
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_Apache2() throws {
        let apacheLicenseContent = """
        Apache License
        Version 2.0, January 2004
        http://www.apache.org/licenses/
        
        TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION
        
        Licensed under the Apache License, Version 2.0 (the "License");
        you may not use this file except in compliance with the License.
        You may obtain a copy of the License at
        
            http://www.apache.org/licenses/LICENSE-2.0
        
        Unless required by applicable law or agreed to in writing, software
        distributed under the License is distributed on an "AS IS" BASIS,
        WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
        See the License for the specific language governing permissions and
        limitations under the License.
        """
        
        let result = detectLicenseFromContent(apacheLicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "Apache-2.0")
            #expect(license.text?.content == apacheLicenseContent)
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_GPL3() throws {
        let gpl3LicenseContent = """
        GNU GENERAL PUBLIC LICENSE
        Version 3, 29 June 2007
        
        Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
        Everyone is permitted to copy and distribute verbatim copies
        of this license document, but changing it is not allowed.
        
        This program is free software: you can redistribute it and/or modify
        it under the terms of the GNU General Public License as published by
        the Free Software Foundation, either version 3 of the License, or
        (at your option) any later version.
        """
        
        let result = detectLicenseFromContent(gpl3LicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "GPL-3.0")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_GPL2() throws {
        let gpl2LicenseContent = """
        GNU GENERAL PUBLIC LICENSE
        Version 2, June 1991
        
        Copyright (C) 1989, 1991 Free Software Foundation, Inc.,
        51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
        Everyone is permitted to copy and distribute verbatim copies
        of this license document, but changing it is not allowed.
        """
        
        let result = detectLicenseFromContent(gpl2LicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "GPL-2.0")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_BSD3Clause() throws {
        let bsd3LicenseContent = """
        BSD 3-Clause License
        
        Copyright (c) 2023, Test Author
        All rights reserved.
        
        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:
        
        1. Redistributions of source code must retain the above copyright notice, this
           list of conditions and the following disclaimer.
        
        2. Redistributions in binary form must reproduce the above copyright notice,
           this list of conditions and the following disclaimer in the documentation
           and/or other materials provided with the distribution.
        
        3. Neither the name of the copyright holder nor the names of its
           contributors may be used to endorse or promote products derived from
           this software without specific prior written permission.
        """
        
        let result = detectLicenseFromContent(bsd3LicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "BSD-3-Clause")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_BSD2Clause() throws {
        let bsd2LicenseContent = """
        BSD 2-Clause License
        
        Copyright (c) 2023, Test Author
        All rights reserved.
        
        Redistribution and use in source and binary forms, with or without
        modification, are permitted provided that the following conditions are met:
        
        1. Redistributions of source code must retain the above copyright notice, this
           list of conditions and the following disclaimer.
        
        2. Redistributions in binary form must reproduce the above copyright notice,
           this list of conditions and the following disclaimer in the documentation
           and/or other materials provided with the distribution.
        """
        
        let result = detectLicenseFromContent(bsd2LicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "BSD-2-Clause")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_ISC() throws {
        let iscLicenseContent = """
        ISC License
        
        Copyright (c) 2023, Test Author
        
        Permission to use, copy, modify, and/or distribute this software for any
        purpose with or without fee is hereby granted, provided that the above
        copyright notice and this permission notice appear in all copies.
        
        THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
        WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
        MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
        ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
        WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
        ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
        OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
        """
        
        let result = detectLicenseFromContent(iscLicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "ISC")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    @Test
    func detectLicenseFromContent_UnknownLicense() throws {
        let unknownLicenseContent = """
        Custom License
        
        This is a custom license that doesn't match any known patterns.
        You can do whatever you want with this software.
        """
        
        let result = detectLicenseFromContent(unknownLicenseContent)
        
        #expect(result == nil)
    }
    
    @Test
    func detectLicenseFromContent_EmptyContent() throws {
        let result = detectLicenseFromContent("")
        #expect(result == nil)
    }
    
    @Test
    func detectLicenseFromContent_CaseInsensitive() throws {
        let mitLicenseContent = """
        mit license
        
        permission is hereby granted, free of charge, to any person obtaining a copy
        """
        
        let result = detectLicenseFromContent(mitLicenseContent)
        
        #expect(result != nil)
        if case .licenseID(let license) = result {
            #expect(license.id == "MIT")
        } else {
            Issue.record("Expected licenseID case")
        }
    }
    
    // MARK: - extractLicenseFromReadme Tests
    
    @Test
    func extractLicenseFromReadme_LicenseField() throws {
        let readmeContent = """
        # My Awesome Package
        
        This is a great package that does amazing things.
        
        ## License
        
        License: MIT
        
        ## Installation
        
        Install using Swift Package Manager.
        """
        
        let result = extractLicenseFromReadme(readmeContent)
        
        #expect(result == "MIT")
    }
    
    @Test
    func extractLicenseFromReadme_LicensedUnder() throws {
        let readmeContent = """
        # My Package
        
        This package is licensed under Apache-2.0.
        
        ## Usage
        
        Use it like this...
        """
        
        let result = extractLicenseFromReadme(readmeContent)
        
        #expect(result == "APACHE-2.0")
    }
    
    @Test
    func extractLicenseFromReadme_LicenseSuffix() throws {
        let readmeContent = """
        # My Package
        
        This is a GPL-3.0 license package.
        
        ## Features
        
        - Feature 1
        - Feature 2
        """
        
        let result = extractLicenseFromReadme(readmeContent)
        
        #expect(result == "GPL-3.0")
    }
    
    @Test
    func extractLicenseFromReadme_MultipleMatches() throws {
        let readmeContent = """
        # My Package
        
        License: MIT
        
        This package also supports Apache-2.0 license.
        """
        
        let result = extractLicenseFromReadme(readmeContent)
        
        // Should return the first match (MIT)
        #expect(result == "MIT")
    }
    
    @Test
    func extractLicenseFromReadme_NoLicense() throws {
        let readmeContent = """
        # My Package
        
        This is a great package with no license information.
        
        ## Installation
        
        Install using Swift Package Manager.
        """
        
        let result = extractLicenseFromReadme(readmeContent)
        
        #expect(result == nil)
    }
    
    @Test
    func extractLicenseFromReadme_CaseInsensitive() throws {
        let readmeContent = """
        # My Package
        
        license: mit
        """
        
        let result = extractLicenseFromReadme(readmeContent)
        
        #expect(result == "MIT")
    }
    
    @Test
    func extractLicenseFromReadme_AllSupportedLicenses() throws {
        let licenses = ["mit", "apache-2.0", "gpl-3.0", "gpl-2.0", "bsd-3-clause", "bsd-2-clause", "isc"]
        
        for license in licenses {
            let readmeContent = "License: \(license)"
            let result = extractLicenseFromReadme(readmeContent)
            #expect(result == license.uppercased())
        }
    }
    
    // MARK: - extractLicenseInfo Tests
    
    @Test
    func extractLicenseInfo_EmptyLicenses() throws {
        let result = extractLicenseInfo(from: nil as [SBOMLicenseChoice]?)
        
        #expect(result.concluded == "NOASSERTION")
        #expect(result.declared == "NOASSERTION")
    }
    
    @Test
    func extractLicenseInfo_EmptyArray() throws {
        let result = extractLicenseInfo(from: [])
        
        #expect(result.concluded == "NOASSERTION")
        #expect(result.declared == "NOASSERTION")
    }
    
    @Test
    func extractLicenseInfo_SingleExpression() throws {
        let licenses: [SBOMLicenseChoice] = [.expression("MIT")]
        let result = extractLicenseInfo(from: licenses)
        
        #expect(result.concluded == "MIT")
        #expect(result.declared == "MIT")
    }
    
    @Test
    func extractLicenseInfo_SingleLicenseWithId() throws {
        let license = SBOMLicenseID(
            id: "Apache-2.0",
            text: SBOMLicenseText(content: "Apache license content")
        )
        let licenses: [SBOMLicenseChoice] = [.licenseID(license)]
        let result = extractLicenseInfo(from: licenses)
        
        #expect(result.concluded == "Apache-2.0")
        #expect(result.declared == "Apache-2.0")
    }
    
    @Test
    func extractLicenseInfo_SingleLicenseWithNameOnly() throws {
        let license = SBOMLicenseName(
            name: "Custom License",
            text: SBOMLicenseText(content: "Custom license content")
        )
        let licenses: [SBOMLicenseChoice] = [.licenseName(license)]
        let result = extractLicenseInfo(from: licenses)
        
        #expect(result.concluded == "Custom License")
        #expect(result.declared == "Custom License")
    }
    
    @Test
    func extractLicenseInfo_MultipleLicenses() throws {
        let license1 = SBOMLicenseID(
            id: "MIT",
            text: SBOMLicenseText(content: "MIT content")
        )
        let license2 = SBOMLicenseID(
            id: "Apache-2.0",
            text: SBOMLicenseText(content: "Apache content")
        )
        let licenses: [SBOMLicenseChoice] = [
            .licenseID(license1),
            .expression("GPL-3.0"),
            .licenseID(license2)
        ]
        let result = extractLicenseInfo(from: licenses)
        
        #expect(result.concluded == "GPL-3.0 AND MIT AND Apache-2.0")
        #expect(result.declared == "GPL-3.0 AND MIT AND Apache-2.0")
    }
    
    // Note: Test for license without id or name is not possible since SBOMLicenseID
    // requires id and SBOMLicenseName requires name to be provided
}