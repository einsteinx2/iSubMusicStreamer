//
//  SubsonicXMLDecoder.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

/// Decodes the XML flavor of the Subsonic API into the same Codable DTOs that
/// SubsonicJSON decodes, using the documented XML<->JSON mapping:
///   - the document exposes the root tag as its single key ("subsonic-response")
///   - element attributes and child elements become keyed fields
///   - repeated children with the same tag become arrays
///   - element text content becomes the "value" field
///   - scalars are parsed from attribute strings (Int/Double/Bool/Date)
///
/// Key resolution order inside an element: "value" (text), then attributes, then
/// children. The Subsonic schema subset iSub consumes has no attribute/child-tag
/// name collisions, so the order never matters in practice.
enum SubsonicXMLDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let root = RXMLElement(xmlData: data)
        guard root.isValid else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Data is not parseable XML"))
        }
        return try T(from: XMLDTODecoder(node: .document(root), codingPath: []))
    }
}

private struct XMLKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(_ string: String) {
        stringValue = string
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private func trimmedText(_ element: RXMLElement) -> String? {
    let text = element.text
    return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
}

private func childElements(of element: RXMLElement, tag: String) -> [RXMLElement] {
    var children = [RXMLElement]()
    element.iterate(tag) { child, _ in
        children.append(child)
    }
    return children
}

private final class XMLDTODecoder: Decoder {
    enum Node {
        case document(RXMLElement)   // exposes the root tag as its single key
        case element(RXMLElement)    // keys = "value" ∪ attributes ∪ child tags
        case elements([RXMLElement]) // repeated children -> unkeyed container
        case scalar(String)          // attribute value or text content
    }

    let node: Node
    let codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { [:] }

    init(node: Node, codingPath: [CodingKey]) {
        self.node = node
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        switch node {
        case .document(let root):
            return KeyedDecodingContainer(XMLDocumentContainer(root: root, codingPath: codingPath))
        case .element(let element):
            return KeyedDecodingContainer(XMLElementContainer(element: element, codingPath: codingPath))
        case .elements, .scalar:
            throw DecodingError.typeMismatch([String: Any].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode a keyed container from \(node)"))
        }
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        switch node {
        case .elements(let elements):
            return XMLUnkeyedContainer(elements: elements, codingPath: codingPath)
        case .element(let element):
            // A lone child where an array was requested (parity with LenientArray)
            return XMLUnkeyedContainer(elements: [element], codingPath: codingPath)
        case .document, .scalar:
            throw DecodingError.typeMismatch([Any].self, DecodingError.Context(codingPath: codingPath, debugDescription: "Cannot decode an unkeyed container from \(node)"))
        }
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        XMLSingleValueContainer(decoder: self)
    }
}

// MARK: - Scalar parsing shared by the containers

private enum XMLScalar {
    static func string(_ raw: String, at codingPath: [CodingKey]) -> String {
        raw
    }

    static func bool(_ raw: String, at codingPath: [CodingKey]) throws -> Bool {
        switch raw {
        case "true", "1": return true
        case "false", "0": return false
        default:
            throw DecodingError.typeMismatch(Bool.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Not a boolean: \(raw)"))
        }
    }

    static func integer<T: FixedWidthInteger>(_ type: T.Type, _ raw: String, at codingPath: [CodingKey]) throws -> T {
        guard let value = T(raw) else {
            throw DecodingError.typeMismatch(T.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Not an integer: \(raw)"))
        }
        return value
    }

    static func double(_ raw: String, at codingPath: [CodingKey]) throws -> Double {
        guard let value = Double(raw) else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: codingPath, debugDescription: "Not a number: \(raw)"))
        }
        return value
    }

    static func date(_ raw: String, at codingPath: [CodingKey]) throws -> Date {
        guard let date = SubsonicDateParsing.date(from: raw) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Unrecognized Subsonic date format: \(raw)"))
        }
        return date
    }
}

// MARK: - Keyed container over the document (single key: the root tag)

