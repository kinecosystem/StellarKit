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
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode([UInt8].self))
    }

    func test_optional_not_nil() {
        let a: UInt8? = 123
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode([UInt8].self).first)
    }

    func test_optional_nil() {
        let a: UInt8? = nil
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode([UInt8].self).first)
    }

    func test_data() {
        let a: Data = Data(bytes: [123])
        let x = try! XDREncoder.encode(a)
        try! XCTAssertEqual(a, XDRDecoder(data: x).decode(Data.self))
    }

    func test_struct() {
        struct S: XDRCodable {
            let a: Int32
            let b: String
        }

        let s = S(a: 123, b: "a")
        let x = try! XDREncoder.encode(s)
        let s2 = try! XDRDecoder(data: x).decode(S.self)

        XCTAssertEqual(s.a, s2.a)
        XCTAssertEqual(s.b, s2.b)
    }

}
