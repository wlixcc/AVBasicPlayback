//
//  ViewController.swift
//  AVBasicPlayback
//
//  Created by wl on 2020/12/9.
//

import UIKit
import AVKit
import AVFoundation
import MediaPlayer

class ViewController: UIViewController {
    
    let playButton = UIButton(type: .system)

    
    let url: URL = Bundle.main.url(forResource: "sample-mp4-file", withExtension: "mp4")!
    var asset: AVAsset!
    var player: AVPlayer!
    var playerItem: AVPlayerItem!
    var playerViewController: AVPlayerViewController!
    var timeObserverToken: Any?
    
    // Key-value observing context
    private var playerItemContext = 0
    // 需要加载的属性
    let requiredAssetKeys = [
        "playable",
        "hasProtectedContent"
    ]
    
    // PIPController
    let startButton = UIButton(type: .system)
    let stopButton = UIButton(type: .system)
    var playerLayer: AVPlayerLayer!
    var pictureInPictureController: AVPictureInPictureController!
    var pictureInPictureControllerContext = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPlayer()
        setupRemoteTransportControls()
        setupInterruptionNotification()
        setupRouteChangeNotification()
    }
    
    @objc func playVideo() {
        present(playerViewController, animated: true) {
            self.player.play()
            self.setupNowPlaying()
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

//MARK: 创建AVAsset并且异步加载属性
extension ViewController {
    
    func loadPlayable() {
        //1. 加载本地视频
        let url = Bundle.main.url(forResource: "sample-mp4-file", withExtension: "mp4")!
        let asset = AVAsset(url: url)
        let playableKey = "playable"
        
        //2 判断属性是否可用
        let status = asset.statusOfValue(forKey: playableKey, error: nil)
        if status != .loaded {
            print("playable unloaded")
        }
        //千万不要直接读取,这样可能会造成线程堵塞
        //asset.isPlayable
        
        //3. 加载"playable"属性
        asset.loadValuesAsynchronously(forKeys: [playableKey]) {
            var error: NSError? = nil
            let status = asset.statusOfValue(forKey: playableKey, error: &error)
            switch status {
            case .loaded:
                print("loaded, playable:\(asset.isPlayable)")
            case .failed:
                print("failed")
            case .cancelled:
                print("cancelled")
            default:break
            }
        }
    }
}

//MARK: 加载元数据
extension ViewController {
    func loadMetaData() {
        //1. 加载本地视频
        let url = Bundle.main.url(forResource: "sample-mp4-file", withExtension: "mp4")!
        let asset = AVAsset(url: url)
        let formatsKey = "availableMetadataFormats"
        let commonMetadataKey = "commonMetadata"
        
        //2. 加载属性
        asset.loadValuesAsynchronously(forKeys: [formatsKey, commonMetadataKey]) {
            var error: NSError? = nil
            
            //3 获取Format-specific key spaces下的元数据
            let formatsStatus = asset.statusOfValue(forKey: formatsKey, error: &error)
            if formatsStatus == .loaded {
                for format in asset.availableMetadataFormats {
                    let metaData = asset.metadata(forFormat: format)
                    print(metaData)
                }
            }
            
            //4 获取Common key space 下的元数据
            let commonStatus = asset.statusOfValue(forKey: commonMetadataKey, error: &error)
            if commonStatus == .loaded {
                let metadata = asset.commonMetadata
                print(metadata)
                //5 通过Identifier获取AVMetadataItem
                let titleID: AVMetadataIdentifier = .commonIdentifierTitle
                let titleItems = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: titleID)
                if let item = titleItems.first {
                    //6 处理title item
                    print(item)
                }
            }
        }
    }
}

// MARK: 一个简单的播放示例
extension ViewController {
    func setupPlayer()  {
        // 创建AVAsset对象
        asset = AVAsset(url: url)
        
        // 创建AVPlayerItem对象
        playerItem = AVPlayerItem(asset: asset)
        
        // 创建AVPlayer
        player = AVPlayer(playerItem: playerItem)
        
        // 关联
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.delegate = self
        
    }
}


//MARK: 监听播放状态
extension ViewController {
    func prepareToPlay() {
        // 1.创建AVAsset
        asset = AVAsset(url: url)
        
        // 2.创建AVPlayerItem,并且在readyToPlay状态之前加载所有需要的属性
        playerItem = AVPlayerItem(asset: asset,
                                  automaticallyLoadedAssetKeys: requiredAssetKeys)
        
        // 3.KVO
        playerItem.addObserver(self,
                               forKeyPath: #keyPath(AVPlayerItem.status),
                               options: [.old, .new],
                               context: &playerItemContext)
        
        // 4.创建AVPlayer
        player = AVPlayer(playerItem: playerItem)
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        
        // 只对playerItemContext进行处理
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }
            // Switch over status value
            switch status {
            case .readyToPlay:
                print("加载完成")
            case .failed:
                print("加载失败")
            case .unknown:
                print("未知状态")
            default:break
            }
        }
    }
}

