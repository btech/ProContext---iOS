//
//  Weak.swift
//  RainMan
//
//  Created by me on 12/7/17.
//  Copyright © 2017 b. All rights reserved.
//

import Foundation

class Weak<T: AnyObject>: Hashable where T: Hashable {
    
    let hashValue: Int
    
    weak private(set) var value: T?
    
    init(_ value: T) {
        
        self.value = value
        self.hashValue = value.hashValue
    }
    
    static func ==(lhs: Weak<T>, rhs: Weak<T>) -> Bool {
        
        return lhs.value == rhs.value
    }
}
