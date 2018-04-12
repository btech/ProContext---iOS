# ProContext-iOS
  If you go up to someone right after they've made an accomplishment and say "Great job", they'll automatically know what you're referring to because of the context of the situation. They just accomplished something, and you're complementing them on the thing they just did.
  
  Context's the reason why you don't have to say "Great job on your most recent accomplishment" because context takes care of everything else after "Great job". Context is also the reason that telling someone "Great job" the moment they walk out of a bathroom stall may lead to an awkward situation. That is, of course, dependent on the amount of effort they exerted in there. If considerable, based on the context, they may know exactly what you're talking about, and perhaps throw you a solemn head nod.
  
  But as huge a part context plays in our lives it is practically absent from the code we write, and thus its benefits are as well, resulting in redundancies throughout our code that really should be abstracted away based on the context in which the code is being written.

For example, let's take a layout segment that's meant to get the weight of a student's assignments in a given class:

<p align="center">
  <img src="https://image.ibb.co/nqoJNn/Image_1.png"/>
</p>

Here the user's meant to input the weight of their assignments. They can choose to do so either by entering the "total" weight of all assignments or entering how much "each" individual assignment is weighted. However, to give the user context, if the user chooses to enter the total, the each field will be set to `total weight / number of assignments`, and vice versa if they choose to enter how much they are each (total field will be set to `each weight * number of assignments`).

Let's look at the layout hierarchy here:

<p align="center">
  <img src="https://image.ibb.co/g4PdNn/Untitled.png"/>
</p>

Now when the user inputs a digit into the total field, the each field should be set to `total weight / number of assignments`, but how is the `EachFieldContainer` going to access the value in the `TotalFieldContainer`? How about it just asks?

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

