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

}

