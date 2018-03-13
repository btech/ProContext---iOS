//
//  Context.swift
//  RainMan
//
//  Created by me on 12/7/17.
//  Copyright © 2017 b. All rights reserved.
//

import Foundation
import UIKit

class Context: Hashable {
    
    static var global = GlobalContext("global")

    var hashValue: Int {   return ObjectIdentifier(self).hashValue   }
    
    private(set) var name: String
    private(set) var supercontext: Context?
    private var subcontexts = Set<Weak<Context>>()
    private var requestableNamed = [Requestable.Name : Requestable]()
    private var observersFor = [Notification.Name : [Observer]]()
    private var flags = Set<Flag>()
    private var executableNamed = [Executable.Name : Executable]()
    
    private var contextTree: [Context] {
        
        return supercontextTree + [self] + subcontextTree
    }
    
    private var supercontextTree: [Context] {
        
        var sct = [Context]()
        var supercontext = self.supercontext
        while supercontext != nil {   sct.append(supercontext!); supercontext = supercontext!.supercontext   }
        
        return sct
    }
    
    private var subcontextTree: [Context] {
        
        var sct = subcontexts.map{   return $0.value!   }
        return subcontexts.reduce(into: sct){   $0.append(contentsOf: $1.value!.subcontextTree)   }
    }
    
    required init() {   self.name = ""   }
    
    fileprivate init(_ name: String, superContext: Context? = nil) {
        
        self.name = name
        self.supercontext = superContext
    }
    
    deinit {
        
        // Release self from super-context
        supercontext?.release(self)
    }
    
    func createSubcontext(_ name: String) -> Context {
        
        let subcontext = Context(name, superContext: self)
        return subcontexts.insert(Weak(subcontext)).memberAfterInsert.value!
    }
    
    func createSubcontext<T: Context>(ofType type: T.Type, named name: String? = nil) -> T {
        
        let subcontext = type.init()
        subcontext.name = name ?? "\(type)"
        subcontext.supercontext = self
        
        return subcontexts.insert(Weak(subcontext)).memberAfterInsert.value! as! T
    }
    
    func release(_ subcontext: Context) {
        
        subcontexts.remove(Weak(subcontext))
    }
    
    /**
     Adds a `Requestable` with the provided characteristics.
     
     - parameters:
         - name: The name of the `Requestable`.
         - server: The function that will provide the value the `Requestable` serves.
         - isRequestable: A function that returns a `Bool` indicating whether or not the `Requestable` is allowed to be requested.
         - isExpired: A function that returns a `Bool` indicating if the `Requestable` should be removed.
     
     - precondition: An unexpired `Requestable` with the provided `Requestable.Name` must not already exist in the context tree
    */
    func addRequestable(_ name: Requestable.Name,
                        serving server: @escaping () -> Any?,
                        if isRequestable: @escaping () -> Bool = { true },
                        expiresIf isExpired: @escaping () -> Bool = { false }) {
        
        crashOrRemoveRequestable(name)
        requestableNamed[name] = Requestable(name: name, server: server, isRequestable: isRequestable, isExpired: isExpired)
    }
    
    /// Same as `addRequestable(_:serving:if:expiresIf:)` but defines the `Requestable`
    /// as expired when the provided object is deallocated
    func addRequestable(_ name: Requestable.Name,
                        serving server: @escaping () -> Any?,
                        if isRequestable: @escaping () -> Bool = { true },
                        expiresWith object: AnyObject) {
        
        let isExpired = { [weak object] in object == nil }
        addRequestable(name, serving: server, if: isRequestable, expiresIf: isExpired)
    }
    
    /// Same as `addRequestable(_:serving:if:expiresWith:)` but defines the `Requestable` as
    /// requestable only if the view is in window.
    func addRequestable(_ name: Requestable.Name,
                        serving server: @escaping () -> Any?,
                        ifInWindow view: UIView) {
        
        let isRequestable = { [weak view] in view?.window != nil }
        addRequestable(name, serving: server, if: isRequestable, expiresWith: view)
    }
    
    
    /// Same as `addRequestable(_:serving:ifInWindow:)` but defines the `Requestable` as
    /// expired if the view is removed from the window.
    func addRequestable(_ name: Requestable.Name,
                        serving server: @escaping () -> Any?,
                        ifHasNotLeftWindow view: UIView) {
        
        let isRequestable = { [weak view] in view?.window != nil }
        let isExpired = { !isRequestable() }
        addRequestable(name, serving: server, if: isRequestable, expiresIf: isExpired)
    }
    
    /// Crashes the application if an unexpired requestable with the provided
    /// name already exists in the context tree; removes it if found, otherwise.
    func crashOrRemoveRequestable(_ name: Requestable.Name) {
        
        let contextWithRequestable: Context? = contextTree.reduce(nil, { return ($1.requestableNamed[name] != nil) ? $1 : $0 })
        guard contextWithRequestable == nil || contextWithRequestable!.requestableNamed[name]!.isExpired() else {
            
            fatalError("An unexpired requestable named \(name) already exists in context: \(contextWithRequestable!.name)")
        }
        contextWithRequestable?.requestableNamed[name] = nil
    }
    
