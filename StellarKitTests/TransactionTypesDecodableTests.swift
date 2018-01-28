//
//  TransactionTypesDecodableTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

private let string = "GANMSMOCHLLHKIWHV2MOC7TVPRNK22UT2CNZGYVRAQOTOHCKJZS5I2JQ"
private let data = Data(KeyUtils.key(base32: string))

class TransactionTypesDecodableTests: XCTestCase {

    let pk = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(data))
    let asset = Asset(assetCode: "TEST", issuer: string)!

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func test_PublicKey() {
        let x1 = pk

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = PublicKey(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_CreateAccountOp() {
        let x1 = CreateAccountOp(destination: pk, balance: 123)

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = CreateAccountOp(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_ChangeTrustOp() {
        let x1 = ChangeTrustOp(asset: asset)

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = ChangeTrustOp(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_PaymentOp() {
        let x1 = PaymentOp(destination: pk, asset: asset, amount: 123)

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = PaymentOp(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_Operation() {
        let op = PaymentOp(destination: pk, asset: asset, amount: 123)

        let x1 = Operation(sourceAccount: nil, body: .PAYMENT(op))

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = Operation(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_Transaction() {
        let op = Operation(sourceAccount: nil,
                           body: .PAYMENT(PaymentOp(destination: pk, asset: asset, amount: 123)))

        let x1 = Transaction(sourceAccount: pk,
                             seqNum: 1,
                             timeBounds: nil,
                             memo: .MEMO_NONE,
                             operations: [op])

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = Transaction(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_DecoratedSignature() {
        let x1 = DecoratedSignature(hint: FixedLengthDataWrapper(Data([0, 1, 2, 3])),
                                    signature: Data())

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = DecoratedSignature(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func testMock() {
        URLProtocol.registerClass(HTTPMock.self)

        let key = "GANMSMOCHLLHKIWHV2MOC7TVPRNK22UT2CNZGYVRAQOTOHCKJZS5I2JQ"
        let asset = Asset(assetCode: "TEST", issuer: key)!

        let hz = HorizonMock()

        hz.inject(account: MockAccount(balances: [Balance(asset: asset, amount: 123)]), key: key)

        let funderBalances = [
            Balance(asset: asset, amount: 10000000),
            Balance(asset: .ASSET_TYPE_NATIVE, amount: 1000000000)
        ]

        hz.inject(account: MockAccount(balances: funderBalances),
                  key: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7")

        let s = Stellar(baseURL: URL(string: "https://horizon")!, asset: asset)

        let e = expectation(description: "")

        s.fund(account: "GCJBAMWZPFLO3E37I2SMJ7GCSI7JKK7XEAVFPIHSFFCQ3BMS6SZIO7TN") { success in
            print(success)
            
            s.fund(account: "GCJBAMWZPFLO3E37I2SMJ7GCSI7JKK7XEAVFPIHSFFCQ3BMS6SZIO7TN") { success in
                print(success)

                e.fulfill()
            }
        }

//        s.payment(source: MockStellarAccount(seedStr: "SAXSDD5YEU6GMTJ5IHA6K35VZHXFVPV6IHMWYAQPSEKJRNC5LGMUQX35"),
//                  destination: key,
//                  amount: 100,
//                  passphrase: "") { txHash, error in
//                    print(String(describing: txHash))
//                    print(String(describing: error))
//
//                    e.fulfill()
//        }

//        s.balance(account: key, asset: asset) { balance, error in
//            print(String(describing: balance))
//            print(String(describing: error))
//
//            e.fulfill()
//        }

        wait(for: [e], timeout: 100.0)
    }
}

