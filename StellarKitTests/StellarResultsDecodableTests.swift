//
//  TransactionTypesDecodableTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class StellarResultsDecodableTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func test_transaction_result_create_account_success() {
        let x1 = TransactionResult(feeCharged: 123, result: .txSUCCESS([OperationResult
            .opINNER(OperationResult.Tr.CREATE_ACCOUNT(CreateAccountResult.success))]))

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = TransactionResult(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_transaction_result_create_account_failed() {
        let x1 = TransactionResult(feeCharged: 123, result: .txFAILED([OperationResult
            .opINNER(OperationResult.Tr.CREATE_ACCOUNT(CreateAccountResult.failure(CreateAccountResultCode.CREATE_ACCOUNT_MALFORMED)))]))

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = TransactionResult(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_transaction_result_payment_success() {
        let x1 = TransactionResult(feeCharged: 123, result: .txSUCCESS([OperationResult
            .opINNER(OperationResult.Tr.PAYMENT(PaymentResult.success))]))

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = TransactionResult(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_transaction_result_payment_failed() {
        let x1 = TransactionResult(feeCharged: 123, result: .txFAILED([OperationResult
            .opINNER(OperationResult.Tr.PAYMENT(PaymentResult.failure(PaymentResultCode.PAYMENT_NO_ISSUER)))]))

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = TransactionResult(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

    func test_bad_transaction() {
        let x1 = TransactionResult(feeCharged: 123, result: .txERROR(TransactionResultCode.txBAD_SEQ))

        var xdr = x1.toXDR()
        let xdr1 = x1.toXDR()

        let xdr2 = TransactionResult(xdrData: &xdr).toXDR()

        XCTAssertEqual(xdr1, xdr2)
    }

}
