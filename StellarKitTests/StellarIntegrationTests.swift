//
//  StellarIntegrationTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class StellarIntegrationTests: XCTestCase {
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
    
    func test_trust() {
        guard let account = account else {
            XCTAssertTrue(false, "Missing account!")
            
            return
        }
        
        self.stellar.fund(account: account.publicKey!)
            .then { _ -> Any? in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: account,
                                          passphrase: self.passphrase)
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
        }
    }
    
    func test_double_trust() {
        guard let account = account else {
            XCTAssertTrue(false, "Missing account!")
            
            return
        }
        
        stellar.fund(account: account.publicKey!)
            .then { _ -> Any? in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: account,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Any? in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: account,
                                          passphrase: self.passphrase)
            }
            .error { error in
                XCTAssertTrue(false, "Failed to trust asset: \(error)")
        }
    }
    
    func test_payment_to_untrusting_account() {
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
        guard
            let account = account,
            let account2 = account2
            else {
                XCTAssertTrue(false, "Missing account(s)!")
                
                return
        }
        
        stellar.fund(account: account2.publicKey!)
            .then { _ -> Any? in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: account2,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Any? in
                return self.stellar.payment(source: account,
                                            destination: account2.publicKey!,
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
        
        guard
            let account = account,
            let account2 = account2
            else {
                XCTAssertTrue(false, "Missing account(s)!")
                
                return
        }
        
        stellar.fund(account: account.publicKey!)
            .then { _ -> Any? in
                return stellar.fund(account: account2.publicKey!)
            }
            .then { _ -> Any? in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: account,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Any? in
                return stellar.trust(asset: stellar.asset,
                                     account: account2,
                                     passphrase: self.passphrase)
            }
            .then { txHash -> Any? in
                return stellar.payment(source: account,
                                       destination: account2.publicKey!,
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
        
        guard
            let account = account,
            let issuer = issuer
            else {
                XCTAssertTrue(false, "Missing account(s)!")
                
                return
        }
        
        stellar.fund(account: account.publicKey!)
            .then { _ -> Any? in
                return stellar.trust(asset: stellar.asset,
                                     account: account,
                                     passphrase: self.passphrase)
            }
            .then { txHash -> Any? in
                return stellar.payment(source: issuer,
                                       destination: account.publicKey!,
                                       amount: 1,
                                       passphrase: self.passphrase)
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
        }
    }
    
    func test_balance() {
        let stellar = self.stellar
        
        guard
            let account = account
            else {
                XCTAssertTrue(false, "Missing account(s)!")
                
                return
        }
        
        stellar.fund(account: account.publicKey!)
            .then { _ -> Any? in
                return self.stellar.trust(asset: self.stellar.asset,
                                          account: account,
                                          passphrase: self.passphrase)
            }
            .then { txHash -> Any? in
                return stellar.balance(account: account.publicKey!)
            }
            .error { error in
                XCTAssertTrue(false, "Received unexpected error: \(error)!")
        }
    }

}
