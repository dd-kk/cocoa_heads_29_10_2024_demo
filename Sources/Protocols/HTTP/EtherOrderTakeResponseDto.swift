//
//  EtherOrderTakeResponseDto.swift
//
//
//  Created by User on 15.10.2024.
//

import Foundation

public struct EtherOrderTakeResponseDto {
    public enum EtherOrderTakeResponse {
        case accepted, processing, declined(String)
    }
    public let result: EtherOrderTakeResponse
    
    public init(result: EtherOrderTakeResponse) {
        self.result = result
    }
}

public struct HTTPError: Error {
    public let userInfo: [AnyHashable: Any]
    
    public init(userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo
    }
    // ...
}