//MARK: 基于时间对视频进行操作
extension ViewController {
    func timeBasedOperations() {
        // 60/60 = 1秒
        let oneSecond = CMTime(value: 60, timescale: 60)
        // 1/4 = 0.25秒
        let quarterSecond = CMTime(value: 1, timescale: 4)
        // 441000/44100 = 10秒
        let tenSeconds = CMTime(value: 441000, timescale: 44100)
        // 90/30 = 3秒
        let cursor = CMTime(value: 90, timescale: 30)
        
        print(oneSecond, quarterSecond, tenSeconds, cursor)
    }
    
    
    func addPeriodicTimeObserver() {
        // 每半秒回调一次
        let timeScale = CMTimeScale(NSEC_PER_SEC)
        let time = CMTime(seconds: 0.5, preferredTimescale: timeScale)
        
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: time,
                                                           queue: .main) {
            [weak self] time in
            guard let self = self else { return }
            //在这里进行你的业务逻辑
            print("\(self.player.currentTime())")
        }
    }
    
    func removePeriodicTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
    func addBoundaryTimeObserver() {
        // 视频每播放1/4我们进行一次回调
        let interval = CMTimeMultiplyByFloat64(asset.duration, multiplier: 0.25)
        var currentTime = CMTime.zero
        var times = [NSValue]()
        
        // 添加时间节点
        while currentTime < asset.duration {
            currentTime = currentTime + interval
            times.append(NSValue(time:currentTime))
        }
        
        timeObserverToken = player.addBoundaryTimeObserver(forTimes: times,
                                                           queue: .main) {
            //在这里进行你的业务逻辑
            print(self.player.currentTime())
        }
    }
    
    func removeBoundaryTimeObserver() {
        if let timeObserverToken = timeObserverToken {
            player.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
    }
    
}

//MARK: 调整时间
extension ViewController {
    func seekToTime() {
        // 2分钟
        let time = CMTime(value: 120, timescale: 1)
        player.seek(to: time)
    }
    
    func seekToTimeAccuracy() {
        // 10秒的第一帧。 这里不用觉得CMTime计算的时间不对,视频的帧率由视频本身决定,preferredTimescale设置一个极大的值就可以了
        let seekTime = CMTime(seconds: 10, preferredTimescale: Int32(NSEC_PER_SEC))
        // 设置tolerance 为CMTime.zero 不允许有误差
        player.seek(to: seekTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero)
    }
    
}

//MARK: AVPlayerViewControllerDelegate
extension ViewController: AVPlayerViewControllerDelegate {
    //在这里处理App的恢复逻辑
    func playerViewController(_ playerViewController: AVPlayerViewController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        //重新present playerViewController
        present(playerViewController, animated: true) {
            //通知系统我们已经完成了视频的界面恢复
            completionHandler(true)
        }
    }
}

// MARK: AVPictureInPictureController
extension ViewController {
    
