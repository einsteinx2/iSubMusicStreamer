//
//  APIError.swift
//  iSub
//
//  Created by Benjamin Baron on 1/27/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

// NOTE: Unfortunately lots of boilerplate due to Swift language restrictions
enum APIError: Error {
    case serverUnsupported
    case serverUnreachable
    case requestCreation
    case responseNotXML
    case responseMissingElement(parent: String, tag: String)
    case responseMissingAttribute(tag: String, attribute: String)
    case dataNotFound
    case database
    case filesystem
    
    var name: String {
        switch self {
        case .serverUnsupported:        return "APIError.serverUnsupported"
        case .serverUnreachable:        return "APIError.serverUnreachable"
        case .requestCreation:          return "APIError.requestCreation"
        case .responseNotXML:           return "APIError.esponseNotXML"
        case .responseMissingElement:   return "APIError.responseMissingElement"
        case .responseMissingAttribute: return "APIError.responseMissingAttribute"
        case .dataNotFound:             return "APIError.dataNotFound"
        case .database:                 return "APIError.database"
        case .filesystem:               return "APIError.filesystem"
        }
    }
    
    // Custom description
    var localizedDescription: String {
        switch self {
        case .serverUnsupported:
            return "This server is not supported. iSub supports Subsonic and Subsonic compatible servers."
        case .serverUnreachable:
            return "The server is unreachable. Either the server is turned off or it's not reachable from your current network. For example, port forwarding is not setup and you're not at home, your internet connection is down, etc."
        case .requestCreation:
            return "There was an error creating the API request."
        case .responseNotXML:
            return "The server did not respond with XML. This usually means that somehow you did not reach your Subsonic server, or your Subsonic server is crashing."
        case .responseMissingElement(let parent, let tag):
            return "The response was missing a required XML element \"\(tag)\" inside \(parent), so the requested information could not be read."
        case .responseMissingAttribute(let tag, let attribute):
            return "The response was missing a required XML attribute \"\(attribute)\" inside \(tag), so the requested information could not be read."
        case .dataNotFound:
            return "The requested information was not found."
        case .database:
            return "There was a problem saving iformation to the local iSub database. This should never happen, and may indicate a serious problem. Try restarting iSub, and if it continues to happen please reach out to iSub support."
        case .filesystem:
            return "There was a problem writing to the local device. This should never happen, and may indicate a serious problem. Try restarting iSub, and if it continues to happen please reach out to iSub support."
        }
    }
}

extension APIError: CustomStringConvertible {
    var description: String {
        "\(name) - \(localizedDescription)"
    }
}
