//
//  KeyStoreTests.swift
//  StellarKinKitTests
//
//  Created by Kin Foundation
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

    func test_remove() {
        let account_pkey = account!.publicKey!

        KeyStore.remove(at: 1)

        let account_0_pkey = KeyStore.account(at: 0)!.publicKey!

        XCTAssertEqual(account_pkey, account_0_pkey, "It looks like the wrong account was removed!")
    }

    func test_removing_middle_account_fills_hole() {
        let issuer_pkey = issuer!.publicKey!

        XCTAssertNotEqual(issuer_pkey, KeyStore.account(at: 1)!.publicKey!,
                          "Issuer should not be at index 1!")

        KeyStore.remove(at: 1)

        XCTAssertEqual(issuer_pkey, KeyStore.account(at: 1)!.publicKey!,
                       "Issuer should be at index 1!")
    }

    func test_export_with_different_passphrase() {
        let store = KeyStore.exportAccount(account: account!,
                                           passphrase: passphrase,
                                           newPassphrase: "new phrase")

        XCTAssertNotNil(store)
    }

    func test_export_with_same_passphrase() {
        let store = KeyStore.exportAccount(account: account!,
                                           passphrase: passphrase,
                                           newPassphrase: passphrase)

        XCTAssertNotNil(store)
    }

    func test_import_with_different_passphrase() {
        let count = KeyStore.count()

        let store = KeyStore.exportAccount(account: account!,
                                           passphrase: passphrase,
                                           newPassphrase: "new phrase")

        try? KeyStore.importAccount(store!, passphrase: "new phrase", newPassphrase: passphrase)

        XCTAssert(KeyStore.count() == count + 1)
    }

    func test_import_with_same_passphrase() {
        let count = KeyStore.count()

        let store = KeyStore.exportAccount(account: account!,
                                           passphrase: passphrase,
                                           newPassphrase: passphrase)

        try? KeyStore.importAccount(store!, passphrase: passphrase, newPassphrase: passphrase)

        XCTAssert(KeyStore.count() == count + 1)
    }

    func test_account_import() {
        let count = KeyStore.count()

        let account = try? KeyStore.importSecretSeed("SCML43HASLG5IIN34KCJLDQ6LPWYQ3HIROP5CRBHVC46YRMJ6QLOYQJS",
                                                     passphrase: passphrase)

        XCTAssertNotNil(account)

        let storedAccount = KeyStore.account(at: count)

        XCTAssertEqual(account!.publicKey!, storedAccount!.publicKey!)
    }

    func test_account_secret_key_with_correct_passphrase() {
        let skey = account!.secretKey(passphrase: passphrase)

        XCTAssertNotNil(skey)
    }

    func test_account_secret_key_with_incorrect_passphrase() {
        let skey = account!.secretKey(passphrase: "incorrect passphrase")

        XCTAssertNil(skey)
    }

    func test_account_secret_seed_with_correct_passphrase() {
        let seed = account!.secretSeed(passphrase: passphrase)

        XCTAssertNotNil(seed)
    }

    func test_account_secret_seed_with_incorrect_passphrase() {
        let seed = account!.secretSeed(passphrase: "incorrect passphrase")

        XCTAssertNil(seed)
    }
}
