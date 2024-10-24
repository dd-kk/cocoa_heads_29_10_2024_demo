//
//  File.swift
//  
//
//  Created by User on 15.10.2024.
//

import Foundation
import Combine

extension OperationUseCase {
    func pause(for delay: TimeInterval) -> AnyPublisher<Void, Never> {
        Timer
            .publish(
                every: delay,
                on: RunLoop.main,
                in: .common
            )
            .autoconnect()
            .first()
            .map({ _ in () })
            .eraseToAnyPublisher()
    }
}