That's better, but what if at some point the `WeightFieldsContainer` is replaced with a different layout hierachy for inputting weights? And let's say this new layout structure has its own way of providing the total weight, so it will add its own `Requestable`, with the same name (`.totalWeight`). But this would result in two `Requestables` existing in the same context with the same name! This is a no, no. Lucky there's a way around this:

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
                       if: { [unowned self] in self.window != nil },
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
        ...
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

    static let totalFieldSetByUser = Flag.Name("total-field-set-by-user")
    static let eachFieldSetByUser = Flag.Name("each-field-set-by-user")
}
```

Set them like so:

```swift
context.setFlag(.totalFieldSetByUser)
```

Much like attempting to request a `Requestable` whose `isRequestable` property returns false throws a `fatalError`, attempting to set a `Flag` that is already set will do the same. This seems like a logic error to me, and I like to keep a tight shop -- rather logic errors cause crashes during development, and fix them, then let them go unnoticed into production. Unsetting a flag that is not set will do the same, and you'll find doing things that don't seem to make sense (like unsetting a `Flag` that is not set) using this library will also throw `fatalErrors`. Unsetting a `Flag` is done similarly:

```swift
context.unsetFlag(.totalFieldSetByUser)
```

And then check if a `Flag` is set using:
```swift
context.flagIsSet(.totalFieldSetByUser)
```

<br /><br /><br />
## Adding Executables

Part of the reason for creating ProContext was to take a step towards decoupling code from the files it's written in. If you think about any application of logic, mentally, there's no file structure. There are things, and these things are grouped together based on what works with what, and these groupings define contexts. It is only when we take this system, and begin implementing it as software that we must represent those things in files, and this confines us as to what code can be used where.

`Executables` are a step away from that and towards are more homogenous code base. By adding `Executables`, functionality is linked with a `Context` and able to be executed anywhere within that context.

For example, sometimes it's difficult to find the most applicable place to write a function. Perhaps it makes the most sense to write it in one object, but doing so there requires a lot of second-hand references (passing shit around), but writing it in the place that produces the least amount of second-hand references doesn't make sense either because although the function works mostly with the data in that object, the object itself would never call that function. So now you're adding a function (a behavior) to an object, when the function is not really a behavior of the object.

This is not fair to the programmer, and certainly not to the object. Let's fix that. So if a function only makes sense within a given context, but is difficult to determine the most sensible place to put it, let's just put it in the `Context` itself!

```swift
class AssignmentsContext: Context {

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
assignmentsContext.execute(.swapWeightInputViews)
```

<br /><br /><br />
## Surprise

Now for that surprise. You may have been thinking 'Where do subcontexts and supercontexts come into play in all of this?' **This** is the most powerful feature of ProContext.

Let's return to our previous example of setting the weights of assignments, and let's blow up the picture to get a bigger idea of what's going on:

<p align="center">
  <img src="https://image.ibb.co/mu18a7/bigger_Idea.png" width="70%"/>
</p>

As you can see we added exams to the picture, because unfortunately, most classes come with exams. Let's get an idea of how this layout looks contextually:

<p align="center">
  <img src="https://image.ibb.co/jOHC3S/contexts.png"/>
</p>

As you can see the 'Assignments' and 'Exams' contexts are part of a larger context named 'Context-oriented Programming 101'. Let's call the supercontext the `ClassContext`. So how do you represent that hierarchy using ProContext? Like so:

```swift
let classContext = Context.global.createSubcontext(ofType: ClassContext.self)
let assignmentsContext = classContext.createSubcontext(ofType: AssignmentsContext.self)
let examsContext = classContext.createSubcontext(ofType: ExamsContext.self)
```

And that's it. With that code we have created a `Context` hierarchy that exactly matches the above diagram. 

Note that all `Contexts` must be created from another `Context` using `Context.createSubcontext()`. In this case we didn't have one to create the `ClassContext` from so we had to use the global context (`Context.global`). Also, we passed the types of our `Context` subclasses, so our subcontexts would be created with the correct types. But if you're not using `Context` subclasses the subcontexts can be created as plain `Context` objects:

```swift
let classContext = Context.global.createSubcontext(named: "Class")
let assignmentsContext = classContext.createSubcontext(named: "Assignments")
let examsContext = classContext.createSubcontext(named: "Exams")
```

You do have to provide a name if not providing a `Context` subclass type.

So what benefits does subcontexting provide? It all starts with contextuals and their scope -- contextuals are just the things we've already talked about: `Requestables`, `Observers`, `Flags`, and `Executables`.

Let's start with `Requestables`. A lot of professors grade their students using a point system instead of a percent based system (they may say that exams count towards 500pts of your total grade instead of 70% of the total). We're going to need to know which one it is so we can append the correct suffix ('%' or 'pts') to the weights they enter. Let's see how getting that may look:

<p align="center">
  <img src="https://image.ibb.co/c7cWV7/with_Grade_Basis_Widget.png" width="70%"/>
</p>

Now, let's say you add a `Requestable` for the grade basis:

```swift
class GradeBasisSelectionView: UIView {
    
    private let classContext: ClassContext
    
    ...
    
    private var percentsIsSelected: Bool { ... }
    
    init(context: ClassContext) {
        ...
        
        classContext.addRequestable(.percentsIsSelected,
                                    requesting: { [unowned self] in self.percentsIsSelected },
                                    ifInWindow: self
        ) 
    }
}

extension Requestable.Name {

