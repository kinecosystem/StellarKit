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
import Sodium

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
    
    var sign: ((Data) throws -> [UInt8])?
    
    init() {
        self.init(seedStr: KeyUtils.base32(seed: TestKeyUtils.seed()!))
    }
}

class StellarBaseTests: XCTestCase {
    var endpoint: String { fatalError("override me") }
    var networkId: NetworkId { fatalError("override me") }
    
    let asset = Asset(assetCode: "TEST_ASSET",
                      issuer: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7")!
    var node: Stellar.Node!
    
    var account: Account!
    var account2: Account!
    var issuer: Account!
    var funder: Account!

    override func setUp() {
        super.setUp()

        node = Stellar.Node(baseURL: URL(string: endpoint)!, networkId: networkId)

        account = MockStellarAccount()
        account2 = MockStellarAccount()
        issuer = MockStellarAccount(seedStr: "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35")
        funder = MockStellarAccount(seedStr: "SDBDJVXHPVQGDXYHEVOBBV4XZUDD7IQTXM5XHZRLXRJVY5YMH4YUCNZC")

        createAssetAccount()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func createAssetAccount() {
        let e = expectation(description: "setup")

        Stellar.balance(account: issuer.publicKey!, asset: asset, node: node)
            .then { _ in e.fulfill() }
            .error({ _ in
                TxBuilder(source: self.funder, node: self.node)
                    .add(operation: StellarKit.Operation
                        .createAccount(destination: self.issuer.publicKey!, balance: 100 * 100_000))
                    .post()
                    .then({ _ -> Promise<Responses.TransactionSuccess> in
                        return TxBuilder(source: self.issuer, node: self.node)
                            .add(operation: StellarKit.Operation.changeTrust(asset: self.asset))
                            .post()
                    })
                    .then { _ in e.fulfill() }
            })

        wait(for: [ e ], timeout: 3.0)
    }

    func fund(account: String) -> Promise<String> {
        return TxBuilder(source: funder, node: node)
            .add(operation: StellarKit.Operation.createAccount(destination: account, balance: 100 * 100_000))
            .post()
            .then { return Promise($0.hash) }
    }

    func test_network_parameters() {
        let e = expectation(description: "")

        Stellar.networkConfiguration(node: node)
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
