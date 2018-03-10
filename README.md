# ProContext-iOS
For example, let's take a layout segment that's meant to get the weight of a student's assignments in a given class:

<p align="center">
  <img src="https://image.ibb.co/nqoJNn/Image_1.png"/>
</p>

Here the user's meant to input the weight of their assignments. They can choose to do so either by entering the "total" weight of all assignments or entering how much "each" individual assignment is weighted. However, to give the user context, if the user chooses to enter the total, the each field will be set to `total weight / number of assignments`, and vice versa if they choose to enter how much they are each (total field will be set to `each weight * number of assignments`).

Let's look at the layout hierarchy here:

<p align="center">
  <img src="https://image.ibb.co/g4PdNn/Untitled.png"/>
</p>

Now when the user inputs a digit into the total field, the each field should be set to `total weight / number of assignments`, but how is the `EachFieldContainer` going to access the value in the total field? How about it just asks?

```swift
class EachFieldContainer: UIStackView {

    private let context: Context
    
    ...

    var totalWeight: Double? { context.request(.totalWeight) }
    
    ...
}
```

So now when the total field is edited the `EachFieldContainer` can set the each field like so:

```swift
class EachFieldContainer: UIStackView {

    ...

    private func onTotalFieldChanged() {
    
        guard totalWeight != nil else { eachField.text = nil }
        
        let eachWeight = totalWeight! / numberOfAssignments
        eachField.text = String(eachWeight)
    }
}
```

Now the `TotalFieldContainer` just has to provide access to the total weight:

```swift
class TotalFieldContainer: UIStackView {
    
    private let totalField: UITextField
    
    var weight: Double? { return Double(totalField.text) }

    init(context: Context) {
        ...
        context.addRequestable(.totalWeight, requesting: { self.weight })
    }
}

extension Requestable.Name {

    static let totalWeight = Requestable.Name("total-weight")
}
```

And that's it, the `EachFieldContainer` can now easily access the total weight simply by requesting it using its name.

Well that's almost it. There's just a few add-ons that need to be made to really round out this solution. There are a couple issues with the above ProContext-related code. Can you spot them?

The addition of the `Requestable` creates a retain cycle. Passing `self.weight` to `context` within the closure results in `context` getting a strong reference to the `TotalFieldContainer`, but the `TotalFieldContainer` also has a strong reference to `context`. Let's fix that:

```swift
init(context: Context) {
    ...
    context.addRequestable(.totalWeight, requesting: { [weak self] in self?.weight })
}
```

That's better, but what if at some point the `WeightFieldsContainer` is replaced with a different layout hierachy for inputting views? And let's say this new layout structure has its own way of providing the total weight, so it will add its own `Requestable`, with the same name (`.totalWeight`). But this would result in two `Requestables` existing in the same context with the same name! This is a no, no. Lucky there's a way around this:

```swift
context.addRequestable(.totalWeight, 
                       requesting: { [unowned self] in self.weight },
                       expiresIf: { [weak self] in self == nil }
)
```

Now if a `Requestable` is added to a `Context` that already has one with the same name, it will discard the old one if it's expired. And because the `Requestable's` only called if it's not deallocated in this case, we can replace `weak` in the `requesting:` parameter with `unowned` and get rid of any pesky question marks.

Now I don't know about you, but if there is a possibility of my app crashing I prefer it to happen during development and not production, so as an added bonus, there's an `if:` parameter that can be provided when adding requestables which must be true in order for the `Requestable` to be requested, otherwise a `fatalError` will be thrown. So the final usage of `addRequestable()` looks like:

```swift
context.addRequestable(.totalWeight, 
                       requesting: { [unowned self] in self.weight },
                       if: { [unowned self] in self.window != nil }
                       expiresIf: { [weak self] in self == nil)
}
```

There are several versions of `addRequestable()` available to be used. One of which is made specifically for views adding `Requestables` that are only valid while the view is in the window. Which is what the above is, so using the more applicable `addRequestable()` function results in the above code looking like this:

```swift
context.addRequestable(.totalWeight, 
                       requesting: { [unowned self] in self.weight }, 
                       ifInWindow: self
)
```
<br /><br /><br />
## Adding Observers

Bet you thought adding `Requestables` was it. Of course not! Who wants to have to use another object (`NotificationCenter`) just to use observers, especially when we can get rid of all `@objc` tags by reimplementing the design pattern in Swift. Using observers in `Contexts` also comes with a surpise bonus, but we'll save that for later.

Let's add observers using our previous example with assignment weights. The `EachFieldContainer` has to know when the total field value changes, right? So let's post a notification every time the total field's value changes:

```swift
class TotalFieldContainer: UIStackView {
    
