// Modified and ported to Swift by Ben Baron in 2025

// ================================================================================================
//  RXMLElement.h
//  Fast processing of XML files
//
// ================================================================================================
//  Created by John Blanco on 9/23/11.
//  Version 1.4
//
//  Copyright (c) 2011 John Blanco
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
// ================================================================================================
//

import Foundation
import libxml2

// MARK: - RXMLDocHolder

final class RXMLDocHolder {
    private(set) var doc: xmlDocPtr?
    
    init(doc: xmlDocPtr?) {
        self.doc = doc
    }
    
    deinit {
        if doc != nil {
            xmlFreeDoc(doc)
        }
    }
}

// MARK: - RXMLElement

final class RXMLElement {
    private var node: xmlNodePtr?
    private(set) var xmlDoc: RXMLDocHolder?
    
    // MARK: - Initialization
    
    init(xmlData: Data) {
        let doc = xmlReadMemory(
            xmlData.withUnsafeBytes { $0.baseAddress },
            Int32(xmlData.count),
            "",
            nil,
            Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NOENT.rawValue)
        )
        
        guard let doc = doc else { return }
        xmlDoc = RXMLDocHolder(doc: doc)
        
        guard isValid else { return }
        node = xmlDocGetRootElement(doc)
        
        if node == nil {
            xmlDoc = nil
        }
    }
    
    private init(xmlDoc: RXMLDocHolder?, node: xmlNodePtr?) {
        self.xmlDoc = xmlDoc
        self.node = node
    }
    
    // MARK: - Factory Methods
    
    static func element(fromXMLData data: Data) -> RXMLElement? {
        return RXMLElement(xmlData: data)
    }
    
    static func element(fromXMLDoc doc: RXMLDocHolder, node: xmlNodePtr) -> RXMLElement? {
        return RXMLElement(xmlDoc: doc, node: node)
    }
    
    // MARK: - Properties
    
    var tag: String? {
        guard let node = node else { return nil }
        return String(cString: node.pointee.name)
    }
    
    var text: String {
        guard let node = node else { return "" }
        guard let key = xmlNodeGetContent(node) else { return "" }
        defer { xmlFree(key) }
        return String(cString: key)
    }
    
    var xml: String {
        guard let node = node else { return "" }
        let buffer = xmlBufferCreate()
        defer { xmlBufferFree(buffer) }
        xmlNodeDump(buffer, node.pointee.doc, node, 0, 0)
        return String(cString: xmlBufferContent(buffer))
    }
    
    var innerXml: String {
        guard let node = node else { return "" }
        var innerXml = ""
        var cur = node.pointee.children
        
        while cur != nil {
            if cur?.pointee.type == XML_TEXT_NODE {
                if let key = xmlNodeGetContent(cur) {
                    innerXml += String(cString: key)
                    xmlFree(key)
                }
            } else {
                let buffer = xmlBufferCreate()
                defer { xmlBufferFree(buffer) }
                xmlNodeDump(buffer, node.pointee.doc, cur, 0, 0)
                innerXml += String(cString: xmlBufferContent(buffer))
            }
            cur = cur?.pointee.next
        }
        
        return innerXml
    }
    
    var textAsInt: Int {
        return Int(text) ?? 0
    }
    
    var textAsDouble: Double {
        return Double(text) ?? 0.0
    }
    
    var isValid: Bool {
        return xmlDoc != nil
    }
    
    // MARK: - Attributes
    
    func attribute(_ name: String) -> String? {
        guard let node = node else { return nil }
        guard let attCStr = xmlGetProp(node, name.cString(using: .utf8)) else { return nil }
        defer { xmlFree(UnsafeMutableRawPointer(mutating: attCStr)) }
        return String(cString: attCStr)
    }
    
    var attributeNames: [String] {
        guard let node = node else { return [] }
        var names: [String] = []
        var attr = node.pointee.properties
        
        while attr != nil {
            names.append(String(cString: attr!.pointee.name))
            attr = attr?.pointee.next
        }
        
        return names
    }
    
    func attributeAsInt(_ name: String) -> Int {
        return Int(attribute(name) ?? "") ?? 0
    }
    
    func attributeAsDouble(_ name: String) -> Double {
        return Double(attribute(name) ?? "") ?? 0.0
    }
    
    // MARK: - Child Navigation
    
    func child(_ tag: String) -> RXMLElement? {
        guard let node = node else { return nil }
        let components = tag.components(separatedBy: ".")
        var cur: xmlNodePtr? = node
        
        for tag in components {
            let tagC = tag.cString(using: .utf8)
            
            if tag == "*" {
                cur = cur?.pointee.children
                while cur != nil && cur!.pointee.type != XML_ELEMENT_NODE {
                    cur = cur!.pointee.next
                }
            } else {
                cur = cur?.pointee.children
                while cur != nil {
                    if cur!.pointee.type == XML_ELEMENT_NODE && xmlStrcmp(cur!.pointee.name, tagC) == 0 {
                        break
                    }
                    cur = cur?.pointee.next
                }
            }
            
            if cur == nil {
                break
            }
        }
        
        guard let cur = cur else { return nil }
        return RXMLElement(xmlDoc: xmlDoc, node: cur)
    }
    
    // MARK: - Iteration
    
    typealias RXMLBlock = (RXMLElement, inout Bool) -> Void
    
    @discardableResult
    func iterate(_ query: String?, using block: RXMLBlock) -> Bool {
        // check for a query
        guard let query = query, let node = node else { return false }
        let components = query.components(separatedBy: ".")
        var cur: xmlNodePtr? = node
        
        // navigate down
        for (index, tagName) in components.enumerated() {
            if tagName == "*" {
                cur = cur?.pointee.children
                
                // different behavior depending on if this is the end of the query or midstream
                if index < components.count - 1, cur != nil {
                    // Midstream
                    repeat {
                        if cur?.pointee.type == XML_ELEMENT_NODE {
                            let element = RXMLElement(xmlDoc: xmlDoc, node: cur)
                            let restOfQuery = components[(index + 1)...].joined(separator: ".")
                            element.iterate(restOfQuery, using: block)
                        }
                        cur = cur?.pointee.next
                    } while cur != nil
                }
            } else {
                let tagNameC = tagName.cString(using: .utf8)
                cur = cur?.pointee.children
                while cur != nil {
                    if cur?.pointee.type == XML_ELEMENT_NODE && xmlStrcmp(cur?.pointee.name, tagNameC) == 0 {
                        break
                    }
                    cur = cur?.pointee.next
                }
            }
            
            if cur == nil {
                break
            }
        }
        
        guard cur != nil else { return true }
        guard let childTagName = components.last else { return true }
        
        repeat {
            if cur?.pointee.type == XML_ELEMENT_NODE {
                let element = RXMLElement(xmlDoc: xmlDoc, node: cur)
                var stop = false
                block(element, &stop)
                if stop { return false }
            }
            
            if childTagName == "*" {
                cur = cur?.pointee.next
            } else {
                let tagNameC = childTagName.cString(using: .utf8)
                repeat {
                    cur = cur?.pointee.next
                    if cur?.pointee.type == XML_ELEMENT_NODE && xmlStrcmp(cur?.pointee.name, tagNameC) == 0 {
                       break
                   }
                } while cur != nil
            }
        } while cur != nil
        
        return true
    }
    
    // MARK: - Description
    
    var description: String {
        return text
    }
}
