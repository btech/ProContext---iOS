//
//  Observer.swift
//  RainMan
//
//  Created by me on 2/2/18.
//  Copyright © 2018 b. All rights reserved.
//

import Foundation

class Observer {
    
    private let send: (Notification) -> Void
    let isObserving: () -> Bool
    let isExpired: () -> Bool
    
    init(send: @escaping (Notification) -> Void, isObserving: @escaping () -> Bool, isExpired: @escaping () -> Bool) {
        
        self.send = send
        self.isObserving = isObserving
        self.isExpired = isExpired
    }
    
    func notify(_ notification: Notification) throws {
        
        guard !isExpired() else {   throw NotifyingExpiredObserver()   }
        if isObserving() {   send(notification)   }
    }
}

struct NotifyingExpiredObserver: Error {}
