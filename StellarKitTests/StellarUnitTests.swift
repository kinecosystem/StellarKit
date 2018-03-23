//
//  StellarUnitTests.swift
//  StellarKitTests
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKit

class StellarUnitTests: StellarBaseTests {
    override var endpoint: String { return "https://horizon" }
    
    var horizonMock: HorizonMock? = nil
    var registered = false
    
    override func setUp() {
        super.setUp()
        
        if !registered {
            URLProtocol.registerClass(HTTPMock.self)
            registered = true
        }
        
        horizonMock = HorizonMock()
        
        let nBalance = Balance(asset: .ASSET_TYPE_NATIVE, amount: 10000000)
        let kBalance = Balance(asset: self.asset, amount: 10000000)
        
        horizonMock?.inject(account: MockAccount(balances: [nBalance, kBalance]),
                            key: "GBSJ7KFU2NXACVHVN2VWQIXIV5FWH6A7OIDDTEUYTCJYGY3FJMYIDTU7")
    }
    
    override func tearDown() {
        horizonMock = nil
        
        super.tearDown()
    }
}