private struct XMLDocumentContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let root: RXMLElement
    let codingPath: [CodingKey]

    var allKeys: [Key] {
        guard let tag = root.tag, let key = Key(stringValue: tag) else { return [] }
        return [key]
    }

    func contains(_ key: Key) -> Bool {
        key.stringValue == root.tag
    }

    private func element(for key: Key) throws -> RXMLElement {
        guard contains(key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "Root element is <\(root.tag ?? "nil")>, not <\(key.stringValue)>"))
        }
        return root
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        _ = try element(for: key)
        return false
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let decoder = XMLDTODecoder(node: .element(try element(for: key)), codingPath: codingPath + [key])
        return try T(from: decoder)
    }

    // The document level only ever decodes the envelope object
    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool { throw unsupported(key) }
    func decode(_ type: String.Type, forKey key: Key) throws -> String { throw unsupported(key) }
    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { throw unsupported(key) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { throw unsupported(key) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { throw unsupported(key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { throw unsupported(key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { throw unsupported(key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { throw unsupported(key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { throw unsupported(key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { throw unsupported(key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { throw unsupported(key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { throw unsupported(key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { throw unsupported(key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { throw unsupported(key) }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> { throw unsupported(key) }
    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer { throw unsupported(key) }
    func superDecoder() throws -> Decoder { throw unsupported(nil) }
    func superDecoder(forKey key: Key) throws -> Decoder { throw unsupported(key) }

    private func unsupported(_ key: Key?) -> DecodingError {
        DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath + [key].compactMap { $0 }, debugDescription: "Unsupported decode at the XML document level"))
    }
}

// MARK: - Keyed container over an element

private struct XMLElementContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let element: RXMLElement
    let codingPath: [CodingKey]

    var allKeys: [Key] {
        var names = element.attributeNames
        if trimmedText(element) != nil {
            names.append("value")
        }
        element.iterate("*") { child, _ in
            if let tag = child.tag {
                names.append(tag)
            }
        }
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }.compactMap { Key(stringValue: $0) }
    }

    func contains(_ key: Key) -> Bool {
        if key.stringValue == "value" && trimmedText(element) != nil {
            return true
        }
        return element.attribute(key.stringValue) != nil || element.child(key.stringValue) != nil
    }

    // A scalar for the key, or nil if the key resolves to child elements
    private func scalar(for key: Key) -> String? {
        if key.stringValue == "value", let text = trimmedText(element) {
            return text
        }
        return element.attribute(key.stringValue)
    }

    private func requireScalar(for key: Key) throws -> String {
        guard let raw = scalar(for: key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "No attribute or text value for \(key.stringValue) in <\(element.tag ?? "nil")>"))
        }
        return raw
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard contains(key) else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "No value for \(key.stringValue) in <\(element.tag ?? "nil")>"))
        }
        return false
    }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        let path = codingPath + [key]
        if type == Date.self {
            return try XMLScalar.date(try requireScalar(for: key), at: path) as! T
        }
        if let raw = scalar(for: key) {
            return try T(from: XMLDTODecoder(node: .scalar(raw), codingPath: path))
        }
        let children = childElements(of: element, tag: key.stringValue)
        guard !children.isEmpty else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "No value for \(key.stringValue) in <\(element.tag ?? "nil")>"))
        }
        // A single child decodes as the object itself; multiple children only make
        // sense for array-shaped types, which request an unkeyed container
        let node: XMLDTODecoder.Node = children.count == 1 ? .element(children[0]) : .elements(children)
        return try T(from: XMLDTODecoder(node: node, codingPath: path))
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        try XMLScalar.bool(try requireScalar(for: key), at: codingPath + [key])
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        try requireScalar(for: key)
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
        try XMLScalar.double(try requireScalar(for: key), at: codingPath + [key])
    }

    func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
        Float(try XMLScalar.double(try requireScalar(for: key), at: codingPath + [key]))
    }

    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try integer(forKey: key) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try integer(forKey: key) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try integer(forKey: key) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try integer(forKey: key) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try integer(forKey: key) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try integer(forKey: key) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try integer(forKey: key) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try integer(forKey: key) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try integer(forKey: key) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try integer(forKey: key) }

    private func integer<T: FixedWidthInteger>(forKey key: Key) throws -> T {
        try XMLScalar.integer(T.self, try requireScalar(for: key), at: codingPath + [key])
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Nested containers are not supported"))
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath + [key], debugDescription: "Nested containers are not supported"))
    }

    func superDecoder() throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "superDecoder is not supported"))
    }

    func superDecoder(forKey key: Key) throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath + [key], debugDescription: "superDecoder is not supported"))
    }
}

// MARK: - Unkeyed container over repeated child elements

private struct XMLUnkeyedContainer: UnkeyedDecodingContainer {
    let elements: [RXMLElement]
    let codingPath: [CodingKey]
    private(set) var currentIndex = 0

