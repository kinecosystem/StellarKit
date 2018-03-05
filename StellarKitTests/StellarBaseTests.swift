//
//  StellarBaseTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit
import KinUtil

struct MockStellarAccount: Account {
    var publicKey: String? {
        return KeyUtils.base32(publicKey: keyPair.publicKey)
    }

    let keyPair: Sign.KeyPair

    init(seedStr: String) {
        keyPair = TestKeyUtils.keyPair(from: seedStr)!

        let secretKey = keyPair.secretKey

        sign = { message in
            return try TestKeyUtils.sign(message: message,
                                         signingKey: secretKey)
        }
    }

    var sign: ((Data) throws -> Data)?

    init() {
        self.init(seedStr: KeyUtils.base32(seed: TestKeyUtils.seed()!))
    }
}

class StellarBaseTests: XCTestCase {
    var endpoint: String { return "override me" }
    
    lazy var stellar: Stellar =
        Stellar(node: StellarNode(baseURL: URL(string: endpoint)!),
                asset: Asset(assetCode: "KIN",
                             issuer: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7"))

    var account: Account!
    var account2: Account!
    var issuer: Account!

    override func setUp() {
        super.setUp()

        account = MockStellarAccount()
        account2 = MockStellarAccount()
        issuer = MockStellarAccount(seedStr: "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35")
    }

    override func tearDown() {
        super.tearDown()
    }

    func fund(account: String) -> Promise<String> {
        let funderPK = "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7"
        let funderSK = "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35"

        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: funderPK)))

        let funder = MockStellarAccount(seedStr: funderSK)

        return stellar.sequence(account: funderPK)
            .then { sequence in
                let tx = Transaction(sourceAccount: sourcePK,
                                     seqNum: sequence + 1,
                                     timeBounds: nil,
                                     memo: .MEMO_NONE,
                                     operations: [Operation.createAccountOp(destination: account,
                                                                            balance: 10 * 10000000)])

                let envelope = try self.stellar.sign(transaction: tx,
                                                     signer: funder)

                return self.stellar.postTransaction(baseURL: self.stellar.node.baseURL, envelope: envelope)
        }
    }

    func test_trust() {
        let e = expectation(description: "")

        fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account)
            }
            .then { _ in
                e.fulfill()
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

    func test_double_trust() {
        let e = expectation(description: "")

        fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account)
            }
            .then { txHash -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account)
            }
            .then { _ in
                e.fulfill()
            }
            .error { error in
                XCTAssertTrue(false, "Failed to trust asset: \(error)")
                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

    func test_payment_to_untrusting_account() {
        let e = expectation(description: "")

        stellar.payment(source: account,
                        destination: account2.publicKey!,
                        amount: 1)
            .then { txHash -> Void in
                XCTAssertTrue(false, "Expected error!")
                e.fulfill()
            }
            .error { error in
                if case StellarError.destinationNotReadyForAsset = error {

                }
                else {
                    XCTAssertTrue(false, "Received unexpected error: \(error)!")
                }

                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

    func test_payment_from_unfunded_account() {
        let e = expectation(description: "")

        fund(account: account2.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account2)
            }
            .then { txHash -> Promise<String> in
                return self.stellar.payment(source: self.account,
                                            destination: self.account2.publicKey!,
                                            amount: 1)
            }
            .then { txHash -> Void in
                XCTAssertTrue(false, "Expected error!")
                e.fulfill()
            }
            .error { error in
                if case StellarError.missingSequence = error {

                }
                else {
                    XCTAssertTrue(false, "Received unexpected error: \(error)!")
                }

                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

    func test_payment_from_empty_account() {
        let e = expectation(description: "")

        let stellar = self.stellar

        fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.fund(account: self.account2.publicKey!)
            }
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account)
            }
            .then { txHash -> Promise<String> in
                return stellar.trust(asset: stellar.asset,
                                     account: self.account2)
            }
            .then { txHash -> Promise<String> in
                return stellar.payment(source: self.account,
                                       destination: self.account2.publicKey!,
                                       amount: 1)
            }
            .then { txHash -> Void in
                XCTAssertTrue(false, "Expected error!")
                e.fulfill()
            }
            .error { error in
                if case PaymentError.PAYMENT_UNDERFUNDED = error {

                }
                else {
                    XCTAssertTrue(false, "Received unexpected error: \(error)!")
                }

                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

    func test_payment_to_trusting_account() {
        let e = expectation(description: "")

        fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account)
            }
            .then { txHash -> Promise<String> in
                return self.stellar.payment(source: self.issuer,
                                            destination: self.account.publicKey!,
                                            amount: 1)
            }
            .then { _ in
                e.fulfill()
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

    func test_balance() {
        let e = expectation(description: "")

        fund(account: account.publicKey!)
            .then { txHash -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account)
            }
            .then { txHash -> Promise<Decimal> in
                return self.stellar.balance(account: self.account.publicKey!)
            }
            .then { _ in
                e.fulfill()
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }

}
