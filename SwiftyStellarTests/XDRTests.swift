//
//  XDRTests.swift
//  SwiftyStellarTests
//
//  Created by Avi Shevin on 07/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest

class XDRTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func test_encode_Int32() {
        let xdr = Int32(1234).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAE0g==")
    }

    func test_decode_Int32() {
        var xdr = Data(base64Encoded: "AAAE0g==")!

        XCTAssertEqual(Int32(1234), Int32(xdrData: &xdr))
    }

    func test_encode_UInt32() {
        let xdr = UInt32(1234).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAE0g==")
    }

    func test_decode_UInt32() {
        var xdr = Data(base64Encoded: "AAAE0g==")!

        XCTAssertEqual(UInt32(1234), UInt32(xdrData: &xdr))
    }

    func test_encode_Int64() {
        let xdr = Int64(1234).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAAAABNI=")
    }

    func test_decode_Int64() {
        var xdr = Data(base64Encoded: "AAAAAAAABNI=")!

        XCTAssertEqual(Int64(1234), Int64(xdrData: &xdr))
    }

    func test_encode_UInt64() {
        let xdr = UInt64(1234).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAAAABNI=")
    }

    func test_decode_UInt64() {
        var xdr = Data(base64Encoded: "AAAAAAAABNI=")!

        XCTAssertEqual(UInt64(1234), UInt64(xdrData: &xdr))
    }

    func test_encode_Bool() {
        let xdr = Bool(true).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAQ==")
    }

    func test_decode_Bool() {
        var xdr = Data(base64Encoded: "AAAAAQ==")!

        XCTAssertEqual(true, Bool(xdrData: &xdr))
    }

    func test_encode_Data() {
        let xdr = Data([0, 1, 3, 5, 7]).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAABQABAwUH")
    }

    func test_decode_Data() {
        var xdr = Data(base64Encoded: "AAAABQABAwUH")!

        XCTAssertEqual(Data([0, 1, 3, 5, 7]), Data(xdrData: &xdr))
    }

    func test_encode_Array() {
        let xdr = Array<Int32>([0, 1, 3, 5, 7]).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAABQAAAAAAAAABAAAAAwAAAAUAAAAH")
    }

    func test_decode_Array() {
        var xdr = Data(base64Encoded: "AAAABQAAAAAAAAABAAAAAwAAAAUAAAAH")!

        XCTAssertEqual(Array<Int32>([0, 1, 3, 5, 7]), Array<Int32>.init(xdrData: &xdr))
    }

    func test_encode_counted_Array() {
        let xdr = Array<Int32>([0, 1, 3, 5, 7]).toXDR(count: 5)

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAAAAAAEAAAADAAAABQAAAAc=")
    }

    func test_decode_counted_Array() {
        var xdr = Data(base64Encoded: "AAAAAAAAAAEAAAADAAAABQAAAAc=")!

        XCTAssertEqual(Array<Int32>([0, 1, 3, 5, 7]), Array<Int32>.init(xdrData: &xdr, count: 5))
    }

    func test_encode_Optional_with_value() {
        let i: Int32? = 1234
        let xdr = i.toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAQAABNI=")
    }

    func test_encode_Optional_with_nil() {
        let i: Int32? = nil
        let xdr = i.toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAA==")
    }

}
