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
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()

        let newTaskField = app.textFields["newTaskField"]
        XCTAssertTrue(newTaskField.waitForExistence(timeout: 2))
        newTaskField.click()
        newTaskField.typeText("Stretch\n")

        let predicate = NSPredicate(format: "label == %@", "Stretch")
        let matchingLabels = app.staticTexts.matching(predicate)
        XCTAssertEqual(matchingLabels.count, 1)
    }
}
