//
//  StellarUnitTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

struct MockStellarAccount: Account {
    var publicKey: String? {
        return KeyUtils.base32(publicKey: keyPair.publicKey)
    }

    let keyPair: Sign.KeyPair

    init(seedStr: String) {
        keyPair = KeyUtils.keyPair(from: seedStr)!
    }

    func sign(message: Data, passphrase: String) throws -> Data {
        return try KeyUtils.sign(message: message,
                                 signingKey: keyPair.secretKey)
    }
}

class StellarUnitTests: XCTestCase {
    let passphrase = "a phrase"

    var horizonMock: HorizonMock? = nil

    let kinAsset = Asset(assetCode: "KIN",
                         issuer: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7")!

    let stellar = Stellar(baseURL: URL(string: "https://horizon")!,
                          asset: Asset(assetCode: "KIN",
                                       issuer: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7"))
    
    var account = MockStellarAccount(seedStr: "SBVUHZRTCKG7NS54KIEFGEWSW7VS6YRGSRSH3S5GNQ52GUVE7RM4KPEH")
    var account2 = MockStellarAccount(seedStr: "SCXKOLLQIAODKV6PXNAH4ZZWKIPK3DUAWUAGEC7I6HEL4Y7ZCWOUWWLU")
    var issuer = MockStellarAccount(seedStr: "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35")

    var registered = false

    override func setUp() {
        super.setUp()

        if !registered {
            URLProtocol.registerClass(HTTPMock.self)
            registered = true
        }

        horizonMock = HorizonMock()

        let nBalance = Balance(asset: .ASSET_TYPE_NATIVE, amount: 10000000)
        let kBalance = Balance(asset: kinAsset, amount: 10000000)

        horizonMock?.inject(account: MockAccount(balances: [nBalance, kBalance]),
                            key: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7")
    }
    
    override func tearDown() {
        horizonMock = nil

        super.tearDown()
    }

    func test_trust() {
        let e = expectation(description: "")

        self.stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            self.stellar.trust(asset: self.stellar.asset,
                               account: self.account,
                               passphrase: self.passphrase) { txHash, error in
                                if let error = error {
                                    XCTAssertTrue(false, "Failed to trust asset: \(error)")
                                }

                                e.fulfill()
            }
        }

        wait(for: [e], timeout: 60)
    }

    func test_double_trust() {
        let e = expectation(description: "")

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            self.stellar.trust(asset: self.stellar.asset,
                               account: self.account,
                               passphrase: self.passphrase) { txHash, error in
                                if let error = error {
                                    XCTAssertTrue(false, "Failed to trust asset: \(error)")

                                    e.fulfill()

                                    return
                                }

                                self.stellar.trust(asset: self.stellar.asset,
                                                   account: self.account,
                                                   passphrase: self.passphrase) { txHash, error in
                                                    if let error = error {
                                                        XCTAssertTrue(false, "Received unexpected error: \(error)!")
                                                    }

                                                    e.fulfill()
                                }
            }
        }

        wait(for: [e], timeout: 60)
    }

    func test_payment_to_untrusting_account() {
        let e = expectation(description: "")

        stellar.payment(source: account,
                        destination: account2.publicKey!,
                        amount: 1,
                        passphrase: passphrase) { txHash, error in
                            defer {
                                e.fulfill()
                            }

                            guard let error = error else {
                                XCTAssertTrue(false, "Expected error!")

                                return
                            }

                            guard let stellarError = error as? StellarError else {
                                XCTAssertTrue(false, "Received unexpected error: \(error)!")

                                return
                            }
                            switch stellarError {
                            case .destinationNotReadyForAsset: break
                            default:
                                XCTAssertTrue(false, "Received unexpected error: \(error)!")
                            }
        }

        wait(for: [e], timeout: 60)
    }

    func test_payment_from_unfunded_account() {
        let e = expectation(description: "")

        stellar.fund(account: account2.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            self
                .stellar
                .trust(asset: self.stellar.asset,
                       account: self.account2,
                       passphrase: self.passphrase) { txHash, error in
                        if let error = error {
                            XCTAssertTrue(false, "Failed to trust asset: \(error)")
                            e.fulfill()

                            return
                        }

                        self
                            .stellar
                            .payment(source: self.account,
                                     destination: self.account2.publicKey!,
                                     amount: 1,
                                     passphrase: self.passphrase) { txHash, error in
                                        defer {
                                            e.fulfill()
                                        }

                                        guard let error = error else {
                                            XCTAssertTrue(false, "Expected error!")

                                            return
                                        }

                                        guard let stellarError = error as? StellarError else {
                                            XCTAssertTrue(false, "Received unexpected error: \(error)!")

                                            return
                                        }
                                        switch stellarError {
                                        case .missingSequence: break
                                        default:
                                            XCTAssertTrue(false, "Received unexpected error: \(error)!")
                                        }
                        }
            }
        }

        wait(for: [e], timeout: 60)
    }

    func test_payment_from_empty_account() {
        let e = expectation(description: "")
        let stellar = self.stellar

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            stellar.fund(account: self.account2.publicKey!) { success in
                if !success {
                    XCTAssertTrue(false, "Unable to fund account!")

                    e.fulfill()

                    return
                }

                stellar
                    .trust(asset: stellar.asset,
                           account: self.account,
                              passphrase: self.passphrase) { txHash, error in
                                if let error = error {
                                    XCTAssertTrue(false, "Failed to trust asset: \(error)")
                                    e.fulfill()

                                    return
                                }

                                stellar
                                    .trust(asset: stellar.asset,
                                           account: self.account2,
                                              passphrase: self.passphrase) { txHash, error in
                                                if let error = error {
                                                    XCTAssertTrue(false, "Failed to trust asset: \(error)")
                                                    e.fulfill()

                                                    return
                                                }

                                                stellar
                                                    .payment(source: self.account,
                                                             destination: self.account2.publicKey!,
                                                             amount: 1,
                                                             passphrase: self.passphrase) { txHash, error in
                                                                defer {
                                                                    e.fulfill()
                                                                }

                                                                guard let error = error else {
                                                                    XCTAssertTrue(false, "Expected error!")

                                                                    return
                                                                }

                                                                guard let paymentError = error as? PaymentError else {
                                                                    XCTAssertTrue(false, "Received unexpected error: \(error)!")

                                                                    return
                                                                }
                                                                switch paymentError {
                                                                case .PAYMENT_UNDERFUNDED: break
                                                                default:
                                                                    XCTAssertTrue(false, "Received unexpected error: \(error)!")
                                                                }
                                                }
                                }
                }
            }
        }

        wait(for: [e], timeout: 60)
    }

    func test_payment_to_trusting_account() {
        let e = expectation(description: "")
        let stellar = self.stellar

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            stellar
                .trust(asset: stellar.asset,
                       account: self.account,
                          passphrase: self.passphrase) { txHash, error in
                            if let error = error {
                                XCTAssertTrue(false, "Failed to trust asset: \(error)")
                                e.fulfill()

                                return
                            }

                            stellar
                                .payment(source: self.issuer,
                                         destination: self.account.publicKey!,
                                         amount: 1,
                                         passphrase: self.passphrase) { txHash, error in
                                            defer {
                                                e.fulfill()
                                            }

                                            XCTAssertNotNil(txHash)
                            }
            }
        }

        wait(for: [e], timeout: 60)
    }

    func test_balance() {
        let e = expectation(description: "")
        let stellar = self.stellar

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            stellar
                .trust(asset: stellar.asset,
                       account: self.account,
                          passphrase: self.passphrase) { txHash, error in
                            if let error = error {
                                XCTAssertTrue(false, "Failed to trust asset: \(error)")
                                e.fulfill()

                                return
                            }

                            stellar.balance(account: self.account.publicKey!, completion: { balance, error in
                                defer {
                                    e.fulfill()
                                }

                                if let error = error {
                                    XCTAssertTrue(false, "Received unexpected error: \(error)!")

                                    return
                                }
                            })
            }
        }

        wait(for: [e], timeout: 60)
    }

}
