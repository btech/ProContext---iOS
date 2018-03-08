//
//  Flag.swift
//  RainMan
//
//  Created by me on 1/31/18.
//  Copyright © 2018 b. All rights reserved.
//

import Foundation

class Flag: Hashable {
    
    var hashValue: Int {   return name.hashValue   }
    
    let name: Flag.Name
    
    init(name: Flag.Name) {
        
        self.name = name
    }
    
    class Name: Hashable {
        
        var hashValue: Int {   return rawValue.hashValue   }
        
        let rawValue: String
        
        init(_ rawValue: String) {
            
            self.rawValue = rawValue
            
            // Declare use of flag name
            Context.global.declare(useOf: self)
        }
        
        static func ==(lhs: Flag.Name, rhs: Flag.Name) -> Bool {
            
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    static func ==(lhs: Flag, rhs: Flag) -> Bool {
        
        return lhs.name == rhs.name
    }
}
