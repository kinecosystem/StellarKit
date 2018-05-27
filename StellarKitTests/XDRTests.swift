//
// XDRTests.swift
// StellarKitTests
//
// Created by Kin Foundation.
// Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
import StellarKit

class XDRTests: XCTestCase {

    func test_bool() {
        let a: Bool = true
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(Bool.self))
    }

    func test_uint8() {
        let a: UInt8 = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(UInt8.self))
    }

    func test_int32() {
        let a: Int32 = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(Int32.self))
    }

    func test_uint32() {
        let a: UInt32 = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(UInt32.self))
    }

    func test_int64() {
        let a: Int64 = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(Int64.self))
    }

    func test_uint64() {
        let a: UInt64 = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(UInt64.self))
    }

    func test_array() {
        let a: [UInt8] = [123]
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decodeArray(UInt8.self))
    }

    func test_string_padded() {
        let a = "a"
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(String.self))
    }

    func test_string_unpadded() {
        let a = "abcd"
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(String.self))
    }

    func test_optional_not_nil() {
        let a: UInt8? = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decodeArray(UInt8.self).first)
    }

    func test_optional_nil() {
        let a: UInt8? = nil
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decodeArray(UInt8.self).first)
    }

    func test_data() {
        let a: Data = Data(bytes: [123])
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(Data.self))
    }

    func test_struct() {
        struct S: XDRCodable, XDREncodableStruct {
            let a: Int32
            let b: String

            init(from decoder: XDRDecoder) throws {
                a = try decoder.decode(Int32.self)
                b = try decoder.decode(String.self)
            }

            init(a: Int32, b: String) {
                self.a = a
                self.b = b
            }
        }

        let s = S(a: 123, b: "a")
        let x = try! XDREncoder.encode(s)
        let s2 = try! XDRDecoder(data: x).decode(S.self)

        XCTAssertEqual(s.a, s2.a)
        XCTAssertEqual(s.b, s2.b)
    }

    func test_dump() {
        let path = URL(fileURLWithPath: "/Users/avi/Downloads/results-006bc03f.xdr")
        
        guard let data = try? Data(contentsOf: path) else {
            print("Unable to load data.")
            
            return
        }

        let decoder = XDRDecoder(data: data)
        
        while true {
            let length = try! decoder.decode(UInt32.self)
            
            let history = try! decoder.decode(TransactionHistoryResultEntry.self)
            
            for result in history.txResultSet.results {
                print(result.transactionHash.wrapped.hexString)
            }
        }
    }
}
