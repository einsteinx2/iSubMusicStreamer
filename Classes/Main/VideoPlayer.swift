//
//  VideoPlayer.swift
//  iSub
//
//  Created by Benjamin Baron on 1/18/21.
//  Copyright © 2021 Ben Baron. All rights reserved.
//

import UIKit
import AVKit
import CocoaLumberjackSwift
import Resolver

final class VideoPlayer: NSObject {
    @Injected private var settings: SavedSettings
    @Injected private var player: BassPlayer
    
    private var videoPlayerController: AVPlayerViewController?
    private var hlsProxyServer: HLSReverseProxyServer?
    
    // MARK: Lifecycle
    
    override init() {
        super.init()
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(playVideo(notification:)), name: Notifications.playVideo)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(removeVideoPlayer(notification:)), name: Notifications.removeVideoPlayer)
    }
    
    deinit {
        NotificationCenter.removeObserverOnMainThread(self)
    }
    
    // MARK: Notifications
    
    @objc private func playVideo(notification: Notification) {
        if let song = notification.userInfo?["song"] as? Song {
            playVideo(song: song)
        }
    }
    
    @objc private func removeVideoPlayer(notification: Notification) {
        if let videoPlayerController = videoPlayerController {
            videoPlayerController.dismiss(animated: true) {
                self.videoPlayerController = nil
            }
        }
    }
    
    // MARK: Video Playback
    
    func playVideo(song: Song, bitrates: [String]? = nil) {
        let isVideoSupported = settings.currentServer?.isVideoSupported ?? false
        guard let bitRate = bitrates ?? settings.currentVideoBitrates, song.isVideo && isVideoSupported else { return }
        
        // Stop the player
        player.stop()
        
        // Play the video
        let parameters: [String: Any] = ["id": song.id, "bitRate": bitRate]
        guard let request = URLRequest(serverId: song.serverId, subsonicAction: .hls, parameters: parameters) else {
            DDLogError("[VideoPlayer] failed to create URLRequest to load HLS video with parameters \(parameters)")
            return
        }
        
        if let url = request.url, let scheme = url.scheme, let host = url.host {
            if url.scheme == "https" && settings.isInvalidSSLCert {
                // While regular HTTP or valid HTTPS works fine with AVPlayer, self-signed SSL does not
                // Many Subsonic servers are unfortunately set up with self-signed SSL, so we need to use a local HTTP proxy to work around this
                // While it should be possible, and much cleaner, to use an AVAssetResourceLoader to do this, Apple explicitly prevents it from working...so this is the only working solution I've found
                
                var originUrlComponents = URLComponents()
                originUrlComponents.scheme = scheme
                originUrlComponents.host = host
                originUrlComponents.port = url.port
                originUrlComponents.path = url.path
                
                guard let originUrlString = originUrlComponents.url?.absoluteString,
                      let originalQueryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else {
                    return
                }
                
                var urlComponents = URLComponents()
                urlComponents.scheme = "http"
                urlComponents.host = "localhost"
                urlComponents.port = HLSReverseProxyServer.port
                urlComponents.path = url.relativePath
                urlComponents.queryItems = originalQueryItems + [URLQueryItem(name: "__hls_origin_url", value: originUrlString)]
                
                if let playerUrl = urlComponents.url {
                    let proxyServer = HLSReverseProxyServer()
                    if proxyServer.start() {
                        hlsProxyServer = proxyServer
                        
                        // Don't allow external playback because it won't work using this local proxy
                        startVideoPlayer(url: playerUrl, allowsExternalPlayback: false)
                    } else {
                        DDLogError("[VideoPlayer] failed to start the HTTP proxy")
                    }
                }
            } else {
                startVideoPlayer(url: url, allowsExternalPlayback: true)
            }
        }
    }
    
    private func startVideoPlayer(url: URL, allowsExternalPlayback: Bool) {
        let player = AVPlayer(url: url)
        player.allowsExternalPlayback = allowsExternalPlayback
        
        let controller = AVPlayerViewController()
        controller.delegate = self
        controller.player = player
        controller.allowsPictureInPicturePlayback = false
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = true
        self.videoPlayerController = controller
        
        UIApplication.keyWindow?.rootViewController?.present(controller, animated: true) {
            do {
                // Start audio session
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Allow audio playback when mute switch is on
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                
                // Auto-start playback
                player.play()
            } catch {
                DDLogError("[AppDelegate] Failed to prepare audio session for video playback: \(error)")
            }
        }
    }
}

extension VideoPlayer: AVPlayerViewControllerDelegate {
    func playerViewController(_ playerViewController: AVPlayerViewController, willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate(alongsideTransition: nil) { context in
            // If the window has been dismissed (superview is nil), clean up the player controller
            if playerViewController.view.superview == nil {
                // Clean up the player controller
                playerViewController.player?.pause()
                playerViewController.player?.rate = 0
                playerViewController.player = nil
                self.videoPlayerController = nil
                
                // Clean up proxy server
                self.hlsProxyServer?.stop()
                self.hlsProxyServer = nil
                
                // TODO: Figure out where to put this, currently it always prints this error: Deactivating an audio session that has running I/O. All I/O should be stopped or paused prior to deactivating the audio session.
//                do {
//                    // Clean up audio session
//                    try AVAudioSession.sharedInstance().setActive(false)
//                } catch {
//                    DDLogError(@"[AppDelegate] Failed to deactivate audio session for video playback: \(error)")
//                }
            }
        }
    }
}
