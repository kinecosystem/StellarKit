//
//  PromiseTests.swift
//  StellarKitTests
//
//  Created by Avi Shevin on 31/01/2018.
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

    func asyncPromise(_ x: Int) -> Promise {
        let p = Promise()

        DispatchQueue(label: "").async {
            p.signal(x)
        }

        return p
    }

    func asyncError(_ m: String) -> Promise {
        let p = Promise()

        DispatchQueue(label: "").async {
            p.signal(TestError(m))
        }

        return p
    }

    func test_async_then() {
        asyncPromise(1)
            .then { x -> Void in
                XCTAssertEqual(x as? Int, Int?(1))
        }
            .error { error in
                XCTAssert(false, "Shouldn't reach here.")
        }
    }

    func test_async_error() {
        asyncError("a")
            .then { _ -> Void in
                XCTAssert(false, "Shouldn't reach here.")
        }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")
        }
    }

    func test_async_chain() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Any? in
                return self.asyncPromise(2)
            }
            .then { x -> Void in
                XCTAssertEqual(x as? Int, Int?(2))

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
            .then { x -> Any? in
                XCTAssertEqual(x as? Int, Int?(1))

                return TestError("a")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")

                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

    func test_async_chain_with_first_link_returning_error() {
        let e = expectation(description: "")

        asyncPromise(1)
            .then { x -> Any? in
                XCTAssertEqual(x as? Int, Int?(1))

                return TestError("a")
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
            .then { x -> Any? in
                return self.asyncPromise(2)
            }
            .then { _ -> Any? in
                return TestError("a")
            }
            .error { error in
                XCTAssertEqual((error as? TestError)?.m, "a")

                e.fulfill()
        }

        wait(for: [e], timeout: 1.0)
    }

}
