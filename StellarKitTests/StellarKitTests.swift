//
//  StellarKitTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class StellarKitTests: XCTestCase {
    let passphrase = "a phrase"

    let stellar = Stellar(baseURL: URL(string: "https://horizon-testnet.stellar.org")!,
                          asset: Asset(assetCode: "KIN",
                                       issuer: "GBOJSMAO3YZ3CQYUJOUWWFV37IFLQVNVKHVRQDEJ4M3O364H5FEGGMBH"))
    var account: StellarAccount?
    var account2: StellarAccount?
    var issuer: StellarAccount?

    override func setUp() {
        super.setUp()

        KeyStore.removeAll()

        if KeyStore.count() > 0 {
            XCTAssertTrue(false, "Unable to clear existing accounts!")
        }

        self.account = try? KeyStore.newAccount(passphrase: passphrase)
        self.account2 = try? KeyStore.newAccount(passphrase: passphrase)

        if account == nil || account2 == nil {
            XCTAssertTrue(false, "Unable to create account(s)!")
        }

        issuer = try? KeyStore.importSecretSeed("SCML43HASLG5IIN34KCJLDQ6LPWYQ3HIROP5CRBHVC46YRMJ6QLOYQJS",
                                                passphrase: passphrase)

        if issuer == nil {
            XCTAssertTrue(false, "Unable to import issuer account!")
        }
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func test_payment_to_untrusting_account() {
        let e = expectation(description: "")

        guard
            let account = account,
            let account2 = account2
            else {
                XCTAssertTrue(false, "Missing account(s)!")

                return
        }

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

        guard
            let account = account,
            let account2 = account2
            else {
                XCTAssertTrue(false, "Missing account(s)!")

                return
        }

        stellar.fund(account: account2.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            self
                .stellar
                .trust(asset: self.stellar.asset,
                       account: account2,
                       passphrase: self.passphrase) { txHash, error in
                        if let error = error {
                            XCTAssertTrue(false, "Failed to trust KIN asset: \(error)")
                            e.fulfill()

                            return
                        }

                        self
                            .stellar
                            .payment(source: account,
                                     destination: account2.publicKey!,
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

        guard
            let account = account,
            let account2 = account2
            else {
                XCTAssertTrue(false, "Missing account(s)!")

                return
        }

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            stellar.fund(account: account2.publicKey!) { success in
                if !success {
                    XCTAssertTrue(false, "Unable to fund account!")

                    e.fulfill()

                    return
                }

                stellar
                    .trust(asset: stellar.asset,
                           account: account,
                              passphrase: self.passphrase) { txHash, error in
                                if let error = error {
                                    XCTAssertTrue(false, "Failed to trust KIN asset: \(error)")
                                    e.fulfill()

                                    return
                                }

                                stellar
                                    .trust(asset: stellar.asset,
                                           account: account2,
                                              passphrase: self.passphrase) { txHash, error in

                                                if let error = error {
                                                    XCTAssertTrue(false, "Failed to trust KIN asset: \(error)")
                                                    e.fulfill()

                                                    return
                                                }

                                                stellar
                                                    .payment(source: account,
                                                             destination: account2.publicKey!,
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

        guard
            let account = account,
            let issuer = issuer
            else {
                XCTAssertTrue(false, "Missing account(s)!")

                return
        }

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            stellar
                .trust(asset: stellar.asset,
                       account: account,
                          passphrase: self.passphrase) { txHash, error in
                            if let error = error {
                                XCTAssertTrue(false, "Failed to trust KIN asset: \(error)")
                                e.fulfill()

                                return
                            }

                            stellar
                                .payment(source: issuer,
                                         destination: account.publicKey!,
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

        guard
            let account = account
            else {
                XCTAssertTrue(false, "Missing account(s)!")

                return
        }

        stellar.fund(account: account.publicKey!) { success in
            if !success {
                XCTAssertTrue(false, "Unable to fund account!")

                e.fulfill()

                return
            }

            stellar
                .trust(asset: stellar.asset,
                       account: account,
                          passphrase: self.passphrase) { txHash, error in
                            if let error = error {
                                XCTAssertTrue(false, "Failed to trust KIN asset: \(error)")
                                e.fulfill()

                                return
                            }

                            stellar.balance(account: account.publicKey!, completion: { balance, error in
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

//    func test1() {
//        let keys = Sodium().sign.keyPair()!
//
//        let pk = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(keys.publicKey))
//
//        print(pk.toXDR().base64EncodedString())
//
//        print(keys.publicKey.base64EncodedString())
//        print(keys.secretKey.base64EncodedString())
//    }
//
//    func test2() {
//        guard let account = self.account, let account2 = self.account2, let issuer = KeyStore.account(at: 3) else {
//            return
//        }
//
//        print(String(describing: account.publicKey))
//        print(String(describing: account.secretSeed(passphrase: passphrase)))
//
//        print(String(describing: account2.publicKey))
//        print(String(describing: account2.secretSeed(passphrase: passphrase)))
//
//        print(String(describing: issuer.publicKey))
//        print(String(describing: issuer.secretSeed(passphrase: passphrase)))
//    }
//
//    func test3() {
//        let data = Data(base64Encoded: "AAAAAMz0aA3zam0llfm+6vrjvMfGp9N69xmsOxJ37Fg3vKoVAAAAZABiBBUAAAABAAAAAAAAAAAAAAABAAAAAAAAAAcAAAAAgQpeQySd0WEDInBglocy8+qfLsWmvL7NPo94NO+PejAAAAABS0lOAAAAAAEAAAAAAAAAAA==")!
//
//        print("----")
//        data.withUnsafeBytes { (bp: UnsafePointer<UInt8>) -> Void in
//            for i in 0..<data.count {
//                print(bp.advanced(by: i).pointee)
//            }
//        }
//    }
//
//    func test4() {
////        let account = try! KeyStore.newAccount(passphrase: passphrase)
//        let account = KeyStore.account(at: 1)!
//
//        print(String(describing: account.publicKey!))
//        print(String(describing: account.secretSeed(passphrase: passphrase)!))
//    }
//
//    func test5() {
//        for _ in 3..<KeyStore.count() {
//            KeyStore.remove(at: 3)
//        }
//    }
//
//    func test6() {
//        _ = try! KeyStore.newAccount(passphrase: passphrase)
//        let account = KeyStore.account(at: KeyStore.count() - 1)
//
//        print(String(describing: account?.secretSeed(passphrase: passphrase)))
//        print(String(describing: account?.publicKey))
//    }
}
