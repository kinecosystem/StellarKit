//
//  PromiseTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class PromiseTests: XCTestCase {

    struct TestError: Error {
        let m: String

        init(_ m: String) {
            self.m = m
        }
    }

    func asyncPromise(_ x: Int) -> Promise<Int> {
        let p = Promise<Int>()

        DispatchQueue(label: "").async {
            p.signal(x)
        }

        return p
    }

    func asyncError(_ m: String) -> Promise<Int> {
        let p = Promise<Int>()

        DispatchQueue(label: "").async {
            p.signal(TestError(m))
        }

        return p
    }

    func test_async_then() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Void in
                XCTAssertEqual(x, Int?(1))
                e.fulfill()
            }
            .error { error in
                XCTAssert(false, "Shouldn't reach here.")
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_error() {
        let e = expectation(description: "")

        asyncError("a")
            .then { _ -> Void in
                XCTAssert(false, "Shouldn't reach here.")
                e.fulfill()
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")
                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_error_with_transform() {
        let e = expectation(description: "")

        asyncError("a")
            .then { _ -> Void in
                XCTAssert(false, "Shouldn't reach here.")
                e.fulfill()
            }
            .transformError { _ in
                return TestError("b")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "b")
                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_chain() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Promise<Int> in
                return self.asyncPromise(2)
            }
            .then { x -> Void in
                XCTAssertEqual(x, Int?(2))

                e.fulfill()
            }
            .error { error in
                XCTAssert(false, "Shouldn't reach here.")
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_then_returning_error() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Promise<Int> in
                throw TestError("a")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")

                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_then_returning_error_with_transform() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Promise<Int> in
                throw TestError("a")
            }
            .transformError { _ in
                return TestError("b")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "b")

                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_chain_with_first_link_returning_error() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Promise<Int> in
                XCTAssertEqual(x, Int?(1))

                throw TestError("a")
            }
            .then { _ -> Void in
                XCTAssert(false, "Shouldn't reach here.")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")

                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_chain_with_last_link_returning_error() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Promise<Int> in
                return self.asyncPromise(2)
            }
            .then { _ -> Promise<Int> in
                throw TestError("a")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")

                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

}
