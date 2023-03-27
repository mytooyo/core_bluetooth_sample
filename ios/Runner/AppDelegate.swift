import UIKit
import Flutter
import CoreBluetooth

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    
    /// Flutter EventSink
    var eventSink: FlutterEventSink?
    /// Flutter EventChannel
    var eventChannel: FlutterEventChannel!
    
    /// 接続がオープンされたストリーム
    var openedStream: OutputStream?
    
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
        let controller = window?.rootViewController as! FlutterViewController
        let methodChannel = FlutterMethodChannel(name: "com.example/app", binaryMessenger: controller.binaryMessenger)
        
        methodChannel.setMethodCallHandler(handler)
        
        self.eventChannel = FlutterEventChannel(name: "com.example/app-event", binaryMessenger: controller.binaryMessenger)
        self.eventChannel.setStreamHandler(self)
        
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    func handler(call: FlutterMethodCall,  result: FlutterResult) {
        print("call method: \(call.method)")
        
        switch call.method {
        case "startAdvertising":
            PeripheralController.shared.start(uidString: "6873C1CD-61F2-4848-B8E0-3531B6903F0B")
            PeripheralController.shared.delegate = self
            result(nil)
            break
        case "stopAdvertising":
            PeripheralController.shared.stop()
            PeripheralController.shared.delegate = nil
            result(nil)
            break
        case "startCentral":
            CentralController.shared.start(uidString: "BE8F7BED-87DE-4DEF-887A-FE8C50D2C098")
            CentralController.shared.delegate = self
            result(nil)
            break
        case "stopCentral":
            CentralController.shared.stop()
            CentralController.shared.delegate = nil
            result(nil)
            break
        case "send":
            guard
                let args = call.arguments as? [String: Any],
                let text = args["data"] as? String
            else {
                return
            }
            self.sendData(text: text)
            result(nil)
            break
        default:
            break
        }
    }
    
    // データ送信
    func sendData(text: String) {
        var textData = text
        textData.append("EOF")
        var data = textData.data(using: .utf8)
        data?.shapeForBle { (ptr, length) in
            self.openedStream?.write(ptr, maxLength: length)
        }
    }
}

// MARK: FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        return nil
    }
    
    // Flutter側にイベントを送信
    func sink(_ event: String, body: [String: Any]? = nil) {
        guard let eventSink = self.eventSink else {
            return
        }
        var data: [String: Any] = ["event": event]
        if let b = body {
            data["body"] = b
        }
        eventSink(data)
    }
}

// MARK: CentralControllerDelegate
extension AppDelegate: CentralControllerDelegate {
    
    func central(opened stream: OutputStream) {
        self.openedStream = stream
        self.sink("connected")
    }
    
    func central(message: String) {
        self.sink("onmessage", body: ["data": message])
    }
}



// MARK: CentralControllerDelegate
extension AppDelegate: PeripheralControllerDelegate {
    
    func peripheral(opened stream: OutputStream) {
        self.openedStream = stream
        self.sink("connected")
    }
    
    func peripheral(message: String) {
        self.sink("onmessage", body: ["data": message])
    }
}
