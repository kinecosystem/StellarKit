//
//  StellarUnitTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

struct TestError: Error {
    let m: String

    init(_ m: String) {
        self.m = m
    }
}

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
        self.stellar.fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account,
                                          passphrase: self.passphrase)
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
        }
    }

    func test_double_trust() {
        stellar.fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account,
                                          passphrase: self.passphrase)
            }
            .error { error in
                XCTAssertTrue(false, "Failed to trust asset: \(error)")
        }
    }

    func test_payment_to_untrusting_account() {
        stellar.payment(source: account,
                        destination: account2.publicKey!,
                        amount: 1,
                        passphrase: self.passphrase)
            .then { txHash -> Void in
                XCTAssertTrue(false, "Expected error!")
            }
            .error { error in
                guard let stellarError = error as? StellarError else {
                    XCTAssertTrue(false, "Received unexpected error: \(error)!")

                    return
                }

                switch stellarError {
                case .missingAccount: break
                case .missingBalance: break
                default:
                    XCTAssertTrue(false, "Received unexpected error: \(error)!")
                }
        }
    }

    func test_payment_from_unfunded_account() {
        stellar.fund(account: account2.publicKey!)
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account2,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Promise<String> in
                return self.stellar.payment(source: self.account,
                                     destination: self.account2.publicKey!,
                                     amount: 1,
                                     passphrase: self.passphrase)
            }
            .then { txHash -> Void in
                XCTAssertTrue(false, "Expected error!")
            }
            .error { error in
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

    func test_payment_from_empty_account() {
        let stellar = self.stellar

        stellar.fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return stellar.fund(account: self.account2.publicKey!)
            }
            .then { _ -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Promise<String> in
                return stellar.trust(asset: stellar.asset,
                                     account: self.account2,
                                     passphrase: self.passphrase)
            }
            .then { txHash -> Promise<String> in
                return stellar.payment(source: self.account,
                                       destination: self.account2.publicKey!,
                                       amount: 1,
                                       passphrase: self.passphrase)
            }
            .then { txHash -> Void in
                XCTAssertTrue(false, "Expected error!")
            }
            .error { error in
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

    func test_payment_to_trusting_account() {
        let stellar = self.stellar

        stellar.fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return stellar.trust(asset: stellar.asset,
                                     account: self.account,
                                     passphrase: self.passphrase)
            }
            .then { txHash -> Promise<String> in
                return stellar.payment(source: self.issuer,
                                       destination: self.account.publicKey!,
                                       amount: 1,
                                       passphrase: self.passphrase)
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
        }
    }

    func test_balance() {
        let stellar = self.stellar

        stellar.fund(account: account.publicKey!)
            .then { txHash -> Promise<String> in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: self.account,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Promise<Decimal> in
                return stellar.balance(account: self.account.publicKey!)
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
        }
    }

}
