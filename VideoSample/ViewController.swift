//
//  ViewController.swift
//  VideoSample
//
//  Created by Kamil Sikorski on 2015-05-12.
//  Copyright (c) 2015 Interactive Athletes Inc. All rights reserved.
//

import UIKit
import MediaPlayer
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var playerView: UIView!
    var moviePlayerController: MPMoviePlayerController!
    var videoURL: NSURL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        let path = NSBundle.mainBundle().bundlePath
        let bundle = NSBundle(path: "\(path)/VideoSample.bundle")!
        videoURL = bundle.URLForResource("Music", withExtension: "mov")!
        moviePlayerController = MPMoviePlayerController(contentURL: videoURL)
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        let bounds = CGRectMake(0, 0, playerView.bounds.width, playerView.bounds.height)
        moviePlayerController.view.frame = bounds
        playerView.addSubview(moviePlayerController.view)
        moviePlayerController.play()
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        let bounds = CGRectMake(0, 0, playerView.bounds.width, playerView.bounds.height)
        moviePlayerController.view.frame = bounds
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func musicTouch(sender: AnyObject) {
        let path = NSBundle.mainBundle().bundlePath
        let bundle = NSBundle(path: "\(path)/VideoSample.bundle")!
        videoURL = bundle.URLForResource("Music", withExtension: "mov")!
        moviePlayerController.contentURL = videoURL

        let bounds = CGRectMake(0, 0, playerView.bounds.width, playerView.bounds.height)
        moviePlayerController.view.frame = bounds
        moviePlayerController.play()
    }

    @IBAction func soccerTouch(sender: AnyObject) {
        let path = NSBundle.mainBundle().bundlePath
        let bundle = NSBundle(path: "\(path)/VideoSample.bundle")!
        videoURL = bundle.URLForResource("Soccer", withExtension: "mp4")!
        moviePlayerController.contentURL = videoURL
        
        let bounds = CGRectMake(0, 0, playerView.bounds.width, playerView.bounds.height)
        moviePlayerController.view.frame = bounds
        moviePlayerController.play()
    }
    
    @IBAction func cropTouch(sender: AnyObject) {
        SVProgressHUD.showWithStatus("Cropping", maskType: .Black)
        
        if let asset = AVAsset.assetWithURL(videoURL) as? AVAsset {
            asset.cropVideo(320, offset: CGPointZero, handler: { [weak self] (url) -> Void in
                if let videoURL = url {
                    SVProgressHUD.showSuccessWithStatus("Cropping Successful")
                    dispatch_async(dispatch_get_main_queue(), {
                        self?.videoURL = videoURL
                        self?.moviePlayerController.contentURL = videoURL
                        self?.moviePlayerController.play()
                    })
                } else {
                    SVProgressHUD.showErrorWithStatus("Cropping Failed")
                }
            })
        }
    }

    @IBAction func scaleTouch(sender: AnyObject) {
        SVProgressHUD.showWithStatus("Scaling", maskType: .Black)
        
        if let asset = AVAsset.assetWithURL(videoURL) as? AVAsset {
            let duration = asset.duration
            let seconds = CMTimeGetSeconds(duration)
            let rangeStart = CMTimeMakeWithSeconds(seconds * 0.25, duration.timescale)
            let rangeDuration = CMTimeMakeWithSeconds(seconds * 0.5, duration.timescale)
            let range = CMTimeRangeMake(rangeStart, rangeDuration)
            
            asset.changeRate(range, scaleFactor: 2.0, handler: { [weak self] (url) -> Void in
                if let videoURL = url {
                    SVProgressHUD.showSuccessWithStatus("Scaling Successful")
                    dispatch_async(dispatch_get_main_queue(), {
                        self?.videoURL = videoURL
                        self?.moviePlayerController.contentURL = videoURL
                        self?.moviePlayerController.play()
                    })
                } else {
                    SVProgressHUD.showErrorWithStatus("Scaling Failed")
                }
            })
        }
    }
}

