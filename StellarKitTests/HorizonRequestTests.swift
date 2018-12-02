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
    let txId1 = "87f5afa8145908e921a9a629d6edfe1c0fa97321e897a83474cea4618d6c64be"
    let txId2 = "7febd4efd56fe337fb66ddfbd6b6776b20719e9d49892c7319090364a215a7c0"

    let base = URL(string: "http://localhost:8000")!

    func test_accounts_request() {
        let e = expectation(description: "")

        Endpoint.accounts(account).load(from: base)
            .then({
                XCTAssert($0.id == self.account)
            })
            .error { print($0); XCTFail() }
            .finally { e.fulfill() }

        wait(for: [e], timeout: 3)
    }

    func test_accounts_transactions_request() {
        let e = expectation(description: "")

        Endpoint.accounts(account).transactions().load(from: base)
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

        requestor.load(url: Endpoint.transactions(txId1).url(with: base))
            .then({ (response: Responses.Transaction) in
                XCTAssert(response.id == self.txId1)
            })
            .error { print($0); XCTFail() }
            .finally { e1.fulfill() }

        requestor.load(url: Endpoint.accounts(account).transactions().url(with: base))
            .then({ (response: Responses.Transactions) in
                XCTAssert(response.transactions.filter { $0.id == self.txId2 }.count == 1)
            })
            .error { print($0); XCTFail() }
            .finally { e2.fulfill() }

        wait(for: [e1, e2], timeout: 3)
    }
}