   ...
   
   private func onWeightChanged() {
    
        context.post(name: .totalWeightChanged, object: nil)
   }
}

extension Notification.Name {

    static let totalWeightChanged = Notification.Name("total-weight-changed")
}
```

Now let's respond to that notification in the `EachFieldContainer`:

```swift
class EachFieldContainer: UIStackView {

    ...
    
    init(context: Context) {
        ...
        context.addObserver(.totalWeightChanged,
                            calling: { [unowned self] (Notification) -> Void in self.onTotalFieldChanged() },
                            ifInWindow: self
        )
    }

    private func onTotalFieldChanged() {
    
        guard totalWeight != nil else { eachField.text = nil }
        
        let eachWeight = totalWeight! / numberOfAssignments
        eachField.text = String(eachWeight)
    }
}
```

And that's it. Like adding a `Requestable` adding an `Observer` can be done using several different functions.

Also, note that the `onTotalFieldChanged()` function doesn't take a `Notification` object as a parameter. Because of that there's no need to use the `Notification` argument in the `calling:` parameter's closure. If we did (let's imagine that `onTotalFieldChanged()` did take a `Notification` object as a parameter) we could shorten it to this:

```swift
calling: { [unowned self] in self.onTotalFieldChanged($0) }
```

<br /><br /><br />
## Setting Flags

You declare a `Flag.Name` the same way you do a `Requestable.Name` and a `Notification.Name`:

```swift
extension Flag.Name {

    static let userUsedTheTotalField = Flag.Name("user-used-the-total-field")
    static let userUsedTheEachField = Flag.Name("user-used-the-each-field")
}
```

Set them like so:

```swift
context.setFlag(.userUsedTheTotalField)
```

Much like attempting to request a `Requestable` whose `isRequestable` property returns false throws a `fatalError`, attempting to set a `Flag` that is already set will do the same. This seems like a logic error to me, and I like to keep a tight shop -- rather logic errors cause crashes during development, and fix them, then let them go unnoticed into production. Unsetting a flag that is not set will do the same, and you'll find doing things that don't seem to make sense (like unsetting a `Flag` that is not set) using this library will also throw `fatalErrors`. Unsetting a `Flag` is done similarly:

```swift
context.unsetFlag(.userUsedTheTotalField)
```

And then check if a `Flag` is set using:
```swift
context.flagIsSet(.userUsedTheTotalField)
```

<br /><br /><br />
## Adding Executables

Part of the reason for creating ProContext was to take a step towards decoupling code from the files it's written in. If you think about any application of logic, mentally, there's no file structure. There are things, and these things are grouped together based on what works with what, and these groupings define contexts. It is only when we take this system, and begin implementing it as software that we must represent those things in files, and this confines us as to what code can be used where.

`Executables` are a step away from that and towards are more homogenous code base. By adding `Executables`, functionality is linked with a `Context` and able to be executed anywhere within that context. For example, sometimes it's difficult to find the most applicable place to write a function. Perhaps it makes the most sense to write it in one object, but doing so there requires a lot of second-hand references (passing shit around), but writing it in the place that produces the least amount of second-hand references doesn't make sense either because although the function works mostly with the data in that object, the object itself would never call that function. So now you're adding a function (a behavior) to an object, when the function is not really a behavior of the object.

This is not fair to the programmer, and certainly not to the object. Let's fix that. So if a function only makes sense within a given context, but is difficult to determine the most sensible place to put it, let's just put it in the `Context` itself!

```swift
class AssignmentWeightsContext: Context {

    init() {
        super.init()

        addExecutable(.swapWeightInputViews,
                      executing: { [unowned self] in self.swapWeightInputViews() },
                      expiresWith: self
        )
    }

    func swapWeightInputViews() { ... }
}

extension Executable.Name {

    static let swapWeightInputViews = Executable.Name("swap-weight-input-views")
}
```

Now whenever we want to execute the executable we just do:

```swift
context.execute(.swapWeightInputViews)
```



-- this any code requesting  because ideally the change would be transparent to anything requesting the total weight via the `Context` object.
    
