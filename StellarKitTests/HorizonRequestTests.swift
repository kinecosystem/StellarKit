//
// HorizonRequests.swift
// StellarKitTests
//
// Created by Kin Foundation.
// Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class HorizonRequestsTests: XCTestCase {
    let account = "GBDYQPNVH7DGKD6ZNBTZY5BZNO2GRHAY7KO3U33UZRBXJDVLBF2PCF6M"
    let txId1 = "5abe92b2bd488b310d18cd34f9a9639a3a2fd5f1bc17a4a1451a6ed2f04f472b"
    let txId2 = "358f13f6a5aa17c08e02dcc6c26bd33c5617543a3d4b45cd60e229edb3b19d8a"

    let base = URL(string: "http://localhost:8000")!

    func test_accounts_request() {
        let e = expectation(description: "")

        Endpoint.account(account).load(from: base)
            .then({
                XCTAssert($0.id == self.account)
            })
            .error { print($0); XCTFail() }
            .finally { e.fulfill() }

        wait(for: [e], timeout: 3)
    }

    func test_accounts_transactions_request() {
        let e = expectation(description: "")

        Endpoint.account(account).transactions().load(from: base)
            .then({ (response: Responses.Transactions) in
                XCTAssert(response.transactions.filter { $0.id == self.txId1 }.count == 1)
            })
            .error { print($0); XCTFail() }
            .finally { e.fulfill() }

        wait(for: [e], timeout: 3)
    }

    func test_simultaneous_requests() {
        let e1 = expectation(description: "")
        let e2 = expectation(description: "")

        let requestor = HorizonRequest()

        requestor.load(url: Endpoint.transaction(txId1).url(with: base))
            .then({ (response: Responses.Transaction) in
                XCTAssert(response.id == self.txId1)
            })
            .error { print($0); XCTFail() }
            .finally { e1.fulfill() }

        requestor.load(url: Endpoint.account(account).transactions().url(with: base))
            .then({ (response: Responses.Transactions) in
                XCTAssert(response.transactions.filter { $0.id == self.txId2 }.count == 1)
            })
            .error { print($0); XCTFail() }
            .finally { e2.fulfill() }

        wait(for: [e1, e2], timeout: 3)
    }
}
