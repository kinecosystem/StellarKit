//
//  KeyStore.swift
//  SwiftyStellar
//
//  Created by Avi Shevin on 08/01/2018.
//  Copyright © 2018 Kin Foundation. All rights reserved.
//

import Foundation
import Sodium

enum KeyStoreErrors: Error {
    case keychainStoreFailed
    case noSalt
    case keypairGenerationFailed
}

private let keychainPrefix = "__swifty_stellar_"
private let keychain = KeychainSwift(keyPrefix: keychainPrefix)

class StellarAccount {
    private(set) fileprivate var keychainKey: String

    var publicKey: String? {
        guard
            let json = json(),
            let key = json["pkey"] else {
                return nil
        }

        return key
    }

    func secretSeed(passphrase: String) -> String? {
        guard let seed = seed(passphrase: passphrase) else {
            return nil
        }

        return KeyUtils.base32(seed: seed)
    }

    init(keychainKey: String) {
        self.keychainKey = keychainKey
    }

    private func json() -> [String: String]? {
        guard
            let data = keychain.getData(keychainKey),
            let jsonOpt = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
            let json = jsonOpt else {
                return nil
        }

        return json
    }

    private func seed(passphrase: String) -> Data? {
        guard
            let json = json(),
            let hash = json["hash"],
            let salt = json["salt"],
            let seed = try? KeyUtils.seed(from: passphrase, hash: hash, salt: salt) else {
                return nil
        }

        return seed
    }
}

class KeyStore {
    static func newAccount(passphrase: String) throws -> StellarAccount {
        let keychainKey = nextKeychainKey()

        let hash = try KeyUtils.hashed(string: passphrase)
        guard let salt = KeyUtils.salt() else {
            throw KeyStoreErrors.noSalt
        }

        guard
            let seed = try? KeyUtils.seed(from: passphrase, hash: hash, salt: salt),
            let keypair = KeyUtils.keyPair(from: seed) else {
                throw KeyStoreErrors.keypairGenerationFailed
        }

        let dict = [
            "hash" : hash,
            "salt" : salt,
            "pkey" : KeyUtils.base32(publicKey: keypair.publicKey)
        ]

        let data = try JSONSerialization.data(withJSONObject: dict, options: [])

        guard keychain.set(data, forKey: keychainKey) else {
            throw KeyStoreErrors.keychainStoreFailed
        }

        let account = StellarAccount(keychainKey: keychainKey)

        return account
    }

    static func account(at index: Int) -> StellarAccount? {
        let keys = self.keys()

        guard index < keys.count else {
            return nil
        }

        guard let indexStr = keys[index].split(separator: "_").last else {
            return nil
        }

        return StellarAccount(keychainKey: String(indexStr))
    }

    @discardableResult
    static func remove(at index: Int) -> Bool {
        return keychain.delete(String(format: "%06d", index))
    }

    private static func nextKeychainKey() -> String {
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

    private static func keys() -> [String] {
        var keys = [String]()
        var latest = -1
        var moreKeys = true

        while moreKeys {
            latest += 1

            let key = String(format: "%06d", latest)

            if keychain.getData(key) == nil {
                moreKeys = false
            }
            else {
                keys.append(key)
            }
        }

        return keys.sorted()
    }
}