    static let percentsIsSelected = Requestable.Name("percents-is-selected")
}
```

Now the grade basis can be accessed from anywhere that has this `Context` object. But what about the subcontexts? They need it too so they can append the right suffix when a weight is entered! So how do they get it? Just like any other `Requestable`:

```swift
let percentsIsSelected: Bool = assignmentsContext.request(.percentsIsSelected)
let percentsIsSelected: Bool = examsContext.request(.percentsIsSelected)
```

You may be wondering 'Wait, but how is that when it wasn't added to either of those `Contexts`, it was added to their super context?' This goes back to contextuals and their scope. So what's the scope of `Requestables`?

**The scope of a `Requestable` is at and below the context it was added to.**

Why is that?

Any single `Context` can have many subcontexts. So if you go back to our example and try to request the total weight of all assignments from the class context:

```swift
classContext.request(.totalWeight)
```

You'll get a `fatalError`. How is it supposed to know whether you want the assignments' total weight *or the exams'*? They both added a requestable named `.totalWeight`, so because of this inherent one-to-many relationship contexts have with their subcontexts, it is ambiguous to try and request something that exists within a subcontext because there may be many subcontexts with the same `Requestable`. But at the same token, because of the one-to-one relationship contexts have with their *supercontexts* there'll never be a conflict because you wouldn't have two identical supercontexts -- *because there can only be one*.

Let's look at the scope of other contextuals:

**The scope of a `Flag` is at and below the context it was added to.**

So just like `Requestables`, and for the same reason too.

`Executables`?

**The scope of an `Executable` is at and below the context it was added to.**

The same.

Now, there's a reason I saved `Observers` for last. Because *they are the only one that is different*. Let's analyze why using a case study. Let's say the student's grades are based on percents, and they put in 20% for assignments, but they accidentally put in 90% instead of 80% for exams. Now the total weight for all their assessments is 110%, which makes no sense (no extra credit for you!). So for our purposes that's an error state, but it's not a problem from the context of the exams because of encapsulation -- exams don't know the weight totals of other assessment categories. For all it knows there's quizzes as well. And it's also not a problem from the context of the assignments for the same reasons. This is a class level problem ('class' as in school class, not object class), so it should be dealt with there. But how will the `ClassContext` know when the weights change so it can check them and make sure they're not above 100%? Let's start by posting a `Notification` every time the weight changes:

```swift
class WeightFieldContainer: UIStackView {

    private let context: Context
    
    var weight: Double? { ... }

    func onWeightChanged() {
        
        context.post(name: .assessmentCategoryWeightChanged, object: weight)
    }
}

extension Notification.Name {

    static let assessmentCategoryWeightChanged = Notification.Name("assessment-category-weight-changed")
}
```

We'll also listen for that `Notification` in the `ClassContext`:

```swift
class ClassContext: Context {

    private let classContext: ClassContext
    
    init() {
        ...
        addObserver(.assessmentCategoryWeightChanged,
                    calling: { [unowned self] in self.validateAssessmentCategoryWeightSum($0),
                    expiresWith: self
        )
    }
    
    private func validateAssessmentCategoryWeightSum(_ notification: Notification) { ... }
}
```

Now we just have to make sure that:

**The scope of an `Observer` is at, below, *and* above the context it was added to.**

And I already did that in the framework so we're good.

Because of this, a context will receive notifications that are posted from its subcontexts. You'll find in the framework there's a special word for a scope that stretches to all supercontexts as well as subcontexts. This is called the context-tree. Let's visualize that:

<p align="center">
  <img src="https://image.ibb.co/gwFSnn/context_tree.png" width="90%"/>
</p>

Everything in red is the context-tree from the perspective of the yellow context.

And another!

<p align="center">
  <img src="https://image.ibb.co/h6R8Sn/context_tree.png" width="90%"/>
</p>

You can check how `Notifications` are propagated up the context-tree as well as down by following the execution of code that follows from calling  `Context.post(name:object:)`.

Let's finish this primer off with delineating the scope of all the contextuals:

**The scope of a `Requestable` is at and below the context it was added to.**

**The scope of a `Flag` is at and below the context it was added to.**

**The scope of an `Executable` is at and below the context it was added to.**

**The scope of an `Observer` is at, below, and above the context it was added to.**

With that you've had your first consextual awakening. Here's to many more.

<p align="center">
  <img src="https://imgflip.com/s/meme/Leonardo-Dicaprio-Cheers.jpg"/>
</p>
    
