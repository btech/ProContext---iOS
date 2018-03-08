//
//  Executable.swift
//  RainMan
//
//  Created by me on 2/1/18.
//  Copyright © 2018 b. All rights reserved.
//

import Foundation

class Executable: Hashable {
    
    var hashValue: Int {return name.hashValue}
    
    private let name: Executable.Name
    private let function: () -> Void
    private let isExecutable: () -> Bool
    let isExpired: () -> Bool
    
    init(name: Executable.Name, execute: @escaping () -> Void, isExecutable: @escaping () -> Bool, isExpired: @escaping () -> Bool) {
        
        self.name = name
        self.function = execute
        self.isExecutable = isExecutable
        self.isExpired = isExpired
    }
    
    func execute() throws {
        
        guard !isExpired() else {   throw ExecutingExpiredExecutable()   }
        
        guard isExecutable() else {   throw ExecutingUnexecutableExecutable()   }
        
        function()
    }
    
    class Name: Hashable {
        
        var hashValue: Int {   return rawValue.hashValue   }
        
        let rawValue: String
        
        init(_ rawValue: String) {
            
            self.rawValue = rawValue
            
            // Declare use of executable name
            Context.global.declare(useOf: self)
        }
        
        static func ==(lhs: Executable.Name, rhs: Executable.Name) -> Bool {
            
            return lhs.rawValue == rhs.rawValue
        }
    }
    
    static func ==(lhs: Executable, rhs: Executable) -> Bool {
        
        return lhs.name == rhs.name
    }
}

struct ExecutingExpiredExecutable: Error {
    
    var localizedDescription: String {   return "Cannot execute an expired executable"   }
}
struct ExecutingUnexecutableExecutable: Error {
    
    var localizedDescription: String {   return "Cannot execute an unexecutable executable"   }
}
