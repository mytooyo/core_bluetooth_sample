//
//  CentralController.swift
//  Runner
//
//  Created by mytooyo on 2023/03/25.
//

import Foundation
import CoreBluetooth

protocol CentralControllerDelegate: AnyObject {
    func central(opened stream: OutputStream)
    
    func central(message: String)
}

class CentralController: NSObject {
    
    /// シングルトン
    static let shared:CentralController = CentralController()
    
    /// BLEセントラルマネージャー
    private var manager: CBCentralManager?
    
    /// 自分自身のUID
    private var uuid: CBUUID!
    
    /// 接続中のサービスUUID
    private var connectedUUIDs: [CBUUID]!
    
    /// L2CAP接続に利用するPSM
    private var psm: CBL2CAPPSM!
    
    /// L2CAPチャネル
    private var streams: BLEStream?
    
    /// 接続したPeripheral
    private var peripheral: CBPeripheral?
    
    weak var delegate: CentralControllerDelegate?
    
    /// 検索開始
    func start(uidString: String) {
        self.uuid = CBUUID(string: uidString)
        // マネージャーインスタンス生成
        // インスタンスを生成すると下記の`centralManagerDidUpdateState`メソッドが呼ばれる
        self.manager = CBCentralManager(delegate : self, queue : nil)
    }
    
    func stop() {
        self.streams?.disconnect()
        self.manager?.stopScan()
        if let p = self.peripheral {
            self.manager?.cancelPeripheralConnection(p)
        }
       
    }
}


// MARK: CBCentralManagerDelegate
extension CentralController: CBCentralManagerDelegate {
    /// Bluetoothの状態変更コールバック
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // BluetoothがONでない場合は後続処理は行わない
        if central.state != .poweredOn {
            print("[error] bluetooth powered not on")
            return
        }
        
        // スキャンを開始
        let options: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: false)
        ]
        self.manager?.scanForPeripherals(withServices: nil, options: options)
    }
    
    /// サービススキャンした結果のコールバック
    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String : Any],
        rssi RSSI: NSNumber
    ) {
        // `advertisementData`の"kCBAdvDataServiceUUIDs"にServiceのUUIDが設定されるため、
        // Advertisingした際のIDが存在するか確認して、存在するデバイスに接続する
        guard let name = advertisementData["kCBAdvDataLocalName"] as? String,
              name == BLEConst.kServiceName,
              let ids = advertisementData["kCBAdvDataServiceUUIDs"] as? [CBUUID]
        else {
            return
        }
        
        print("central manager: [\(name)] -> \(ids)")
        
        // 接続状態を保存
        self.connectedUUIDs = ids
        self.peripheral = peripheral
        self.peripheral?.delegate = self
        
        //　スキャンを停止して接続する
        self.manager?.stopScan()
        self.manager?.connect(peripheral, options: nil)
    }
    
    /// ペリフェラルとの接続が完了した場合のコールバック
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("connected to peripheral")
        // Peripheralが提供しているサービスをUUID指定で検索する
        peripheral.discoverServices(self.connectedUUIDs)
    }
    
    /// 接続に失敗した際のコールバック
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("[central error] did fail to connect: \(String(describing: error))")
    }
    
    /// 接続が切れた際のコールバック
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("[central error] disconnected peripheral with error: \(error)")
            return
        }
        print("disconnected peripheral")
    }
        
}

// MARK: CBPeripheralDelegate
extension CentralController: CBPeripheralDelegate {
    /// PeripheralのServiceが見つかった際のコールバック
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if (error != nil) {
            print("[error central] discover services \(error!.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        
        // 見つかったサービスを取得
        for service in services {
            if self.connectedUUIDs.contains(service.uuid) {
                // サービスに紐づくCharacteristicを検索しり
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    /// ServiceのCharacteristicsが見つかった場合に呼ばれる
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if (error != nil) {
            print("[error central] discover characterostics \(error!.localizedDescription)")
            return
        }
        
        // 見つかったCharacteristicsを取得
        guard let characteristics = service.characteristics else {
            print("no data characteristics")
            return
        }
        
        // 必要なCharacteristicsが存在するか確認
        guard let c = characteristics.filter({ d in d.uuid.uuidString == BLEConst.kCharacteristicsPSM}).first else {
            print("[error cantral] no psm characteristcs")
            return
        }
        
        // チャネルオープンするために必要なPSM値を取得するためのリクエスト
        // (PSM値は毎回同じだが、変更されることがあるのか..)
        peripheral.readValue(for: c)
    }
    
    /// readValueリクエストに対する返却値
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("did update value characteristic: \( characteristic.uuid.uuidString)")
        let uuid = characteristic.uuid.uuidString
        
        switch uuid {
        case BLEConst.kCharacteristicsPSM:
            // PSM取得
            // 構造体に変換
            guard let data = try? JSONDecoder().decode(BLEPSMIF.self, from: characteristic.value!) else {
                return
            }
            self.psm = CBL2CAPPSM(data.psm)
            // チャネルオープン
            peripheral.openL2CAPChannel(self.psm!)
            break
        default:
            break
        }
    }
    
    /// L2CAPチャネルオープン
    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        if let err = error {
            print("[central error] opening channel: \(err.localizedDescription)")
            return
        }
        guard let channel = channel else { return }
        self.streams = BLEStream(channel: channel)
        self.streams?.delegate = self
    }
}

// MARK: BLEStreamDelegate
extension CentralController: BLEStreamDelegate {
    
    /// オープンされたストリーム
    func bleStream(stream opened: OutputStream) {
        self.delegate?.central(opened: opened)
    }
    
    /// メッセージ受信
    func bleStream(message: String) {
        self.delegate?.central(message: message)
    }
}


