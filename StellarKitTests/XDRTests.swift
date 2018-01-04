//
//  XDRTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
import StellarKit

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
        var xdr = Bool(true).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAQ==")

        xdr = Bool(false).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAA==")
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

    func test_encode_String() {
        let xdr = "two strings".toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAC3R3byBzdHJpbmdzAA==")
    }

    func test_decode_String() {
        var xdr = Data(base64Encoded: "AAAAC3R3byBzdHJpbmdzAA==")!

        XCTAssertEqual("two strings", String(xdrData: &xdr))

        xdr = Data(base64Encoded: "AAAACGEgc3RyaW5n")!

        XCTAssertEqual("a string", String(xdrData: &xdr))
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

    func test_encode_FixedLengthArrayWrapper() {
        let wrapper = FixedLengthArrayWrapper<Int32>([1, 3, 5])

        let xdr = wrapper.toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAAAQAAAAMAAAAF")

        XCTAssertNotNil(wrapper.debugDescription)

        for i in wrapper {
            XCTAssert(i > 0)
        }
    }

    func test_decode_FixedLengthArrayWrapper() {
        var xdr = Data(base64Encoded: "AAAAAQAAAAMAAAAF")!

        XCTAssertEqual([1, 3, 5], Array<Int32>.init(xdrData: &xdr, count: 3))
    }

    func test_decode_FixedLengthDataWrapper() {
        let wrapper = FixedLengthDataWrapper(Data([1, 3, 5]))
        var xdr = wrapper.toXDR()

        XCTAssertEqual(wrapper.wrapped, Data(xdrData: &xdr, count: Int32(wrapper.wrapped.count)))

        XCTAssertNotNil(wrapper.debugDescription)
    }

    func test_encode_XDREncodableStruct() {
        struct TestStruct: XDREncodableStruct {
            let a: Int32
            let b: Int64
        }

        let xdr = TestStruct(a: 12, b: 29).toXDR()

        XCTAssertEqual(xdr.base64EncodedString(), "AAAADAAAAAAAAAAd")
    }
}
