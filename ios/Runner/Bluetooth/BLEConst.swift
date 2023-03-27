//
//  BLEConst.swift
//  Runner
//
//  Created by mytooyo on 2023/03/25.
//

import Foundation
import CoreBluetooth

class BLEConst {
    
    /// Bluetooth接続で利用するサービス名
    static let kServiceName: String = "com.example.corebluetooth"
    
    /// Bluetooth接続Characteristics
    static let kCharacteristicsPSM = "0001"
    
    /// Bluetooth接続Characteristicsリスト
    static let kCharacteristicsList: [CBMutableCharacteristic] = [
        CBMutableCharacteristic(
            type: CBUUID(string: BLEConst.kCharacteristicsPSM),
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
    ]
    
    /// ストリームの最大サイズ
    static let kStreamMaxSize: Int = 1024
}

struct BLEPSMIF: Codable {
    var psm: Int
    enum CondingKeys: String, CodingKey {
        case psm
    }
}
