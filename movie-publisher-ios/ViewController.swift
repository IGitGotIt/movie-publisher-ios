//
//  ViewController.swift
//  movie-publisher-ios
//
//  Created by iujie on 24/11/2022.
//

import UIKit
import OpenTok

extension Date {
    var millisecondsSince1970:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}



// Replace with your OpenTok API key
let kApiKey = "44935341"
// Replace with your generated session ID
let kSessionId = "2_MX40NDkzNTM0MX5-MTY4NTk5NDEzNzgxOH4xa3RsRllEcTk2UEcvSkpnaXFPZFdmaUt-fn4"
// Replace with your generated token
let kToken = "T1==cGFydG5lcl9pZD00NDkzNTM0MSZzaWc9Zjg3MzE1ZGUzNzc1ZWZkOThlYmQ0ZjZhYTgyZGY2M2YzNmI4OWI1MjpzZXNzaW9uX2lkPTJfTVg0ME5Ea3pOVE0wTVg1LU1UWTROVGs1TkRFek56Z3hPSDR4YTNSc1JsbEVjVGsyVUVjdlNrcG5hWEZQWkZkbWFVdC1mbjQmY3JlYXRlX3RpbWU9MTY4NTk5NDEzOCZub25jZT0wLjczODY1MzAyNjg1MDQxOSZyb2xlPW1vZGVyYXRvciZleHBpcmVfdGltZT0xNjg2MDgwNTM4JmluaXRpYWxfbGF5b3V0X2NsYXNzX2xpc3Q9"

let kWidgetHeight: CGFloat = 240
let kWidgetWidth: CGFloat = 320
let screenSize: CGRect = UIScreen.main.bounds;
let screenWidth = screenSize.width;
let screenHeight = screenSize.height;
let videoPublisherName = "videoPublisher"
let videoFileName = "vonage_roadshow"

class ViewController: UIViewController {
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()

    var publisher: OTPublisher?
    var subscriber: OTSubscriber?
    var capturer: VideoCapturer?
    var firstCaptionTextRcvd = false
    var timeCaptionStartMarker : Int64 = 0
    let timeVideoFirstTalk: Int64 = Int64(8.4 * 1000)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        doConnect()
    }
    
    private func doConnect() {
        var error: OTError?
        defer {
            process(error: error)
        }
        session.perform(Selector(("setApiRootURL:")), with: NSURL(string: "https://api.dev.opentok.com"))
        session.connect(withToken: kToken, error: &error)
    }
    
    fileprivate func doPublish() {
        var error: OTError? = nil
        defer {
            process(error: error)
        }

        let settings = OTPublisherSettings()
        settings.name = videoPublisherName
        
        publisher = OTPublisher(delegate: self, settings: settings)
       
   
        
        if let path = Bundle.main.path(forResource: videoFileName, ofType: "mp4", inDirectory: "") {
            let videoUrl = URL.init(fileURLWithPath: path)

            capturer = VideoCapturer(url: videoUrl)

            let customAudioDevice = CustomAudioDevice(url: videoUrl, videoCapturer: capturer!)
            OTAudioDeviceManager.setAudioDevice(customAudioDevice)



        }
        publisher?.publishCaptions = false
        //  publisher?.videoCapture = capturer
        session.publish(publisher!, error: &error)
       
        
        if let pubView = publisher?.view {
            pubView.frame = CGRect(x: 0, y: 0, width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(pubView)
        }
    
    }
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            process(error: error)
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        subscriber?.captionsDelegate = self
        session.subscribe(subscriber!, error: &error)
    }
    fileprivate func process(error err: OTError?) {
        if let e = err {
            showAlert(errorStr: e.localizedDescription)
        }
    }
    
    fileprivate func showAlert(errorStr err: String) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: "Error", message: err, preferredStyle: .alert)
            controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(controller, animated: true, completion: nil)
        }
    }
    
    fileprivate func cleanupSubscriber() {
       subscriber?.view?.removeFromSuperview()
       subscriber = nil
    }
    
    fileprivate func cleanupPublisher() {
        publisher?.view?.removeFromSuperview()
        publisher = nil
    }
 
// For disconnect button
    @IBAction func didClick(_ sender: UIButton) {
        var error: OTError?
        defer {
            process(error: error)
        }
        if (sender.titleLabel!.text == "Disconnect") {
            if (publisher != nil) {
                session.unpublish(publisher!, error: &error)
            }
            session.disconnect(&error)
            sender.setTitle("Connect", for: .normal)
        }
        else {
            doConnect()
            sender.setTitle("Disconnect", for: .normal)
        }
    }
}


extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
        cleanupSubscriber()
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
       // doSubscribe(stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        cleanupSubscriber()
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        doSubscribe(stream)
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        print("publisher stream destroyed")
        cleanupPublisher()
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// MARK: - OTSubscriber delegate callbacks
extension ViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        publisher?.publishCaptions = true
        subscriber?.subscribeToCaptions = true
        timeCaptionStartMarker = Date().millisecondsSince1970
        
        print("subscriberDidConnect \(timeCaptionStartMarker)")
        if let subsView = subscriber?.view {
            subsView.frame = CGRect(x: 0, y: kWidgetHeight , width: kWidgetWidth, height: kWidgetHeight)
            view.addSubview(subsView)
        
        }
    }

    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }

    func subscriberVideoDataReceived(_ subscriber: OTSubscriber) {
    }
}

extension ViewController : OTSubscriberKitCaptionsDelegate {
    func subscriber(_ subscriber: OTSubscriberKit, caption text: String, isFinal: Bool) {
        if !firstCaptionTextRcvd  {
            let currentTime = Date().millisecondsSince1970
            let delta = currentTime - (timeCaptionStartMarker + timeVideoFirstTalk)
            if delta < 0 {
             //   print("why \(text)")
            }
           // print("*** Captions Round trip in ms:" + "\(delta)" )
            print("\(text)")
            //firstCaptionTextRcvd = true
            //timeCaptionStartMarker = 0
        }

    }
}

