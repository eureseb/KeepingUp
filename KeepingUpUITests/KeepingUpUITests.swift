//
//  KeepingUpUITests.swift
//  KeepingUpUITests
//
//  Created by EureseB on 3/20/26.
//

import XCTest

final class KeepingUpUITests: XCTestCase {

    @MainActor
    func testReturnKeyAddsSingleTask() throws {
        throw XCTSkip("Menu bar extra controls are not reliably exposed to macOS UI automation in this environment.")
    }
}
