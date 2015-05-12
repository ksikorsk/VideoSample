//
//  AVAsset.swift
//  FaceOff
//
//  Created by Kamil Sikorski on 2015-05-04.
//  Copyright (c) 2015 Shnarped. All rights reserved.
//

import UIKit
import AVFoundation

extension AVAssetTrack {
    var videoOrientation: UIImageOrientation {
        var size :CGSize = self.naturalSize
        var txf :CGAffineTransform = self.preferredTransform
        
        if size.width == txf.tx && size.height == txf.ty {
            return .Left
        } else if txf.tx == 0 && txf.ty == 0 {
            return .Right
        } else if txf.tx == 0 && txf.ty == size.width {
            return .Down
        } else {
            return .Up
        }
    }
}

extension AVAsset {
    @objc func cropVideo(squareSize: CGFloat, offset: CGPoint, handler: ((NSURL?) -> Void)?) {
        
        println("Composable: \(self.composable)")
        println("Exportable: \(self.exportable)")
        println("Protected: \(self.hasProtectedContent)")
        
        var mixComposition :AVMutableComposition = AVMutableComposition()
        
        var trackID = Int32(kCMPersistentTrackID_Invalid)
        
        // 2 - Video track
        var videoTrack :AVMutableCompositionTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: trackID)
        
        videoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, self.duration), ofTrack: self.tracksWithMediaType(AVMediaTypeVideo)[0] as! AVAssetTrack, atTime: kCMTimeZero, error: nil)
        
        var audioTracks = self.tracksWithMediaType(AVMediaTypeAudio)
        
        if !audioTracks.isEmpty {
            // create an audio avassetrack with our asset
            var clipAudioTrack = audioTracks[0] as! AVAssetTrack
            
            // add audio track to composition
            var compositionAudioTrack :AVMutableCompositionTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: trackID)
            compositionAudioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, self.duration), ofTrack: clipAudioTrack, atTime: kCMTimeZero, error: nil)
        }
        
        // create a video avassetrack with our asset
        var clipVideoTrack :AVAssetTrack = self.tracksWithMediaType(AVMediaTypeVideo)[0] as! AVAssetTrack
        
        println("Frame Rate: \(clipVideoTrack.nominalFrameRate)")
        
        // create a video composition and preset some settings
        var videoComposition :AVMutableVideoComposition = AVMutableVideoComposition(propertiesOfAsset: self)
        
        // Set the frame rate
        var frameDuration = clipVideoTrack.minFrameDuration
        
        println("Frame Duration: (\(frameDuration.value), \(frameDuration.timescale))")
        videoComposition.frameDuration = frameDuration
        
        var currentSize = videoComposition.renderSize
        var newSize = squareSize
        newSize = min(newSize, currentSize.width)
        newSize = min(newSize, currentSize.height)
        var size = CGSizeMake(newSize, newSize)
        
        // Set the render size
        println("Render Size: (\(size.width), \(size.height))")
        videoComposition.renderSize = size
        
        // create a video instruction
        var instruction :AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        // Create the range in the timeframe scale
        var timeRange = clipVideoTrack.timeRange
        
        var start = timeRange.start
        println("Time Range Start: (\(start.value), \(start.timescale))")
        var duration = timeRange.duration
        println("Time Range Duration: (\(duration.value), \(duration.timescale))")
        instruction.timeRange = timeRange
        
        var transformer :AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        // Scale is the max of horizontal and vertical scale
        var scaleV = size.height / clipVideoTrack.naturalSize.height
        var scaleH = size.width / clipVideoTrack.naturalSize.width
        var scale = max(scaleV, scaleH)
        
        var t1 :CGAffineTransform
        var t2 :CGAffineTransform
        var t3 :CGAffineTransform = CGAffineTransformIdentity
        
        // Different translations depending on orientiation of the video
        switch clipVideoTrack.videoOrientation {
        case .Up:
            t1 = CGAffineTransformMakeTranslation((clipVideoTrack.naturalSize.height * scale) - offset.x, -offset.y)
            t2 = CGAffineTransformScale(t1, scale, scale)
            t3 = CGAffineTransformRotate(t2, CGFloat(M_PI_2))
            break
        case .Down:
            t1 = CGAffineTransformMakeTranslation(-offset.x, (clipVideoTrack.naturalSize.width * scale) - offset.y)
            t2 = CGAffineTransformScale(t1, scale, scale)
            t3 = CGAffineTransformRotate(t2, -CGFloat(M_PI_2))
            break
        case .Right:
            t1 = CGAffineTransformMakeTranslation(-offset.x, -offset.y)
            t2 = CGAffineTransformScale(t1, scale, scale)
            t3 = CGAffineTransformRotate(t2, 0)
            break
        case .Left:
            t1 = CGAffineTransformMakeTranslation((clipVideoTrack.naturalSize.width * scale) - offset.x, (clipVideoTrack.naturalSize.height * scale) - offset.y)
            t2 = CGAffineTransformScale(t1, scale, scale)
            t3 = CGAffineTransformRotate(t2, CGFloat(M_PI))
            break
        default:
            NSLog("No supported orientation found")
        }
        
        // add the transformer layer instructions, then add to video composition
        transformer.setTransform(t3, atTime: kCMTimeZero)
        instruction.layerInstructions = NSArray(object: transformer) as [AnyObject]
        videoComposition.instructions = NSArray(object: instruction) as [AnyObject]
        
        var outputhPath = "\(NSTemporaryDirectory())newoutput_crop.mp4"
        var exportUrl :NSURL = NSURL(fileURLWithPath: outputhPath)!
        
        NSFileManager.defaultManager().removeItemAtURL(exportUrl, error: nil)
        
        var exporter :AVAssetExportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)
        exporter.videoComposition = videoComposition
        exporter.outputURL = exportUrl
        exporter.outputFileType = AVFileTypeMPEG4
        //        exporter.timeRange = timeRange
        
        exporter.exportAsynchronouslyWithCompletionHandler { () -> Void in
            switch exporter.status{
            case  AVAssetExportSessionStatus.Failed:
                println("failed crop: \(exporter.error)")
                handler?(nil)
            case AVAssetExportSessionStatus.Cancelled:
                println("cancelled crop: \(exporter.error)")
                handler?(nil)
            default:
                println("completed crop")
                println(exportUrl)
                handler?(exportUrl)
            }
        }
    }
    
    @objc func changeRate(range: CMTimeRange, scaleFactor: Double, handler: ((NSURL?) -> Void)?) {
        // create mutable composition
        var mainComposition :AVMutableComposition = AVMutableComposition()
        
        var error :NSError?
        
        // create a video avassetrack with our asset
        var clipVideoTrack :AVAssetTrack = self.tracksWithMediaType(AVMediaTypeVideo)[0] as! AVAssetTrack
        
        // add video tracks to composition
        var compositionVideoTrack :AVMutableCompositionTrack = mainComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
        var videoInsertResult = compositionVideoTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, self.duration), ofTrack: clipVideoTrack, atTime: kCMTimeZero, error: &error)
        
        if (!videoInsertResult || error != nil) {
            //handle error
            println("failed change rate: \(error?.localizedDescription)")
            return;
        }
        
        var timescale = clipVideoTrack.naturalTimeScale
        var seconds = CMTimeGetSeconds(range.duration)
        var newSeconds = seconds * scaleFactor
        
        var newDuration = CMTimeMakeWithSeconds(newSeconds, timescale)
        
        var oldRange = CMTimeRangeMake(CMTimeMakeWithSeconds(CMTimeGetSeconds(range.start), timescale), CMTimeMakeWithSeconds(seconds, timescale))
        
        //change rate
        compositionVideoTrack.scaleTimeRange(oldRange, toDuration: newDuration)
        
        // Do the same with audio if an audio track exists
        var audioTracks = self.tracksWithMediaType(AVMediaTypeAudio)
        
        if !audioTracks.isEmpty {
            // create an audio avassetrack with our asset
            var clipAudioTrack = audioTracks[0] as! AVAssetTrack
            
            // add audio track to composition
            var compositionAudioTrack :AVMutableCompositionTrack = mainComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid))
            
            var audioInsertResult = compositionAudioTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, self.duration), ofTrack: clipAudioTrack, atTime: kCMTimeZero, error: &error)
            
            if (!audioInsertResult || nil != error) {
                //handle error
                return;
            }
            
            compositionAudioTrack.scaleTimeRange(oldRange, toDuration: newDuration)
            
            compositionAudioTrack.validateTrackSegments(compositionAudioTrack.segments, error: &error)
            if (error != nil) {
                println("failed change rate: \(error?.localizedDescription)")
                return;
            }
        }
        
        compositionVideoTrack.validateTrackSegments(compositionVideoTrack.segments, error: &error)
        if (error != nil) {
            println("failed change rate: \(error?.localizedDescription)")
            return;
        }
        
        //export
        var outputhPath = "\(NSTemporaryDirectory())newoutput_rate.mp4"
        var exportUrl :NSURL = NSURL(fileURLWithPath: outputhPath)!
        
        NSFileManager.defaultManager().removeItemAtURL(exportUrl, error: nil)
        
        var exporter :AVAssetExportSession = AVAssetExportSession(asset: mainComposition, presetName: AVAssetExportPresetHighestQuality)
        exporter.outputURL = exportUrl
        exporter.outputFileType = AVFileTypeMPEG4
        exporter.audioTimePitchAlgorithm = AVAudioTimePitchAlgorithmVarispeed
        
        exporter.exportAsynchronouslyWithCompletionHandler { () -> Void in
            switch exporter.status{
            case  AVAssetExportSessionStatus.Failed:
                println("failed change rate: \(exporter.error)")
                handler?(nil)
            case AVAssetExportSessionStatus.Cancelled:
                println("cancelled change rate: \(exporter.error)")
                handler?(nil)
            default:
                println("completed change rate")
                println(exportUrl)
                handler?(exportUrl)
            }
        }
    }
    
    @objc func setRange(range :CMTimeRange, rate: Int32, handler: ((NSURL?) -> Void)?) {
        // create an avassetrack with our asset
        var clipVideoTrack :AVAssetTrack = self.tracksWithMediaType(AVMediaTypeVideo)[0] as! AVAssetTrack
        
        // create a video composition and preset some settings
        var videoComposition :AVMutableVideoComposition = AVMutableVideoComposition()
        
        var currentDuration = clipVideoTrack.minFrameDuration
        println("Current Frame Duration: (\(currentDuration.value), \(currentDuration.timescale))")
        // The frame duration time scale should be value * rate, with a max of current timescale
        var frameDuration = CMTimeMake(currentDuration.value, min(currentDuration.timescale, Int32(currentDuration.value) * rate))
        println("Frame Duration: (\(frameDuration.value), \(frameDuration.timescale))")
        
        // Set the frame rate
        videoComposition.frameDuration = frameDuration
        
        // Set the render size
        var size = clipVideoTrack.naturalSize
        println("Render Size: (\(size.width), \(size.height))")
        videoComposition.renderSize = size
        
        // create a video instruction
        var instruction :AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction()
        
        // Set the range
        var start = range.start
        println("Time Range Start: (\(start.value), \(start.timescale))")
        var duration = range.duration
        println("Time Range Duration: (\(duration.value), \(duration.timescale))")
        instruction.timeRange = range
        
        // add the transformer layer instructions, then add to video composition
        var transformer :AVMutableVideoCompositionLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: clipVideoTrack)
        instruction.layerInstructions = NSArray(object: transformer) as [AnyObject]
        
        videoComposition.instructions = NSArray(object: instruction) as [AnyObject]
        
        var outputhPath = "\(NSTemporaryDirectory())newoutput_range.mp4"
        var exportUrl :NSURL = NSURL(fileURLWithPath: outputhPath)!
        
        NSFileManager.defaultManager().removeItemAtURL(exportUrl, error: nil)
        
        var exporter :AVAssetExportSession = AVAssetExportSession(asset: self, presetName: AVAssetExportPresetHighestQuality)
        exporter.videoComposition = videoComposition
        exporter.shouldOptimizeForNetworkUse = true
        exporter.outputURL = exportUrl
        exporter.outputFileType = AVFileTypeMPEG4
        exporter.timeRange = range
        
        exporter.exportAsynchronouslyWithCompletionHandler { () -> Void in
            switch exporter.status{
            case  AVAssetExportSessionStatus.Failed:
                println("failed set range: \(exporter.error)")
                handler?(nil)
            case AVAssetExportSessionStatus.Cancelled:
                println("cancelled set range: \(exporter.error)")
                handler?(nil)
            default:
                println("completed set range")
                println(exportUrl)
                handler?(exportUrl)
            }
        }
    }
}