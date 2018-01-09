//
//  SwiftyStellarTests.swift
//  SwiftyStellarTests
//
//  Created by Avi Shevin on 04/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import SwiftyStellar
@testable import Sodium

class SwiftyStellarTests: XCTestCase {
    let passphrase = "a phrase"

    let stellar = Stellar(baseURL: URL(string: "https://horizon-testnet.stellar.org")!,
                          kinIssuer: "GBOJSMAO3YZ3CQYUJOUWWFV37IFLQVNVKHVRQDEJ4M3O364H5FEGGMBH")
    var account: StellarAccount?
    var account2: StellarAccount?

    override func setUp() {
        super.setUp()

        print("count: \(KeyStore.count())")

        if let account = KeyStore.account(at: 0) {
            self.account = account
        }
        else {
            self.account = try? KeyStore.newAccount(passphrase: passphrase)
        }

        if let account2 = KeyStore.account(at: 1) {
            self.account2 = account2
        }
        else {
            self.account2 = try? KeyStore.newAccount(passphrase: passphrase)
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testPayment() {
        let e = expectation(description: "")

        let destination = "GCJBAMWZPFLO3E37I2SMJ7GCSI7JKK7XEAVFPIHSFFCQ3BMS6SZIO7TN"

        guard let account = self.account, let account2 = self.account2, let destPK = account2.publicKey else {
            XCTAssertTrue(false)

            return
        }

        stellar.payment(source: account,
                        destination: destPK,
                        amount: 1,
                        passphrase: passphrase) { txHash, error in
                            defer {
                                e.fulfill()
                            }

                            if let error = error as? StellarError {
                                switch error {
                                case .parseError (let data):
                                    if let data = data {
                                        print("Error: (\(error)): \(data.base64EncodedString())")
                                    }
                                case .unknownError (let json):
                                    if let json = json {
                                        print("Error: (\(error)): \(json)")
                                    }
                                default:
                                    break
                                }

                                print("Error: \(error)")
                            }
                            else if let error = error {
                                print(error)
                            }

                            guard let txHash = txHash else {
                                return
                            }

                            print(txHash)
        }

        wait(for: [e], timeout: 20)
    }

    func testBalance() {
        let e = expectation(description: "")

        let account = "GANMSMOCHLLHKIWHV2MOC7TVPRNK22UT2CNZGYVRAQOTOHCKJZS5I2JQ"

        stellar.balance(account: account) { amount, error in
            defer {
                e.fulfill()
            }

            if let error = error {
                print("Error: \(error)")
            }

            guard let amount = amount else {
                return
            }

            print(amount)

        }

        wait(for: [e], timeout: 10)
    }

    func testTrust() {
        let e = expectation(description: "")

        guard let account = self.account else {
            XCTAssertTrue(false)

            return
        }

        stellar.trustKIN(source: account, passphrase: passphrase) { txHash, error in
            defer {
                e.fulfill()
            }

            if let error = error as? StellarError {
                switch error {
                case .parseError (let data):
                    if let data = data {
                        print("Error: (\(error)): \(data.base64EncodedString())")
                    }
                case .unknownError (let json):
                    if let json = json {
                        print("Error: (\(error)): \(json)")
                    }
                default:
                    break
                }

                print("Error: \(error)")
            }
            else if let error = error {
                print(error)
            }

            guard let txHash = txHash else {
                return
            }

            print(txHash)
        }

        wait(for: [e], timeout: 20)
    }

    func test1() {
        let keys = Sodium().sign.keyPair()!

        let pk = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(keys.publicKey))

        print(pk.toXDR().base64EncodedString())

        print(keys.publicKey.base64EncodedString())
        print(keys.secretKey.base64EncodedString())
    }

    func test2() {
        guard let account = self.account, let account2 = self.account2 else {
            return
        }

        print(String(describing: account.publicKey))
        print(String(describing: account.secretSeed(passphrase: passphrase)))

        print(String(describing: account2.publicKey))
        print(String(describing: account2.secretSeed(passphrase: passphrase)))
    }

    func test3() {
        let data = Data(base64Encoded: "AAAAAMz0aA3zam0llfm+6vrjvMfGp9N69xmsOxJ37Fg3vKoVAAAAZABiBBUAAAABAAAAAAAAAAAAAAABAAAAAAAAAAcAAAAAgQpeQySd0WEDInBglocy8+qfLsWmvL7NPo94NO+PejAAAAABS0lOAAAAAAEAAAAAAAAAAA==")!

        print("----")
        data.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
            for i in 0..<data.count {
                print(bp.advanced(by: i).pointee)
            }
        }
    }

    func test4() {
//        let account = try? KeyStore.newAccount(passphrase: "passphrase")
        let account = KeyStore.account(at: 0)!

        print(String(describing: account.publicKey!))
        print(String(describing: account.secretSeed(passphrase: passphrase)!))
    }

    func test5() {
        KeyStore.removeAll()
    }

    func test6() {
        _ = try! KeyStore.newAccount(passphrase: passphrase)
        let account = KeyStore.account(at: KeyStore.count() - 1)

        print(String(describing: account?.secretSeed(passphrase: passphrase)))
        print(String(describing: account?.publicKey))
    }
}
