// Modified from: https://github.com/StyleShare/HLSCachingReverseProxyServer

import Foundation
import CocoaLumberjackSwift

@objc class HLSReverseProxyServer: NSObject {
    static let originURLKey = "__hls_origin_url"

    private let webServer = GCDWebServer()
    private let urlSessionDelegate = SelfSignedCertURLSessionDelegate()
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60
        configuration.timeoutIntervalForRequest = 240
        return URLSession(configuration: configuration, delegate: urlSessionDelegate, delegateQueue: nil)
    }()

    @objc private(set) var port: UInt = 8080

    @objc override init() {
        super.init()
        addRequestHandlers()
    }

    // MARK: Starting and Stopping Server
    
    @objc func start() {
        guard !webServer.isRunning else { return }
        webServer.start(withPort: port, bonjourName: nil)
    }

    @objc func stop() {
        guard webServer.isRunning else { return }
        webServer.stop()
    }

    // MARK: Resource URL

    private func reverseProxyURL(from originURL: URL) -> URL? {
        guard var components = URLComponents(url: originURL, resolvingAgainstBaseURL: false) else { return nil }
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port)

        let originURLQueryItem = URLQueryItem(name: Self.originURLKey, value: originURL.absoluteString)
        components.queryItems = (components.queryItems ?? []) + [originURLQueryItem]

        return components.url
    }

    // MARK: Request Handler

    private func addRequestHandlers() {
        addPlaylistHandler()
        addSegmentHandler()
    }

    private func addPlaylistHandler() {
        webServer.addHandler(forMethod: "GET", pathRegex: "^/.*\\.m3u8$", request: GCDWebServerRequest.self) { [weak self] request, completion in
          guard let self = self else {
            return completion(GCDWebServerDataResponse(statusCode: 500))
          }

          guard let originURL = self.originURL(from: request) else {
            return completion(GCDWebServerErrorResponse(statusCode: 400))
          }

          let task = self.urlSession.dataTask(with: originURL) { data, response, error in
            guard let data = data, let response = response else {
              return completion(GCDWebServerErrorResponse(statusCode: 500))
            }
            
            DDLogInfo("[HLSReverseProxyServer] HLS playlist data size: \(data.count)")
            DDLogVerbose("[HLSReverseProxyServer] HLS playlist content: \(String(data: data, encoding: .utf8) ?? "")")

            let playlistData = self.reverseProxyPlaylist(with: data, forOriginURL: originURL)
            let contentType = response.mimeType ?? "application/x-mpegurl"
            completion(GCDWebServerDataResponse(data: playlistData, contentType: contentType))
          }

          task.resume()
        }
    }

    private func addSegmentHandler() {
        webServer.addHandler(forMethod: "GET", pathRegex: "^/.*\\.ts$", request: GCDWebServerRequest.self) { [weak self] request, completion in
          guard let self = self else {
            return completion(GCDWebServerDataResponse(statusCode: 500))
          }

          guard let originURL = self.originURL(from: request) else {
            return completion(GCDWebServerErrorResponse(statusCode: 400))
          }

          let task = self.urlSession.dataTask(with: originURL) { data, response, error in
            guard let data = data, let response = response else {
              return completion(GCDWebServerErrorResponse(statusCode: 500))
            }
            
            DDLogInfo("[HLSReverseProxyServer] HLS segment data size: \(data.count)")

            let contentType = response.mimeType ?? "video/mp2t"
            completion(GCDWebServerDataResponse(data: data, contentType: contentType))
          }

          task.resume()
        }
    }

    private func originURL(from request: GCDWebServerRequest) -> URL? {
        guard let encodedURLString = request.query?[Self.originURLKey] else { return nil }
        guard var urlString = encodedURLString.removingPercentEncoding else { return nil }
        
        // Only add the Subsonic API query parameters to the initial playlist request
        if request.url.pathExtension == "m3u8", !urlString.contains("?"), let query = request.url.query {
            // Use the query property of the original URL as GCDWebServer doesn't support
            // multiple entries for the same query parameter in it's query dictionary
            urlString += "?" + query
        }
        
        let url = URL(string: urlString)
        DDLogVerbose("[HLSReverseProxyServer] originURL: \(url?.absoluteString ?? "")")
        return url
    }


    // MARK: Manipulating Playlist

    private func reverseProxyPlaylist(with data: Data, forOriginURL originURL: URL) -> Data {
        return String(data: data, encoding: .utf8)!
          .components(separatedBy: .newlines)
          .map { line in processPlaylistLine(line, forOriginURL: originURL) }
          .joined(separator: "\n")
          .data(using: .utf8)!
    }

    private func processPlaylistLine(_ line: String, forOriginURL originURL: URL) -> String {
        guard !line.isEmpty else { return line }

        if line.hasPrefix("#") {
          return lineByReplacingURI(line: line, forOriginURL: originURL)
        }

        if let originalSegmentURL = absoluteURL(from: line, forOriginURL: originURL),
          let reverseProxyURL = reverseProxyURL(from: originalSegmentURL) {
          return reverseProxyURL.absoluteString
        }

        return line
    }

    private func lineByReplacingURI(line: String, forOriginURL originURL: URL) -> String {
        let uriPattern = try! NSRegularExpression(pattern: "URI=\"(.*)\"")
        let lineRange = NSMakeRange(0, line.count)
        guard let result = uriPattern.firstMatch(in: line, options: [], range: lineRange) else { return line }

        let uri = (line as NSString).substring(with: result.range(at: 1))
        guard let absoluteURL = absoluteURL(from: uri, forOriginURL: originURL) else { return line }
        guard let reverseProxyURL = reverseProxyURL(from: absoluteURL) else { return line }

        return uriPattern.stringByReplacingMatches(in: line, options: [], range: lineRange, withTemplate: "URI=\"\(reverseProxyURL.absoluteString)\"")
    }

    private func absoluteURL(from line: String, forOriginURL originURL: URL) -> URL? {
        guard ["m3u8", "ts"].contains(originURL.pathExtension) else { return nil }

        if line.hasPrefix("http://") || line.hasPrefix("https://") {
          return URL(string: line)
        }

        guard let scheme = originURL.scheme, let host = originURL.host else { return nil }
        
        let originPort = originURL.port ?? 80

        let path: String
        if line.hasPrefix("/") {
          path = line
        } else {
          path = originURL.deletingLastPathComponent().appendingPathComponent(line).path
        }

        let absoluteURL = URL(string: scheme + "://" + host + ":\(originPort)" + path)?.standardized
        DDLogVerbose("[HLSReverseProxyServer] absoluteURL: \(absoluteURL?.absoluteString ?? "")")
        return absoluteURL
    }
}
