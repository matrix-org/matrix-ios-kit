/*
 Copyright 2021 The Matrix.org Foundation C.I.C

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import XCTest

@testable import MatrixKit

class MXKRoomDataSourceTests: XCTestCase {

    func testDestroyRemovesAllBubbles() {
        let dataSource = StubMXKRoomDataSource()
        dataSource.destroy()
        XCTAssert(dataSource.getBubbles()?.isEmpty != false)
    }

    func testDestroyDeallocatesAllBubbles() throws {
        let dataSource = StubMXKRoomDataSource()
        weak var first = try XCTUnwrap(dataSource.getBubbles()?.first)
        weak var last = try XCTUnwrap(dataSource.getBubbles()?.last)
        dataSource.destroy()
        XCTAssertNil(first)
        XCTAssertNil(last)
    }

}

private final class StubMXKRoomDataSource: MXKRoomDataSource {

    override init() {
        super.init()

        let data1 = MXKRoomBubbleCellData()
        let data2 = MXKRoomBubbleCellData()
        let data3 = MXKRoomBubbleCellData()

        data1.nextCollapsableCellData = data2
        data2.prevCollapsableCellData = data1
        data2.nextCollapsableCellData = data3
        data3.prevCollapsableCellData = data2

        replaceBubbles([data1, data2, data3])
    }

}
