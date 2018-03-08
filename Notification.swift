//
//  Notification.swift
//  RainMan
//
//  Created by me on 1/30/18.
//  Copyright © 2018 b. All rights reserved.
//

import Foundation

class Notification {
    
    let name: Notification.Name
    let origin: Context
    let object: Any?

    init(name: Notification.Name, origin: Context, object: Any?) {
        
        self.name = name
        self.origin = origin
        self.object = object
    }
    
    class Name: Hashable {
        
        var hashValue: Int {   return rawValue.hashValue   }
        
        let rawValue: String
        
        init(_ rawValue: String) {
            
            self.rawValue = rawValue
            
            Context.global.declare(useOf: self)
        }
        
        static func ==(lhs: Notification.Name, rhs: Notification.Name) -> Bool {
            
            return lhs.rawValue == rhs.rawValue
        }
    }
}
