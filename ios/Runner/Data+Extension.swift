//
//  Data+Extension.swift
//  Runner
//
//  Created by mytooyo on 2023/03/25.
//

import Foundation

extension Data {
    mutating func shapeForBle(sendTo: @escaping ((UnsafePointer<UInt8>, Int) -> Void)) {
        // データサイズ
        let totalSize = self.count
        self.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            /// ポインター形式変換
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            // 1度に送信できるサイズは1KBまでのため、1024を上限としてチャンク分割を行う
            let uploadChunkSize = BLEConst.kStreamMaxSize
            // オフセット
            var offset = 0
            // オフセットがサイズを超えるまで繰り返し
            while offset < totalSize {
                // チャックのサイズを算出
                let chunkSize = offset + uploadChunkSize > totalSize ? totalSize - offset : uploadChunkSize
                // 送信するチャンクデータを取得
                var chunk = Data(bytesNoCopy: ptr + offset, count: chunkSize, deallocator: .none)
                
                let diff = uploadChunkSize - chunkSize;
                var data = ""
                for _ in 0..<diff {
                    data.append(" ")
                }
                chunk.append(data.data(using: .utf8)!)
                
                // 送信するための形式に変換
                chunk.withUnsafeBytes { chunkRaw in
                    guard let chunkPtr = chunkRaw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    sendTo(chunkPtr, chunk.count)
                }
                offset += chunkSize
            }
        }
    }
}