    /**
     Returns the value by requesting it from the `Requestable` with the provided
     name, and casting it to the type indicated by the context in which `request(_:)`
     was called.
     
     - parameter name: The name of the `Requestable` to make the request of.
     
     - precondition: A `Requestable` with the provided name must exist at or
        above this context, and it must be unexpired and requestable.
    */
    func request<T>(_ name: Requestable.Name) -> T {
        
        if let requestable = requestableNamed[name] {
            
            do {   return try requestable.request() as Any as! T   }
            catch let e where e is RequestingExpiredRequestable || e is RequestingUnrequestableRequestable { fatalError(e.localizedDescription) }
            catch let e as NSError { print(e.localizedDescription) }
        }
        
        if supercontext != nil { return supercontext!.request(name) as T? as Any as! T }
        
        fatalError("A requestable named \(name.rawValue) has not been added")
    }
    
    func addObserver(for name: Notification.Name,
                     calling send: @escaping (Notification) -> Void,
                     if isObserving: @escaping () -> Bool,
                     expiresIf isExpired: @escaping () -> Bool) {

        let observer = Observer(send: send, isObserving: isObserving, isExpired: isExpired)
        observersFor[name, default: []].append(observer)
    }
    
    func addObserver(for names: Set<Notification.Name>,
                     calling send: @escaping (Notification) -> Void,
                     if isObserving: @escaping () -> Bool,
                     expiresIf isExpired: @escaping () -> Bool) {
        
        names.forEach { addObserver(for: $0, calling: send, if: isObserving, expiresIf: isExpired) }
    }
    
    func addObserver(for name: Notification.Name,
                     calling send: @escaping (Notification) -> Void,
                     if isObserving: @escaping () -> Bool,
                     expiresWith object: AnyObject) {
        
        let isExpired = { [weak object] in object == nil }
        addObserver(for: name, calling: send, if: isObserving, expiresIf: isExpired)
    }
    
    func addObserver(for names: Set<Notification.Name>,
                     calling send: @escaping (Notification) -> Void,
                     if isObserving: @escaping () -> Bool,
                     expiresWith object: AnyObject) {
        
        names.forEach { addObserver(for: $0, calling: send, if: isObserving, expiresWith: object) }
    }
    
    func addObserver(for name: Notification.Name,
                     calling send: @escaping (Notification) -> Void,
                     ifInWindow view: UIView) {
        
        let isObserving = { [weak view] in view?.window != nil }
        addObserver(for: name, calling: send, if: isObserving, expiresWith: view)
    }
    
    func addObserver(for names: Set<Notification.Name>,
                     calling send: @escaping (Notification) -> Void,
                     ifInWindow view: UIView) {
        
        names.forEach { addObserver(for: $0, calling: send, ifInWindow: view) }
    }
    
    func post(name: Notification.Name, object: Any?) {
        
        let notification = Notification(name: name, origin: self, object: object)
        post(notification)
        
        propagateDown(notification)
        propagateUp(notification)
    }
    
    private func post(_ notification: Notification) {
        
        // Notify observers, if any
        observersFor[notification.name]?.forEach {
            
            // Try to notify observer, but if observer has left, remove it
            do {   try $0.notify(notification)   }
            catch is NotifyingExpiredObserver {   observersFor[notification.name]!.remove($0)   }
            catch let e as NSError {   print(e.localizedDescription)   }
        }
    }
    
    private func propagateDown(_ notification: Notification) {
        
        // Propagate notification to subcontexts
        for subcontext in subcontexts {
            
            subcontext.value!.post(notification)
            subcontext.value!.propagateDown(notification)
        }
    }
    
    private func propagateUp(_ notification: Notification) {
        
        // Propagate notification to supercontexts
        supercontext?.post(notification)
        supercontext?.propagateUp(notification)
    }
    
    func setFlag(_ name: Flag.Name) {
        
        // Guard from the flag already being set in the context tree
        let flag = Flag(name: name)
        for context in contextTree {
        
            guard !context.flags.contains(flag) else {
                
                fatalError("\(name.rawValue) flag is already set in \(context.name)")
            }
        }

        // Set flag
        flags.insert(flag)
    }
    
    func unsetFlag(_ name: Flag.Name) {
        
        let flag = Flag(name: name)
        let flagWasUnset = (supercontextTree + [self]).reduce(false){   return ($1.flags.remove(flag) != nil) ? true : $0   }
        guard flagWasUnset else { fatalError("\(name) flag was not set") }
    }
    
    func flagIsSet(_ name: Flag.Name) -> Bool {
        
        return (supercontextTree + [self]).reduce(false){ return $1.flags.contains{ $0.name == name } ? true : $0 }
    }
    
