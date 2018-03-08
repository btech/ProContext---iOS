//
//  Requestable.swift
//  RainMan
//
//  Created by me on 2/6/18.
//  Copyright © 2018 b. All rights reserved.
//

import Foundation

class Requestable {
    
    let name: Requestable.Name
    let server: () -> Any?
    let isRequestable: () -> Bool
    let isExpired: () -> Bool
    
    init(name: Requestable.Name, server: @escaping () -> Any?, isRequestable: @escaping () -> Bool, isExpired: @escaping () -> Bool) {
        
        self.name = name
        self.server = server
        self.isRequestable = isRequestable
        self.isExpired = isExpired
    }
    
    func request() throws -> Any? {
        
        guard !isExpired() else {   throw RequestingExpiredRequestable()   }
        
        guard isRequestable() else {   throw RequestingUnrequestableRequestable()   }
        
        return server()
    }
    
    class Name: Hashable {
        
        var hashValue: Int {   return rawValue.hashValue   }
        
        let rawValue: String
        
        init(_ rawValue: String) {
            
            self.rawValue = rawValue
            
            // Declare use of requestable name
            Context.global.declare(useOf: self)
        }
        
        static func ==(lhs: Requestable.Name, rhs: Requestable.Name) -> Bool {
            
            return lhs.rawValue == rhs.rawValue
        }
    }
}

struct RequestingExpiredRequestable: Error {
    
    var localizedDescription: String {   return "Cannot request an expired requestable"   }
}
struct RequestingUnrequestableRequestable: Error {
    
    var localizedDescription: String {   return "Cannot request an unrequestable requestable"   }
}