    func setupPictureInPicture() {
        // 开始画中画播放的按钮
        let startImage = AVPictureInPictureController.pictureInPictureButtonStartImage(compatibleWith: nil)
        startButton.addTarget(self, action: #selector(togglePictureInPictureMode(_:)), for: .touchUpInside)
        startButton.setTitle("startPIP", for: .normal)
        startButton.setImage(startImage, for: .normal)
        view.addSubview(startButton)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        startButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 10).isActive = true
        
        // 停止画中画播放按钮
        let stopImage = AVPictureInPictureController.pictureInPictureButtonStopImage(compatibleWith: nil)
        stopButton.addTarget(self, action: #selector(togglePictureInPictureMode(_:)), for: .touchUpInside)
        stopButton.setTitle("stopPIP", for: .normal)
        stopButton.setImage(stopImage, for: .normal)
        view.addSubview(stopButton)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stopButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 10).isActive = true
        
        
        // 判断设备是否支持画中画
        if AVPictureInPictureController.isPictureInPictureSupported() {
            player = AVPlayer(url: url)
            //创建AVPlayerLayer
            playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
            view.layer.addSublayer(playerLayer)
            playerLayer.player?.play()
            
            // 创建AVPictureInPictureController
            pictureInPictureController = AVPictureInPictureController(playerLayer: playerLayer)
            pictureInPictureController.delegate = self

        } else {
            // 不支持画中画
            startButton.isEnabled = false
            stopButton.isEnabled = false
        }
    }
    
    // 切换画中画状态
    @objc func togglePictureInPictureMode(_ sender: UIButton) {
        if pictureInPictureController.isPictureInPictureActive {
            //停止
            pictureInPictureController.stopPictureInPicture()
        } else {
            //开始
            pictureInPictureController.startPictureInPicture()
        }
    }

}

// MARK: AVPictureInPictureControllerDelegate
extension ViewController: AVPictureInPictureControllerDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        //在这里进行用户视频播放界面的恢复逻辑
        print("restore")
        completionHandler(true)
    }
    
    func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //显示placeholder,隐藏播放控件等操作
        print("will start")
    }
    
    func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        //隐藏placeholder,恢复播放控件等操作
        print("will stop")
    }
    
}

// MARK: 远程控制&锁屏界面显示
extension ViewController {
    func setupRemoteTransportControls() {
        try! AVAudioSession.sharedInstance().setActive(true)
        
        // 获取 MPRemoteCommandCenter
        let commandCenter = MPRemoteCommandCenter.shared()
     
        // 播放控制
        commandCenter.playCommand.addTarget { [unowned self] event in
            if self.player.rate == 0.0 {
                self.player.play()
                return .success
            }
            return .commandFailed
        }
     
        //  停止控制
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            if self.player.rate == 1.0 {
                self.player.pause()
                return .success
            }
            return .commandFailed
        }
    }
    
    func setupNowPlaying() {
        // 由我们自己控制锁屏界面的显示
//        playerViewController.updatesNowPlayingInfoCenter = false
        
        // 设置显示内容
        var nowPlayingInfo = [String : Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = "My Movie"
        if let image = UIImage(named: "lockscreen") {
            nowPlayingInfo[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: image.size) { size in
                    return image
            }
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = playerItem.currentTime().seconds
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = playerItem.asset.duration.seconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
     
        // 提交给MPNowPlayingInfoCenter
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
}

// MARK: 音频路由
extension ViewController {
    func setupInterruptionNotification() {
        let notificationCenter = NotificationCenter.default
           notificationCenter.addObserver(self,
                                          selector: #selector(handleInterruption),
                                          name: AVAudioSession.interruptionNotification,
                                          object: nil)
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
        }
        if type == .began {
            // 中断请求触发,在这里处理你的业务逻辑
        }
        else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    // 系统会自动恢复播放 （通话结束）
                } else {
                    // 系统不会自动恢复播放
                }
            }
        }
    }
    
    func setupRouteChangeNotification() {
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self,
                                       selector: #selector(handleRouteChange),
                                       name: AVAudioSession.routeChangeNotification,
                                       object: nil)
    }
    
    
    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
             let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
             let reason = AVAudioSession.RouteChangeReason(rawValue:reasonValue) else {
                 return
         }
         switch reason {
         case .newDeviceAvailable:
            //耳机插入、蓝牙连接等情况
            
             let session = AVAudioSession.sharedInstance()
            //获取当前路由信息
            for output in session.currentRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                 //耳机已连接
                 //headphonesConnected = true
                 break
             }
         case .oldDeviceUnavailable:
            //耳机拔出、蓝牙断开等情况
            
            //获取先前的路由信息
             if let previousRoute =
                 userInfo[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription {
                for output in previousRoute.outputs where output.portType == AVAudioSession.Port.headphones {
                    //耳机已断开连接
                     //headphonesConnected = false
                     break
                 }
             }
         default: ()
         }
    }

}



