//
//  SubsonicDateParsing.swift
//  iSub
//
//  Created by Ben Baron on 7/25/26.
//  Copyright © 2026 Ben Baron. All rights reserved.
//

import Foundation

// Subsonic-family servers are inconsistent about date formatting, so parsing tries
// each known format in order of how commonly it has been observed.

// This is the format that Subsonic and Airsonic servers reply with
private let iso8601FormatterWithMilliseconds: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .iso8601)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return dateFormatter
}()

// This is the format shown in the API documentation
private let iso8601FormatterWithoutTimezone: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.calendar = Calendar(identifier: .iso8601)
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    return dateFormatter
}()

// Navidrome emits colon-separated UTC offsets, e.g. 2023-01-01T12:00:00.123456789+02:00
private let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return dateFormatter
}()

private let iso8601Formatter: ISO8601DateFormatter = {
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [.withInternetDateTime]
    return dateFormatter
}()

enum SubsonicDateParsing {
    static func date(from string: String) -> Date? {
        iso8601FormatterWithMilliseconds.date(from: string)
            ?? iso8601FormatterWithoutTimezone.date(from: string)
            ?? iso8601FormatterWithFractionalSeconds.date(from: string)
            ?? iso8601Formatter.date(from: string)
    }
}
