//
//  XMLTestHelpers.swift
//  iSubTests
//
//  Created by Benjamin Baron on 7/9/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation
import XCTest
@testable import iSub_Beta

// Helpers for constructing RXMLElement values in tests, either from inline XML
// strings or from fixture files, and for digging out nested elements.
enum XMLTestHelpers {
    enum XMLTestError: Error {
        case invalidXML(String)
        case elementNotFound(String)
    }

    // Parses an XML string into its root element. Always prefixes an XML declaration:
    // besides realism, this keeps the data out of Data's small-buffer inline storage,
    // which RXMLElement(xmlData:) cannot parse (it escapes a pointer out of
    // withUnsafeBytes, which is only stable for heap-backed Data)
    static func root(xml: String) throws -> RXMLElement {
        let document = xml.hasPrefix("<?xml") ? xml : "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + xml
        let element = RXMLElement(xmlData: Data(document.utf8))
        guard element.isValid else { throw XMLTestError.invalidXML(xml) }
        return element
    }

    // Parses a fixture file into its root element
    static func root(fixture relativePath: String) throws -> RXMLElement {
        let element = RXMLElement(xmlData: try Fixtures.data(relativePath))
        guard element.isValid else { throw XMLTestError.invalidXML(relativePath) }
        return element
    }

    // Returns the first descendant element with the given tag, searching depth-first
    static func firstDescendant(tag: String, of element: RXMLElement) -> RXMLElement? {
        if let child = element.child(tag), child.isValid {
            return child
        }
        var found: RXMLElement?
        element.iterate("*") { child, stop in
            if let match = firstDescendant(tag: tag, of: child) {
                found = match
                stop = true
            }
        }
        return found
    }

    // Returns all descendant elements with the given tag, searching depth-first
    static func descendants(tag: String, of element: RXMLElement) -> [RXMLElement] {
        var found = [RXMLElement]()
        element.iterate("*") { child, _ in
            if child.tag == tag {
                found.append(child)
            }
            found.append(contentsOf: descendants(tag: tag, of: child))
        }
        return found
    }

    // Convenience: parse inline XML and return the first descendant with the tag
    static func element(tag: String, xml: String) throws -> RXMLElement {
        let root = try root(xml: xml)
        if root.tag == tag { return root }
        guard let match = firstDescendant(tag: tag, of: root) else {
            throw XMLTestError.elementNotFound(tag)
        }
        return match
    }

    // Convenience: parse a fixture and return the first descendant with the tag
    static func element(tag: String, fixture relativePath: String) throws -> RXMLElement {
        let root = try root(fixture: relativePath)
        if root.tag == tag { return root }
        guard let match = firstDescendant(tag: tag, of: root) else {
            throw XMLTestError.elementNotFound(tag)
        }
        return match
    }
}
