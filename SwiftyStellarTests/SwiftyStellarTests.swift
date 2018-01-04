//
//  SwiftyStellarTests.swift
//  SwiftyStellarTests
//
//  Created by Avi Shevin on 04/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import SwiftyStellar
@testable import Sodium

class SwiftyStellarTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func keyPair() -> Sign.KeyPair {
        let publicKey = Data(base64Encoded: "gQpeQySd0WEDInBglocy8+qfLsWmvL7NPo94NO+PejA=")!
        let secretKey = Data(base64Encoded: "r8r3grK5KYpWo3oeTOHi13FVVVLYKZwzD3vdD1tQO+GBCl5DJJ3RYQMicGCWhzLz6p8uxaa8vs0+j3g07496MA==")!

        return Sign.KeyPair(publicKey: publicKey, secretKey: secretKey)
    }
    
    func testExample() {
        let e = expectation(description: "")

        let destination = "GDGPI2AN6NVG2JMV7G7OV6XDXTD4NJ6TPL3RTLB3CJ36YWBXXSVBKS6K"

        Stellar.payment(source: keyPair().publicKey,
                        destination: base32KeyToData(key: destination),
                        amount: 1229,
                        signingKey: keyPair().secretKey) { data in
                            defer {
                                e.fulfill()
                            }

                            guard
                                let data = data,
                                let string = String(data: data, encoding: .utf8) else {
                                    return
                            }

                            print(string)

        }

        wait(for: [e], timeout: 10)
    }

    func test1() {
        let keys = Sodium().sign.keyPair()!

        let pk = PublicKey.PUBLIC_KEY_TYPE_ED25519(FixedLengthDataWrapper(keys.publicKey))

        print(pk.toXDR().base64EncodedString())

        print(keys.publicKey.base64EncodedString())
        print(keys.secretKey.base64EncodedString())
    }

    func test2() {
        let keys = keyPair()

        print(keys.publicKey.crc16)

        print(publicKeyToStellar(keys.publicKey))
        print(base32KeyToData(key: "GCAQUXSDESO5CYIDEJYGBFUHGLZ6VHZOYWTLZPWNH2HXQNHPR55DA6MT").hexString)
    }
}
