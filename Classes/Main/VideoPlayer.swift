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
    @Injected private var settings: Settings
    @Injected private var audioEngine: AudioEngine
    
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
    
    func playVideo(song: Song, bitrates: [Int]? = nil) {
        let isVideoSupported = settings.currentServer?.isVideoSupported ?? false
        guard song.isVideo && isVideoSupported else { return }
        
        // Get the default bitrates if none provided
        let bitRate = bitrates ?? settings.currentVideoBitrates.map { $0.intValue }
        
        // Stop the player
        audioEngine.player?.stop()
        
        // If we're on HTTPS, use our proxy to allow for playback from a self signed server
        // TODO: Right now we always use the proxy server as even if it's http, if the server has https enabled, it will forward requests there. In the future, it would be better to first test if it's possible to play without the proxy even with https (in case they are using a legit SSL cert) and then also enable picture in picture mode and airplay.
        let proxyServer = HLSReverseProxyServer()
        proxyServer.start()
        self.hlsProxyServer = proxyServer
        
        // Play the video
        let parameters: [String: Any] = ["id": song.id, "bitRate": bitRate]
        guard let request = URLRequest(serverId: song.serverId, subsonicAction: "hls", parameters: parameters) else {
            DDLogError("[VideoPlayer] failed to create URLRequest to load HLS video with parameters \(parameters)")
            return
        }
        
        if let url = request.url, let scheme = url.scheme, let host = url.host, let port = url.port {
            var urlString = "http://localhost:\(proxyServer.port)\(url.relativePath)?\(url.path)"
            let originUrlString = "\(scheme)://\(host):\(port)\(url.path)"
            urlString += "&__hls_origin_url=\(originUrlString)"
            
            if let playerUrl = URL(string: urlString) {
                let player = AVPlayer(url: playerUrl)
                player.allowsExternalPlayback = false // Disable AirPlay since it won't work with the proxy server
                
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