    init(elements: [RXMLElement], codingPath: [CodingKey]) {
        self.elements = elements
        self.codingPath = codingPath
    }

    var count: Int? { elements.count }
    var isAtEnd: Bool { currentIndex >= elements.count }

    private mutating func nextElement<T>(_ type: T.Type) throws -> RXMLElement {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Unkeyed container is at end"))
        }
        defer { currentIndex += 1 }
        return elements[currentIndex]
    }

    mutating func decodeNil() throws -> Bool {
        false // XML has no null elements
    }

    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let element = try nextElement(type)
        let path = codingPath + [XMLKey("[\(currentIndex - 1)]")]
        return try T(from: XMLDTODecoder(node: .element(element), codingPath: path))
    }

    mutating func decode(_ type: Bool.Type) throws -> Bool { throw scalarUnsupported(type) }
    mutating func decode(_ type: String.Type) throws -> String { throw scalarUnsupported(type) }
    mutating func decode(_ type: Double.Type) throws -> Double { throw scalarUnsupported(type) }
    mutating func decode(_ type: Float.Type) throws -> Float { throw scalarUnsupported(type) }
    mutating func decode(_ type: Int.Type) throws -> Int { throw scalarUnsupported(type) }
    mutating func decode(_ type: Int8.Type) throws -> Int8 { throw scalarUnsupported(type) }
    mutating func decode(_ type: Int16.Type) throws -> Int16 { throw scalarUnsupported(type) }
    mutating func decode(_ type: Int32.Type) throws -> Int32 { throw scalarUnsupported(type) }
    mutating func decode(_ type: Int64.Type) throws -> Int64 { throw scalarUnsupported(type) }
    mutating func decode(_ type: UInt.Type) throws -> UInt { throw scalarUnsupported(type) }
    mutating func decode(_ type: UInt8.Type) throws -> UInt8 { throw scalarUnsupported(type) }
    mutating func decode(_ type: UInt16.Type) throws -> UInt16 { throw scalarUnsupported(type) }
    mutating func decode(_ type: UInt32.Type) throws -> UInt32 { throw scalarUnsupported(type) }
    mutating func decode(_ type: UInt64.Type) throws -> UInt64 { throw scalarUnsupported(type) }

    mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Nested containers are not supported"))
    }

    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "Nested containers are not supported"))
    }

    mutating func superDecoder() throws -> Decoder {
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: codingPath, debugDescription: "superDecoder is not supported"))
    }

    private func scalarUnsupported<T>(_ type: T.Type) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "The Subsonic schema has no arrays of scalars"))
    }
}

// MARK: - Single value container (scalars, plus pass-through for wrapper types)

private struct XMLSingleValueContainer: SingleValueDecodingContainer {
    let decoder: XMLDTODecoder
    var codingPath: [CodingKey] { decoder.codingPath }

    private func requireScalar<T>(_ type: T.Type) throws -> String {
        guard case .scalar(let raw) = decoder.node else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(codingPath: codingPath, debugDescription: "Expected a scalar, found \(decoder.node)"))
        }
        return raw
    }

    func decodeNil() -> Bool {
        false // XML attributes are never null; absent keys never reach this point
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        try XMLScalar.bool(try requireScalar(type), at: codingPath)
    }

    func decode(_ type: String.Type) throws -> String {
        try requireScalar(type)
    }

    func decode(_ type: Double.Type) throws -> Double {
        try XMLScalar.double(try requireScalar(type), at: codingPath)
    }

    func decode(_ type: Float.Type) throws -> Float {
        Float(try XMLScalar.double(try requireScalar(type), at: codingPath))
    }

    func decode(_ type: Int.Type) throws -> Int { try integer() }
    func decode(_ type: Int8.Type) throws -> Int8 { try integer() }
    func decode(_ type: Int16.Type) throws -> Int16 { try integer() }
    func decode(_ type: Int32.Type) throws -> Int32 { try integer() }
    func decode(_ type: Int64.Type) throws -> Int64 { try integer() }
    func decode(_ type: UInt.Type) throws -> UInt { try integer() }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try integer() }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try integer() }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try integer() }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try integer() }

    private func integer<T: FixedWidthInteger>() throws -> T {
        try XMLScalar.integer(T.self, try requireScalar(T.self), at: codingPath)
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Date.self {
            return try XMLScalar.date(try requireScalar(type), at: codingPath) as! T
        }
        // Wrapper types (SubsonicID, LenientArray) re-enter through the decoder so
        // their own init(from:) drives which container they need
        return try T(from: decoder)
    }
}
