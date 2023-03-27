//
//  BLEStream.swift
//  Runner
//
//  Created by mytooyo on 2023/03/25.
//

import Foundation
import CoreBluetooth

protocol BLEStreamDelegate: AnyObject {
    
    /// オープンされたストリーム
    func bleStream(stream opened: OutputStream)
    
    /// メッセージ受信
    func bleStream(message: String)
}

class BLEStream: NSObject, StreamDelegate {
    
    /// L2CAPチャネル
    private var channel: CBL2CAPChannel
    
    weak var delegate: BLEStreamDelegate?
    
    /// 処理中のメッセージ
    private var message: String?
    
    init(channel: CBL2CAPChannel) {
        self.channel = channel
        super.init()
        
        /// ストリームオープン
        self.channel.outputStream?.delegate = self
        self.channel.outputStream?.schedule(in: .current, forMode: .default)
        self.channel.outputStream?.open()
        
        /// ストリームオープン
        self.channel.inputStream?.delegate = self
        self.channel.inputStream?.schedule(in: .current, forMode: .default)
        self.channel.inputStream?.open()
    }
    
    /// ストリーム切断
    func disconnect() {
        self.channel.inputStream?.close()
        self.channel.outputStream?.close()
    }
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        var streamType: String = "input"
        if aStream == self.channel.outputStream {
            streamType = "output"
        }
        
        switch eventCode {
        case .openCompleted:
            // ストリームオープン
            print("[stream - \(streamType)] open completed")
            
            if streamType == "output" {
                self.delegate?.bleStream(stream: self.channel.outputStream!)
            }
            break
        case .hasBytesAvailable:
            // データ受信
            print("[stream - \(streamType)] has bytes available")
            if let inputStream = self.channel.inputStream {
                self.onStream(stream: inputStream)
            }
            break
        case .hasSpaceAvailable:
            // データ送信可能
            print("[stream - \(streamType)] has space available")
            break
        case .errorOccurred:
            print("[stream - \(streamType)] errorOccurred: \(String(describing: aStream.streamError?.localizedDescription))")
            break
        case .endEncountered:
            // ストリーム切断
            print("[stream - \(streamType)] end encountered")
            self.disconnect()
            break
        default:
            break
        }
    }
    
    /// データ受信
    func onStream(stream: InputStream) {
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: BLEConst.kStreamMaxSize)
        
        // データ格納用に定義
        var data = Data()
        // ストリームからデータ読み込み
        let count = stream.read(buffer, maxLength: BLEConst.kStreamMaxSize)
        // データサイズが0以上の場合はデータに追加
        if 0 < count {
            data.append(buffer, count: count)
        }
        
        // 送信されたデータがテキストデータの場合
        guard let str = String(data: data, encoding: .utf8) else {
            return
        }
        
        let trimed = str.trimmingCharacters(in: .whitespaces)
        if trimed.isEmpty { return }
        
        // EOFが含まれている場合
        if trimed.contains("EOF") {
            // EOFで分割
            let list = trimed.components(separatedBy: "EOF")
            if list.isEmpty { return }
            
            // EOF前後に文字列が存在する場合は一旦EOF前までで区切り、
            // 以降の文字列は別メッセージとして処理
            for i in 0 ..< list.count {
                if list[i].isEmpty {
                    continue
                }
                
                // メッセージを追加してコールバック
                self.setMessage(msg: list[i])
                // 最後のインデックスで値が空でない場合はEOFで完結していないため
                // メッセージ追加のみ
                if i == list.count - 1 && !list[i].isEmpty {
                    continue
                }
                self.delegate?.bleStream(message: self.message!)
                self.message = nil
            }
            
        }
        // 含まれていない場合はメッセージに追加しておく
        else {
            self.setMessage(msg: trimed)
        }

    }
    
    private func setMessage(msg: String) {
        if self.message == nil {
            self.message = msg
        } else {
            self.message!.append(msg)
        }
    }
}
