//
//  KeyStoreTests.swift
//  StellarKinKitTests
//
//  Created by Avi Shevin on 11/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import XCTest
@testable import StellarKinKit

class KeyStoreTests: XCTestCase {
    
    let passphrase = "a phrase"

    var account: StellarAccount?
    var account2: StellarAccount?
    var issuer: StellarAccount?

    override func setUp() {
        super.setUp()

        KeyStore.removeAll()

        if KeyStore.count() > 0 {
            XCTAssertTrue(false, "Unable to clear existing accounts!")
        }

        self.account = try? KeyStore.newAccount(passphrase: passphrase)
        self.account2 = try? KeyStore.newAccount(passphrase: passphrase)

        if account == nil || account2 == nil {
            XCTAssertTrue(false, "Unable to create account(s)!")
        }

        issuer = try? KeyStore.importSecretSeed("SCML43HASLG5IIN34KCJLDQ6LPWYQ3HIROP5CRBHVC46YRMJ6QLOYQJS",
                                                passphrase: passphrase)

        if issuer == nil {
            XCTAssertTrue(false, "Unable to import issuer account!")
        }
    }

    override func tearDown() {
        super.tearDown()
    }

    func test_export() {
        let count = KeyStore.count()

        let store = KeyStore.exportKeystore(passphrase: passphrase, newPassphrase: passphrase)

        XCTAssert(store.count == count, "Unexpected number of exported accounts: \(store)")
    }

    func test_import() {
        let count = KeyStore.count()

        let store = KeyStore.exportKeystore(passphrase: passphrase, newPassphrase: "new phrase")

        try? KeyStore.importKeystore(store, passphrase: "new phrase", newPassphrase: passphrase)

        XCTAssert(KeyStore.count() == count * 2, "One or more accounts failed to import")
    }

    func test_account_import() {
        let count = KeyStore.count()

        let account = try? KeyStore.importSecretSeed("SCML43HASLG5IIN34KCJLDQ6LPWYQ3HIROP5CRBHVC46YRMJ6QLOYQJS",
                                                     passphrase: passphrase)

        XCTAssertNotNil(account)

        let storedAccount = KeyStore.account(at: count)

        XCTAssertEqual(account!.publicKey!, storedAccount!.publicKey!)
    }

}
