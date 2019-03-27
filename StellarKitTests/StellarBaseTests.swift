//
//  StellarBaseTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit
import StellarErrors
import KinUtil
import Sodium

struct MockStellarAccount: Account {
    var publicKey: String? {
        return KeyUtils.base32(publicKey: keyPair.publicKey)
    }
    
    let keyPair: Sign.KeyPair
    
    init(seedStr: String) {
        keyPair = TestKeyUtils.keyPair(from: seedStr)!
        
        let secretKey = keyPair.secretKey

        let sign: (([UInt8]) throws -> [UInt8]) = { message in
            return try TestKeyUtils.sign(message: message, signingKey: secretKey)
        }

        self.sign = sign
    }
    
    var sign: (([UInt8]) throws -> [UInt8])?
    
    init() {
        self.init(seedStr: KeyUtils.base32(seed: TestKeyUtils.seed()!))
    }
}

class StellarBaseTests: XCTestCase {
    var endpoint: String { fatalError("override me") }
    var networkId: NetworkId { fatalError("override me") }
    
    let asset = Asset(assetCode: "KIN",
                      issuer: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7")!
    var node: Stellar.Node!
    
    var account: Account!
    var account2: Account!
    var issuer: Account!
    
    override func setUp() {
        super.setUp()

        node = Stellar.Node(baseURL: URL(string: endpoint)!, networkId: networkId)

        account = MockStellarAccount()
        account2 = MockStellarAccount()
        issuer = MockStellarAccount(seedStr: "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35")
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func fund(account: String) -> Promise<String> {
        let funderPK = "GCLBBAIDP34M4JACPQJUYNSPZCQK7IRHV7ETKV6U53JPYYUIIVDVJJFQ"
        let funderSK = "SDBDJVXHPVQGDXYHEVOBBV4XZUDD7IQTXM5XHZRLXRJVY5YMH4YUCNZC"
        
        let sourcePK = PublicKey.PUBLIC_KEY_TYPE_ED25519(WD32(KeyUtils.key(base32: funderPK)))
        
        let funder = MockStellarAccount(seedStr: funderSK)
        
        return Stellar.sequence(account: funderPK, node: node)
            .then { sequence in
                let tx = Transaction(sourceAccount: sourcePK,
                                     seqNum: sequence,
                                     timeBounds: nil,
                                     memo: .MEMO_NONE,
                                     fee: 100,
                                     operations: [StellarKit.Operation.createAccount(destination: account,
                                                                                     balance: 100 * 10000000)])
                
                let envelope = try Stellar.sign(transaction: tx,
                                                signer: funder,
                                                node: self.node)
                
                return Stellar.postTransaction(envelope: envelope, node: self.node)
        }
    }
    
    func test_trust() {
        let e = expectation(description: "")
        
        fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return Stellar.trust(asset: self.asset,
                                     account: self.account,
                                     node: self.node)
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
                return Stellar.trust(asset: self.asset,
                                     account: self.account,
                                     node: self.node)
            }
            .then { txHash -> Promise<String> in
                return Stellar.trust(asset: self.asset,
                                     account: self.account,
                                     node: self.node)
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
        
        Stellar.payment(source: account,
                        destination: account2.publicKey!,
                        amount: 1,
                        node: node)
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
                return Stellar.trust(asset: self.asset,
                                     account: self.account2,
                                     node: self.node)
            }
            .then { txHash -> Promise<String> in
                return Stellar.payment(source: self.account,
                                       destination: self.account2.publicKey!,
                                       amount: 1,
                                       asset: self.asset,
                                       node: self.node)
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
        
        fund(account: account.publicKey!)
            .then { _ -> Promise<String> in
                return self.fund(account: self.account2.publicKey!)
            }
            .then { _ -> Promise<String> in
                return Stellar.trust(asset: self.asset,
                                     account: self.account,
                                     node: self.node)
            }
            .then { txHash -> Promise<String> in
                return Stellar.trust(asset: self.asset,
                                     account: self.account2,
                                     node: self.node)
            }
            .then { txHash -> Promise<String> in
                return Stellar.payment(source: self.account,
                                       destination: self.account2.publicKey!,
                                       amount: 1,
                                       asset: self.asset,
                                       node: self.node)
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
                return Stellar.trust(asset: self.asset,
                                     account: self.account,
                                     node: self.node)
            }
            .then { txHash -> Promise<String> in
                return Stellar.payment(source: self.issuer,
                                       destination: self.account.publicKey!,
                                       amount: 1,
                                       asset: self.asset,
                                       node: self.node)
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
                return Stellar.trust(asset: self.asset,
                                     account: self.account,
                                     node: self.node)
            }
            .then { txHash -> Promise<Decimal> in
                return Stellar.balance(account: self.account.publicKey!,
                                       asset: self.asset,
                                       node: self.node)
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

    func test_network_parameters() {
        let e = expectation(description: "")

        Stellar.networkParameters(node: node)
            .then ({ params in
                XCTAssertGreaterThan(params.baseFee, 0)
            })
            .error({ error in
                XCTAssertFalse(true, "\(error)")
            })
            .finally {
                e.fulfill()
        }

        wait(for: [e], timeout: 120.0)
    }
}
