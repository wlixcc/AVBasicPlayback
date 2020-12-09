//
//  ViewController.swift
//  AVBasicPlayback
//
//  Created by wl on 2020/12/9.
//

import UIKit
import AVKit
import AVFoundation

class ViewController: UIViewController {
    
    let playButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    @objc func playVideo() {
        //1.这是一个HTTP Live Streaming流媒体链接,用于测试。 如果一直加载不出来,你也可以使用工程中的视频作为测试
        guard let url = URL(string: "https://devimages-cdn.apple.com/samplecode/avfoundationMedia/AVFoundationQueuePlayer_HLS2/master.m3u8") else {
            return
        }
        //        guard let url = Bundle.main.url(forResource: "sample-mp4-file", withExtension: "mp4") else {
        //            return
        //        }
        
        //2. 创建AVPlayer
        let player = AVPlayer(url: url)
        
        //3. 创建AVPlayerViewController,并设置player
        let controller = AVPlayerViewController()
        controller.player = player
        
        //4. 显示
        present(controller, animated: true) {
            player.play()
        }
        
    }
    
    func setupUI() {
        playButton.setTitle("Play Video", for: .normal)
        playButton.addTarget(self, action: #selector(playVideo), for: .touchUpInside)
        
        view.addSubview(playButton)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        playButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
    }
}


