//
//  KeyStore.swift
//  StellarKinKit
//
//  Created by Kin Foundation
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import StellarKinKit

enum KeyStoreErrors: Error {
    case storeFailed
    case noSalt
    case noPepper
    case noSeed
    case noSecretKey
    case keypairGenerationFailed
    case encryptionFailed
}

protocol AccountStorage {
    static func nextStorageKey() -> String
    static func save(_ accountData: Data, forKey key: String) -> Bool
    static func retrieve(_ key: String) -> Data?
    static func account(at index: Int) -> StellarAccount?
    static func remove(at index: Int) -> Bool
    static func count() -> Int
    static func clear()
}

private let StorageClass: AccountStorage.Type = KeychainStorage.self

public class StellarAccount: Account {
    private(set) fileprivate var storageKey: String

    public var publicKey: String? {
        guard
            let json = json(),
            let key = json["pkey"] else {
                return nil
        }

        return key
    }

    public func sign(message: Data, passphrase: String) throws -> Data {
        guard let signingKey = secretKey(passphrase: passphrase) else {
            throw KeyStoreErrors.noSecretKey
        }

        return try KeyUtils.sign(message: message, signingKey: signingKey)
    }

    fileprivate func secretKey(passphrase: String) -> Data? {
        guard let seed = seed(passphrase: passphrase) else {
            return nil
        }

        guard let keypair = KeyUtils.keyPair(from: seed) else {
            return nil
        }

        return keypair.secretKey
    }

    func secretSeed(passphrase: String) -> String? {
        guard let seed = seed(passphrase: passphrase) else {
            return nil
        }

        return KeyUtils.base32(seed: seed)
    }

    init(storageKey: String) {
        self.storageKey = storageKey
    }

    func json() -> [String: String]? {
        guard
            let data = StorageClass.retrieve(storageKey),
            let jsonOpt = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
            let json = jsonOpt else {
                return nil
        }

        return json
    }

    private func seed(passphrase: String) -> Data? {
        guard
            let json = json(),
            let eseed = json["seed"],
            let salt = json["salt"],
            let seed = try? KeyUtils.seed(from: passphrase, encryptedSeed: eseed, salt: salt) else {
                return nil
        }

        return seed
    }
}

public struct KeyStore {
    public static func newAccount(passphrase: String) throws -> StellarAccount {
        let storageKey = StorageClass.nextStorageKey()

        try save(accountData: try accountData(passphrase: passphrase), key: storageKey)

        let account = StellarAccount(storageKey: storageKey)

        return account
    }

    public static func account(at index: Int) -> StellarAccount? {
        return StorageClass.account(at: index)
    }

    @discardableResult
    public static func remove(at index: Int) -> Bool {
        return StorageClass.remove(at: index)
    }

    public static func count() -> Int {
        return StorageClass.count()
    }

    @discardableResult
    public static func importSecretSeed(_ seed: String, passphrase: String) throws -> StellarAccount {
        let seedData = KeyUtils.key(base32: seed)

        let storageKey = StorageClass.nextStorageKey()

        try save(accountData: try accountData(passphrase: passphrase, seed: seedData), key: storageKey)

        let account = StellarAccount(storageKey: storageKey)

        return account
    }

    public static func importAccount(_ accountData: [String: String],
                              passphrase: String,
                              newPassphrase: String) throws {
        let reencryptedJSON: [String: String]?
        if passphrase != newPassphrase {
            reencryptedJSON = reencrypt(accountData,
                                        passphrase: passphrase,
                                        newPassphrase: newPassphrase)
        } else {
            reencryptedJSON = accountData
        }

        if let accountData = reencryptedJSON {
            try save(accountData: accountData, key: StorageClass.nextStorageKey())
        }
    }

    public static func exportAccount(account: StellarAccount,
                                     passphrase: String,
                                     newPassphrase: String) -> [String: String]? {
            if let json = account.json() {
                let reencryptedJSON: [String: String]?
                if passphrase != newPassphrase {
                    reencryptedJSON = reencrypt(json,
                                                passphrase: passphrase,
                                                newPassphrase: newPassphrase)
                } else {
                    reencryptedJSON = json
                }

                if let json = reencryptedJSON {
                    return json
                }
            }

        return nil
    }

