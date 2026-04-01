//
//  URLScheme.swift
//  StosDebug
//
//  Created by Stossy11 on 29/3/2026.
//

import Foundation

struct URLQueryDecoder {
    func decode<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = components?.queryItems ?? []
        let dict = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        let decoder = _QueryDecoder(dict: dict)
        return try T(from: decoder)
    }
}

private struct _QueryDecoder: Decoder {
    let dict: [String: String]
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedDecodingContainer<Key> {
        KeyedDecodingContainer(_KeyedContainer(dict: dict, codingPath: codingPath))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { fatalError("Unsupported") }
    func singleValueContainer() throws -> SingleValueDecodingContainer { fatalError("Unsupported") }
}

private struct _KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let dict: [String: String]
    var codingPath: [CodingKey]
    var allKeys: [Key] { dict.keys.compactMap { Key(stringValue: $0) } }
    
    func contains(_ key: Key) -> Bool { dict[key.stringValue] != nil }
    func decodeNil(forKey key: Key) -> Bool { dict[key.stringValue] == nil }
    
    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard let value = dict[key.stringValue] else { throw missing(key) }
        return value
    }
    
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
        guard let raw = dict[key.stringValue], let value = Int(raw) else { throw missing(key) }
        return value
    }
    
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard let raw = dict[key.stringValue], let value = Bool(raw) else { throw missing(key) }
        return value
    }
    
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        guard let raw = dict[key.stringValue], let value = Double(raw) else { throw missing(key) }
        return value
    }
    
    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        // use string conversion if unable to use any other type
        guard let raw = dict[key.stringValue] else { throw missing(key) }
        guard let value = raw as? T else { throw missing(key) }
        return value
    }
    
    func decodeIfPresent(_ type: String.Type, forKey key: Key) throws -> String? {
        dict[key.stringValue]
    }

    func decodeIfPresent(_ type: Int.Type, forKey key: Key) throws -> Int? {
        dict[key.stringValue].flatMap(Int.init)
    }

    func decodeIfPresent(_ type: Bool.Type, forKey key: Key) throws -> Bool? {
        dict[key.stringValue].flatMap(Bool.init)
    }

    func decodeIfPresent(_ type: Double.Type, forKey key: Key) throws -> Double? {
        dict[key.stringValue].flatMap(Double.init)
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        guard let raw = dict[key.stringValue] else { return nil }
        return raw as? T
    }
    
    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> { fatalError("Unsupported") }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { fatalError("Unsupported") }
    func superDecoder() throws -> Decoder { fatalError("Unsupported") }
    func superDecoder(forKey key: Key) throws -> Decoder { fatalError("Unsupported") }
    
    private func missing(_ key: Key) -> DecodingError {
        DecodingError.keyNotFound(key, .init(codingPath: codingPath, debugDescription: "Missing key '\(key.stringValue)'"))
    }
}

struct EnableJIT: Decodable, Sendable {
    var bundleId: String
    var appName: String
    var pid: Int?
    var relaunchApp: Bool?
    var forcePID: Bool?
    var script: String?
    
    var scriptData: Data? {
        if let script {
             return Data(base64Encoded: script)
        } else { return nil }
    }
}
