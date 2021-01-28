//
//  SubsonicError.swift
//  iSub
//
//  Created by Benjamin Baron on 1/27/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import Foundation

// NOTE: Unfortunately lots of boilerplate due to Swift language restrictions
enum SubsonicError: Error {
    case generic(message: String)
    case missingParameter(message: String)
    case clientVersion(message: String)
    case serverVersion(message: String)
    case badCredentials(message: String)
    case tokenAuthNotSupported(message: String)
    case notAuthorized(message: String)
    case trialExpired(message: String)
    case dataNotFound(message: String)
    case unknown(code: Int, message: String)
    
    init(element: RXMLElement) {
        let code = element.attribute("code").intXML
        let message = element.attribute("message").stringXML
        self = .init(code: code, message: message)
    }
    
    init(code: Int, message: String) {
        switch code {
        case  0: self = .generic(message: message)
        case 10: self = .missingParameter(message: message)
        case 20: self = .clientVersion(message: message)
        case 30: self = .serverVersion(message: message)
        case 40: self = .badCredentials(message: message)
        case 41: self = .tokenAuthNotSupported(message: message)
        case 50: self = .notAuthorized(message: message)
        case 60: self = .trialExpired(message: message)
        case 70: self = .dataNotFound(message: message)
        default: self = .unknown(code: code, message: message)
        }
    }
    
    var name: String {
        switch self {
        case .generic:               return "SubsonicError.generic"
        case .missingParameter:      return "SubsonicError.missingParameter"
        case .clientVersion:         return "SubsonicError.clientVersion"
        case .serverVersion:         return "SubsonicError.serverVersion"
        case .badCredentials:        return "SubsonicError.badCredentials"
        case .tokenAuthNotSupported: return "SubsonicError.tokenAuthNotSupported"
        case .notAuthorized:         return "SubsonicError.notAuthorized"
        case .trialExpired:          return "SubsonicError.trialExpired"
        case .dataNotFound:          return "SubsonicError.dataNotFound"
        case .unknown:               return "SubsonicError.unknown"
        }
    }
    
    var code: Int {
        switch self {
        case .generic:               return  0
        case .missingParameter:      return 10
        case .clientVersion:         return 20
        case .serverVersion:         return 30
        case .badCredentials:        return 40
        case .tokenAuthNotSupported: return 41
        case .notAuthorized:         return 50
        case .trialExpired:          return 60
        case .dataNotFound:          return 70
        case .unknown(let code, _):  return code
        }
    }
    
    var message: String {
        switch self {
        case .generic(let message):               return message
        case .missingParameter(let message):      return message
        case .clientVersion(let message):         return message
        case .serverVersion(let message):         return message
        case .badCredentials(let message):        return message
        case .tokenAuthNotSupported(let message): return message
        case .notAuthorized(let message):         return message
        case .trialExpired(let message):          return message
        case .dataNotFound(let message):          return message
        case .unknown(_, let message):            return message
        }
    }

    // Custom description (use `message` property for the original message from Subsonic)
    var localizedDescription: String {
        switch self {
        case .generic:
            return "A generic error occured."
        case .missingParameter:
            return "A required parameter is missing."
        case .clientVersion:
            return "Incompatible Subsonic REST protocol version. Client must upgrade."
        case .serverVersion:
            return "Incompatible Subsonic REST protocol version. Server must upgrade."
        case .badCredentials:
            return "The username or password is incorrect."
        case .tokenAuthNotSupported:
            return "Token authentication is not supported for LDAP users."
        case .notAuthorized:
            return "This user account does not have permission to perform this action."
        case .trialExpired:
            return "Your Subsonic API trial has expired.\n\nYou can purchase a license for Subsonic by logging in to the web interface, clicking \"Settings\" on the left, then clicking \"SUBSONIC PREMIUM\" at the top.\n\nPlease remember, iSub is a 3rd party client for Subsonic, and this license and trial is for Subsonic and not iSub.\n\nThere are 100% free and open source compatible alternatives such as AirSonic if you're not interested in purchasing a Subsonic license."
        case .dataNotFound:
            return "The requested data was not found."
        case .unknown(let code, let message):
            return "An unknown error occured with code: \(code), message: \"\(message)\""
        }
    }
}

extension SubsonicError: CustomStringConvertible, CustomDebugStringConvertible {
    var description: String {
        "\(name) - \(localizedDescription)"
    }
    
    var debugDescription: String {
        "\(name) - (code: \(code), message: \"\(message)\", localizedDescription: \"\(localizedDescription)\")"
    }
}