    private func addExecutable(_ name: Executable.Name, 
                               executing execute: @escaping () -> Void, 
                               if isExecutable: @escaping () -> Bool,
                               expiresIf isExpired: @escaping () -> Bool) {

        // Guard from an unexpired executable with that name already existing in the context tree
        crashOrRemoveExecutable(name)

        // Add new executable
        executableNamed[name] = Executable(name: name, execute: execute, isExecutable: isExecutable, isExpired: isExpired)
    }

    func addExecutable(_ name: Executable.Name,
                       executing execute: @escaping () -> Void,
                       if isExecutable: @escaping () -> Bool, 
                       expiresWith object: AnyObject) {

        // Expire executable when the provided object is deallocated
        let isExpired = { [weak object] in object == nil }
        addExecutable(name, executing: execute, if: isExecutable, expiresIf: isExpired)
    }
    
    func addExecutable(_ name: Executable.Name, 
                       executing execute: @escaping () -> Void, 
                       ifInWindow view: UIView) {
        
        // Add a executable that executes only as long as the view is in the window
        let isExecutable = { [unowned view] in view.window != nil }
        addExecutable(name, executing: execute, if: isExecutable, expiresWith: view)
    }
    
    func crashOrRemoveExecutable(_ name: Executable.Name) {
        
        // Throw fatal error if an unexpired executable with that name already exists in the context tree
        let contextWithExecutable: Context? = contextTree.reduce(nil, { ($1.executableNamed[name] != nil) ? $1 : $0 })
        guard contextWithExecutable == nil || contextWithExecutable!.executableNamed[name]!.isExpired() else {
            
            fatalError("An unexpired executable named \(name) already exists in context: \(contextWithExecutable!.name)")
        }
        
        // Otherwise, remove the expired executable if there
        contextWithExecutable?.executableNamed[name] = nil
    }

    @discardableResult
    func execute(_ name: Executable.Name) -> Bool {

        // If executable is in-context, try to execute
        if let executable = executableNamed[name] {

            do { try executable.execute(); return true }
            catch let e where e is ExecutingExpiredExecutable || e is ExecutingUnexecutableExecutable {

                // Guard from attempting to execute an expired or unexecutable executable
                fatalError(e.localizedDescription)

            } catch let e as NSError {   print(e.localizedDescription)   }
        }
        
        // Otherwise, it should be in a supercontext, so execute it from there
        if supercontext != nil { if supercontext!.execute(name) { return true } }

        // Otherwise, throw fatal error
        fatalError("An executable named \(name.rawValue) has not been added")
    }
    
    private func selfOrSuper(thatUses name: Notification.Name) -> Context? {
        
        if Context.global.nameIsInUse(name) {
            
            return self
            
        } else {
            
            return supercontext?.selfOrSuper(thatUses: name)
        }
    }
    
    private func selfOrSub(thatUses name: Notification.Name) -> Context? {
        
        if Context.global.nameIsInUse(name) {
            
            return self
            
        } else {
            
            for subcontext in subcontexts {
                
                if let context = subcontext.value!.selfOrSub(thatUses: name) {
                    
                    return context
                }
            }
        }
        
        return nil
    }
    
    static func ==(lhs: Context, rhs: Context) -> Bool {
        
        return lhs === rhs
    }
}

class GlobalContext: Context {
    
    // Names are declared in-use to ensure uniqueness of names of the corresponding type across the application
    private var requestableNamesInUse = Set<Requestable.Name>()
    private var notificationNamesInUse = Set<Notification.Name>()
    private var flagNamesInUse = Set<Flag.Name>()
    private var executableNamesInUse = Set<Executable.Name>()

    func declare(useOf name: Notification.Name) {
        
        // Guard from the name already being in use
        guard !notificationNamesInUse.contains(name) else {
            
            fatalError("\(name.rawValue) notifications are already in use")
        }
        
        // Add to notification names in use
        notificationNamesInUse.insert(name)
    }
    
    @available(*, deprecated, message: "Because names are declared when initialized, a name can never not be in-use")
    func nameIsInUse(_ name: Notification.Name) -> Bool {
        
        return notificationNamesInUse.contains(name)
    }
    
    func declare(useOf name: Flag.Name) {
        
        // Guard from the name already being in use
        guard !flagNamesInUse.contains(name) else {
            
            fatalError("\(name.rawValue) flags are already in use")
        }
        
        // Add to flag names in use
        flagNamesInUse.insert(name)
    }

    func declare(useOf name: Executable.Name) {
        
        // Guard from the name already being in use
        guard !executableNamesInUse.contains(name) else {
            
            fatalError("\(name.rawValue) executables are already in use")
        }
        
        // Add to executable names in use
        executableNamesInUse.insert(name)
    }
    
    func declare(useOf name: Requestable.Name) {
        
        // Guard from the name already being in use
        guard !requestableNamesInUse.contains(name) else {
            
            fatalError("\(name.rawValue) requestables are already in-use")
        }
        
        // Add to requestable names in use
        requestableNamesInUse.insert(name)
    }
}
