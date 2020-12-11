//
//  HLSViewController.swift
//  AVBasicPlayback
//
//  Created by wl on 2020/12/11.
//

import UIKit
import AVKit


/// 使用的时候可以在storyboard中修改 Storyboard Entry Point
class HLSViewController: UIViewController {
    
    let button = UIButton(type: .system)
    var mediaSelectionMap: [AVAssetDownloadTask : AVMediaSelection]  = [:]
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var downloadTask: AVAssetDownloadTask?
    
    
    let downloadIdentifier = "Download"
    var configuration: URLSessionConfiguration!
    var downloadSession: AVAssetDownloadURLSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    @objc func setupAssetDownload() {
        guard configuration == nil else {
            return
        }
        // 1. 后台session配置
        configuration = URLSessionConfiguration.background(withIdentifier: downloadIdentifier)
        
        // 2.创建 AVAssetDownloadURLSession,设置代理及回调线程
        downloadSession = AVAssetDownloadURLSession(configuration: configuration,
                                                    assetDownloadDelegate: self,
                                                    delegateQueue: OperationQueue.main)
        
        
        // 3.创建asset,如果下载失败，可以更换测试链接
        let url = URL(string: "http://demo.unified-streaming.com/video/tears-of-steel/tears-of-steel.ism/.m3u8")!
        let asset = AVURLAsset(url: url)
        
        // 4.创建下载任务
        downloadTask = downloadSession.makeAssetDownloadTask(asset: asset,
                                                             assetTitle: "master",
                                                             assetArtworkData: nil,
                                                             options: nil)
        // 5.开始下载
        downloadTask?.resume()
        print("start download")
        
        button.setTitle("Downloading", for: .normal)
        button.isEnabled = false
        
        // 使用downloadTask.urlAsset进行播放
        let playerItem = AVPlayerItem(asset: downloadTask!.urlAsset)
        player = AVPlayer(playerItem: playerItem)
        player?.play()
        
        playerLayer = AVPlayerLayer(player: player!)
        playerLayer?.backgroundColor = UIColor.red.cgColor
        playerLayer?.frame = CGRect(x: 100, y: 100, width: 100, height: 100)
        view.layer.addSublayer(playerLayer!)
        
    }
    
    func restorePendingDownloads() {
        // 1. 根据Identifierr创建URLSessionConfiguration
        configuration = URLSessionConfiguration.background(withIdentifier: downloadIdentifier)
        
        // 2. 创建AVAssetDownloadURLSession
        downloadSession = AVAssetDownloadURLSession(configuration: configuration,
                                                    assetDownloadDelegate: self,
                                                    delegateQueue: OperationQueue.main)
        
        // 3. 获取所有下载任务
        downloadSession.getAllTasks { tasksArray in
            // 4.遍历
            for task in tasksArray {
                guard let downloadTask = task as? AVAssetDownloadTask else { break }
                // 5. 恢复状态，下载进度等
                let asset = downloadTask.urlAsset
                print(asset)
            }
        }
    }
    
    func playOfflineAsset() {
        guard let assetPath = UserDefaults.standard.value(forKey: "assetPath") as? String else {
            print("没有离线资源可以播放")
            return
        }
        let baseURL = URL(fileURLWithPath: NSHomeDirectory())
        let assetURL = baseURL.appendingPathComponent(assetPath)
        let asset = AVURLAsset(url: assetURL)
        if let cache = asset.assetCache, cache.isPlayableOffline {
            // 设置 player item 和 player 开始播放
        } else {
            // 不能进行播放
        }
    }
    
    func deleteOfflineAsset() {
        do {
            //删除已下载的文件
            let userDefaults = UserDefaults.standard
            if let assetPath = userDefaults.value(forKey: "assetPath") as? String {
                let baseURL = URL(fileURLWithPath: NSHomeDirectory())
                let assetURL = baseURL.appendingPathComponent(assetPath)
                try FileManager.default.removeItem(at: assetURL)
                userDefaults.removeObject(forKey: "assetPath")
            }
        } catch {
            print("删除失败: \(error)")
        }
    }

    
    
    func setupUI() {
        button.setTitle("Download", for: .normal)
        button.addTarget(self, action: #selector(setupAssetDownload), for: .touchUpInside)
        
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        button.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
        
    }
    
    func nextMediaSelection(_ asset: AVURLAsset) -> (mediaSelectionGroup: AVMediaSelectionGroup?,
                                                     mediaSelectionOption: AVMediaSelectionOption?) {
        
        // 如果没有缓存,return nil
        guard let assetCache = asset.assetCache else {
            return (nil, nil)
        }
        
        // 遍历
        for characteristic in [AVMediaCharacteristic.audible, AVMediaCharacteristic.legible] {
            
            if let mediaSelectionGroup = asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
                
                // 获取已经下载完成的媒体文件
                let savedOptions = assetCache.mediaSelectionOptions(in: mediaSelectionGroup)
                
                // 如果还有没下载完成的媒体文件
                if savedOptions.count < mediaSelectionGroup.options.count {
                    for option in mediaSelectionGroup.options {
                        if !savedOptions.contains(option) {
                            // retun 以便继续下载
                            return (mediaSelectionGroup, option)
                        }
                    }
                }
            }
        }
        // 所有媒体文件已经下载完成
        return (nil, nil)
    }
    
}

extension HLSViewController: AVAssetDownloadDelegate {
    
    //如果此方法一直不回调,你可以尝试更换hls URL链接进行测试
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        var percentComplete = 0.0
        // 1.遍历
        for value in loadedTimeRanges {
            // 2.获取下载的时间
            let loadedTimeRange = value.timeRangeValue
            // 3.累计
            percentComplete += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
        }
        percentComplete *= 100
        button.setTitle("\(percentComplete)", for: .normal)
        print("\(percentComplete)")
    }
    
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        // 不要对下载的资源进行移动
        print(location.relativePath)
        // 保存相对路径,后续可以使用相对路径在沙盒中找到文件
        UserDefaults.standard.set(location.relativePath, forKey: "assetPath")
        
        button.setTitle("Download", for: .normal)
        button.isEnabled = true
    }
    
    // 如果发现了字幕文件或者替代音轨文件等,这个方法会回调
    func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didResolve resolvedMediaSelection: AVMediaSelection) {
        // 保存下载任务,下载完成后进行业务处理
        mediaSelectionMap[assetDownloadTask] = resolvedMediaSelection
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        button.setTitle("Download", for: .normal)
        button.isEnabled = true
        
        guard error == nil else {
            print("下载失败",error!.localizedDescription)
            return
        }
        guard let task = task as? AVAssetDownloadTask else { return }
        
        // 取出下载对象
        let mediaSelectionPair = nextMediaSelection(task.urlAsset)
        
        if let group = mediaSelectionPair.mediaSelectionGroup,
           let option = mediaSelectionPair.mediaSelectionOption {
            
            // 如果字典中没有保存mediaSelection,不进行下载
            guard let originalMediaSelection = mediaSelectionMap[task] else { return }
            
            // 拷贝
            let mediaSelection = originalMediaSelection.mutableCopy() as! AVMutableMediaSelection
            mediaSelection.select(option, in: group)
            
            // 创建媒体下载链接
            let options = [AVAssetDownloadTaskMediaSelectionKey: mediaSelection]
            let task = downloadSession.makeAssetDownloadTask(asset: task.urlAsset,
                                                             assetTitle: "title",
                                                             assetArtworkData: nil,
                                                             options: options)
            
            // 开始下载
            task?.resume()
            
        } else {
            //所有下载任务已完成
        }
    }
    
    
}
