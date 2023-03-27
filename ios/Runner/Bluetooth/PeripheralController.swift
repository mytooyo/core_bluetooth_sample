//
//  PeripheralController.swift
//  Runner
//
//  Created by mytooyo on 2023/03/25.
//

import Foundation
import CoreBluetooth

protocol PeripheralControllerDelegate: AnyObject {
    func peripheral(opened stream: OutputStream)
    
    func peripheral(message: String)
}

class PeripheralController: NSObject {
    
    /// シングルトン
    static let shared: PeripheralController = PeripheralController()
    
    /// BLEのペリフェラルマネージャー
    private var manager : CBPeripheralManager?
    
    /// 相手に認識させるUUID
    private var uuid: CBUUID!
    
    /// L2CAP接続に利用するPSM
    private var psm: CBL2CAPPSM!
    
    /// L2CAPチャネル
    private var streams: BLEStream?
    
    weak var delegate: PeripheralControllerDelegate?
    
    /// アドバタイズ開始
    func start(uidString: String) {
        self.uuid = CBUUID(string: uidString)
        self.manager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    /// アドバタイズ停止
    func stop() {
        self.streams?.disconnect()
        self.manager?.stopAdvertising()
    }
}

// MARK: CBPeripheralManagerDelegate
extension PeripheralController: CBPeripheralManagerDelegate {
    
    /// Bluetoothの状態変更コールバック
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // BluetoothがONでない場合は後続処理は行わない
        if peripheral.state != .poweredOn {
            print("[peripheral error] bluetooth powered not on")
            return
        }
        
        // サービス生成
        let service = CBMutableService(type: self.uuid, primary: true)
        // Characteristicsを設定
        service.characteristics = BLEConst.kCharacteristicsList
        
        // サービス追加
        self.manager?.add(service)
    }
    
    /// サービス追加コールバック
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let err = error {
            print("[peripheral error] \(err)")
            return
        }
        
        // 正常にサービス追加できたため、アドバタイズを開始する
        let data: [String: Any] = [
            CBAdvertisementDataLocalNameKey: BLEConst.kServiceName,
            CBAdvertisementDataServiceUUIDsKey: [service.uuid],
        ]
        peripheral.startAdvertising(data)
        // ストリーム送受信用のL2CAPチャネルをパブリッシュ
        peripheral.publishL2CAPChannel(withEncryption: true)
        
        print("success! start advertising: \(service.uuid.uuidString)")
    }
    
    /// アドバタイジング完了コールバック
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let err = error {
            print("[peripheral error] failed start advertising: \(err)")
            return
        }
        print("success! started advertising")
    }
    
    /// L2CAPパブリッシュ成功コールバック
    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        if let err = error {
            print("[peripheral error] publishing channel: \(err.localizedDescription)")
            return
        }
        self.psm = PSM
        print("published channel psm: \(PSM)")
    }
    
    /// L2CAPチャネルオープン成功コールバック
    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let err = error {
            print("[peripheral error] opening channel: \(err.localizedDescription)")
            return
        }
        print("did open L2CAP channel")
        guard let channel = channel else { return }
        self.streams = BLEStream(channel: channel)
        self.streams?.delegate = self
    }
    
    /// Central側からREADリクエストが来た際のコールバック
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        print("call method, didReceiveReadRequest: \(request.central.identifier)")
        let uuid = request.characteristic.uuid.uuidString
        
        switch uuid {
        case BLEConst.kCharacteristicsPSM:
            // PSM要求
            let psmValue = Int("\(self.psm!)")!
            let data = try! JSONEncoder().encode(BLEPSMIF(psm: psmValue))
            // リクエストに設定してレスポンス返却
            request.value = data
            peripheral.respond(to: request, withResult: .success)
            break
        default:
            break
        }
    }
}

// MARK: BLEStreamDelegate
extension PeripheralController: BLEStreamDelegate {
    
    /// オープンされたストリーム
    func bleStream(stream opened: OutputStream) {
        self.delegate?.peripheral(opened: opened)
    }
    
    /// メッセージ受信
    func bleStream(message: String) {
        self.delegate?.peripheral(message: message)
    }
}