    private static func accountData(passphrase: String,
                                    seed: Data? = nil) throws -> [String: String] {
        guard let salt = KeyUtils.salt() else {
            throw KeyStoreErrors.noSalt
        }

        guard let seed = seed ?? KeyUtils.seed() else {
            throw KeyStoreErrors.noSeed
        }

        let skey = try KeyUtils.keyHash(passphrase: passphrase, salt: salt)

        guard let encryptedSeed: Data = KeyUtils.encryptSeed(seed, secretKey: skey) else {
            throw KeyStoreErrors.encryptionFailed
        }

        guard let keypair = KeyUtils.keyPair(from: seed) else {
            throw KeyStoreErrors.keypairGenerationFailed
        }

        return [
            "seed" : encryptedSeed.hexString,
            "salt" : salt,
            "pkey" : KeyUtils.base32(publicKey: keypair.publicKey)
        ]
    }

    private static func reencrypt(_ json: [String: String],
                                  passphrase: String,
                                  newPassphrase: String) -> [String: String]? {
        guard
            let eseed = json["seed"],
            let salt = json["salt"],
            let pkey = json["pkey"],
            let skey = try? KeyUtils.keyHash(passphrase: newPassphrase, salt: salt),
            let seed = try? KeyUtils.seed(from: passphrase, encryptedSeed: eseed, salt: salt),
            let encryptedSeed = KeyUtils.encryptSeed(seed, secretKey: skey)
            else {
                return nil
        }

        return [
            "seed": encryptedSeed.hexString,
            "salt": salt,
            "pkey": pkey,
        ]
    }

    private static func save(accountData: [String: String], key: String) throws {
        let data = try JSONSerialization.data(withJSONObject: accountData, options: [])

        guard StorageClass.save(data, forKey: key) else {
            throw KeyStoreErrors.storeFailed
        }
    }
}

extension KeyStore {
    // WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING!  WARNING!
    // This is for internal use, only.  It will delete ALL keychain entries for the app, not just
    // those used by this SDk.
    // It is intended for use by unit tests.
    static func removeAll() {
        StorageClass.clear()
    }
}

private struct KeychainStorage: AccountStorage {
    private static let keychainPrefix = "__swifty_stellar_"
    private static let keychain = KeychainSwift(keyPrefix: keychainPrefix)

    static func nextStorageKey() -> String {
        let keys = self.keys()

        if keys.count == 0 {
            return String(format: "%06d", 0)
        }
        else {
            if
                let key = keys.last,
                let indexStr = key.split(separator: "_").last,
                let last = Int(indexStr) {
                let index = last + 1

                return String(format: "%06d", index)
            }
            else {
                return ""
            }
        }
    }

    static func save(_ accountData: Data, forKey key: String) -> Bool {
        return keychain.set(accountData, forKey: key)
    }

    static func retrieve(_ key: String) -> Data? {
        return keychain.getData(key)
    }

    static func delete(_ key: String) -> Bool {
        return keychain.delete(key)
    }

    static func account(at index: Int) -> StellarAccount? {
        let keys = self.keys()
        
        guard index < keys.count else {
            return nil
        }
        
        guard let indexStr = keys[index].split(separator: "_").last else {
            return nil
        }
        
        return StellarAccount(storageKey: String(indexStr))
    }
    
    @discardableResult
    static func remove(at index: Int) -> Bool {
        let key = keys()[index]
        
        guard
            index < keys().count,
            let indexStr = key.split(separator: "_").last else {
                return false
        }
        
        return delete(String(indexStr))
    }

    static func count() -> Int {
        return keys().count
    }

    private static func keys() -> [String] {
        let keys = (keychain.getAllKeys() ?? []).filter {
            $0.starts(with: keychainPrefix)
        }

        return keys.sorted()
    }

    fileprivate static func clear() {
        keychain.clear()
    }
}
