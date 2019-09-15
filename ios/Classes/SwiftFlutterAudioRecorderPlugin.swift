import Flutter
import UIKit
import AVFoundation

public class SwiftFlutterAudioRecorderPlugin: NSObject, FlutterPlugin, AVAudioRecorderDelegate {
    // status - unset, initialized, recording, paused, stopped
    var status = "unset"
    var hasPermissions = false
    var mExtension = ""
    var mPath = ""
    var channel = 0
    var startTime: Date!
    var settings: [String:Int]!
    var audioRecorder: AVAudioRecorder!
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_audio_recorder", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterAudioRecorderPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "current":
            print("current")
            
            if audioRecorder == nil {
                result(nil)
            } else {
                let dic = call.arguments as! [String : Any]
                channel = dic["channel"] as? Int ?? 0
                
                audioRecorder.updateMeters()
                let duration = Int(audioRecorder.currentTime * 1000)
                var recordingResult = [String : Any]()
                recordingResult["duration"] = duration
                recordingResult["path"] = mPath
                recordingResult["audioFormat"] = mExtension
                recordingResult["peakPower"] = audioRecorder.peakPower(forChannel: channel)
                recordingResult["averagePower"] = audioRecorder.averagePower(forChannel: channel)
                recordingResult["isMeteringEnabled"] = audioRecorder.isMeteringEnabled
                recordingResult["status"] = status
                result(recordingResult)
            }
        case "init":
            print("init")
            
            let dic = call.arguments as! [String : Any]
            mExtension = dic["extension"] as? String ?? ""
            mPath = dic["path"] as? String ?? ""
            print("m:", mExtension, mPath)
            startTime = Date()
            if mPath == "" {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
                mPath = documentsPath + "/" + String(Int(startTime.timeIntervalSince1970)) + ".m4a"
                print("path: " + mPath)
            }
            
            settings = [
                AVFormatIDKey: getOutputFormatFromString(mExtension),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: AVAudioSessionCategoryOptions.defaultToSpeaker)
                try AVAudioSession.sharedInstance().setActive(true)
                audioRecorder = try AVAudioRecorder(url: URL(string: mPath)!, settings: settings)
                audioRecorder.delegate = self
                audioRecorder.isMeteringEnabled = true
                audioRecorder.prepareToRecord()
            } catch {
                print("fail")
                result(FlutterError(code: "", message: "Failed to init", details: nil))
            }
            
            let duration = Int(audioRecorder.currentTime * 1000)
            status = "initialized"
            var recordingResult = [String : Any]()
            recordingResult["duration"] = duration
            recordingResult["path"] = mPath
            recordingResult["audioFormat"] = mExtension
            recordingResult["peakPower"] = 0
            recordingResult["averagePower"] = 0
            recordingResult["isMeteringEnabled"] = audioRecorder.isMeteringEnabled
            recordingResult["status"] = status
            
            result(recordingResult)
        case "start":
            print("start")
            
            if status == "initialized" {
                audioRecorder.record()
                status = "recording"
            }
            
            result(nil)
            
        case "stop":
            print("stop")
            
            if audioRecorder == nil || status == "unset" {
                result(nil)
            } else {
                audioRecorder.updateMeters()
                audioRecorder.stop()
                
                let duration = Int(audioRecorder.currentTime * 1000)
                status = "stopped"
                var recordingResult = [String : Any]()
                recordingResult["duration"] = duration
                recordingResult["path"] = mPath
                recordingResult["audioFormat"] = mExtension
                recordingResult["peakPower"] = audioRecorder.peakPower(forChannel: channel)
                recordingResult["averagePower"] = audioRecorder.averagePower(forChannel: channel)
                recordingResult["isMeteringEnabled"] = audioRecorder.isMeteringEnabled
                recordingResult["status"] = status
                
                audioRecorder = nil
                result(recordingResult)
            }
        case "pause":
            print("pause")
            
            if audioRecorder == nil {
                result(nil)
            }
            
            if status == "recording" {
                audioRecorder.pause()
                status = "paused"
            }
            
            result(nil)
        case "resume":
            print("resume")
            
            if audioRecorder == nil {
                result(nil)
            }
            
            if status == "paused" {
                audioRecorder.record()
                status = "recording"
            }
            
            result(nil)
        case "hasPermissions":
            print("hasPermissions")
            switch AVAudioSession.sharedInstance().recordPermission(){
            case AVAudioSession.RecordPermission.granted:
                print("granted")
                hasPermissions = true
                break
            case AVAudioSession.RecordPermission.denied:
                print("denied")
                hasPermissions = false
                break
            case AVAudioSession.RecordPermission.undetermined:
                print("undetermined")
                AVAudioSession.sharedInstance().requestRecordPermission() { [unowned self] allowed in
                    DispatchQueue.main.async {
                        if allowed {
                            self.hasPermissions = true
                        } else {
                            self.hasPermissions = false
                        }
                    }
                }
                break
            default:
                break
            }
            result(hasPermissions)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func getOutputFormatFromString(_ format : String) -> Int {
        switch format {
        case ".mp4", ".aac", ".m4a":
            return Int(kAudioFormatMPEG4AAC)
        default :
            return Int(kAudioFormatMPEG4AAC)
        }
    }
}