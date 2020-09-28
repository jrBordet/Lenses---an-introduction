import UIKit

public struct Lens <A, B> {
    let get: (A) -> B
    let set: (B, A) -> A
    
    public func over(_ f: @escaping (B) -> B) -> ((A) -> A) {
        return { a in
            let b = self.get(a)
            let transformedB = f(b)
            
            return self.set(transformedB, a)
        }
    }
}

struct User {
    let name : String
    let address : Address
}

extension User {
    static var me = User(name: "Me", address: .one)
}

struct Address {
    let street : String
    let city : String
    let building: Building?
}

struct Building {
    let id: Int
}

extension User: Equatable {
    static func == (lhs: User, rhs: User) -> Bool {
        return (rhs.address == rhs.address && lhs.name == rhs.name)
    }
}

extension Address: Equatable {
    static func == (lhs: Address, rhs: Address) -> Bool {
        return lhs.street == rhs.street && lhs.city == rhs.city && lhs.building == lhs.building
    }
}

extension Building: Equatable { }

extension Address {
    static var one = Address(street: "Street 01", city: "NY", building: nil)
}

let lensUsernName = Lens<User, String>(
    get: { person in
        person.name
}, set: { name, person in
    User(
        name: name,
        address: person.address
    )
})

let name = lensUsernName.get(.me)
let newUser = lensUsernName.set("mini Me", .me)

let lensUserAddress = Lens<User, Address>(
    get: { $0.address},
    set: { User(name: $1.name, address: $0)}
)

let lensAddressStreet = Lens<Address, String>(
    get: { $0.street },
    set: { Address(street: $0, city: $1.city, building: $1.building) }
)

let lensAddressCity = Lens<Address, String>(
    get: { $0.city },
    set: { Address(street: $1.street, city: $0, building: $1.building) }
)
let lensAddressBuilding = Lens<Address, Building?>(
    get: { $0.building },
    set: { Address(street: $1.street, city: $1.city, building: $0) }
)

func lensUserStreet(_ lhs: Lens<User, Address>, _ rhs: Lens<Address, String>) -> Lens<User, String> {
    Lens<User, String>(
        get: { (u: User) -> String in
            let address = lhs.get(u)
            let street = rhs.get(address)
            
            return street
    }, set: { (street: String, user: User) -> User in
        let newUser = lhs.set(rhs.set(street, lhs.get(user)), user)
        
        return newUser
    })
}

let streetUpdate = lensUserStreet(lensUserAddress, lensAddressStreet).set("street update", .me)

lensUserStreet(lensUserAddress, lensAddressStreet).get(.me)

// MARK: - Composition

public func compose<A, B, C>(_ lhs: Lens<A, B>, _ rhs: Lens<B, C>) -> Lens<A, C> {
    Lens<A, C>(
        get: { a -> C in
            // let b = lhs.get(a)
            // let c = rhs.get(b)
            
            return rhs.get(lhs.get(a))
    }, set: { c, a -> A in
        //  let bLhs = lhs.get(a)
        //  let bRhs = rhs.set(c, bLhs)
        //  let a = lhs.set(bRhs, a)
        
        let a = lhs.set(rhs.set(c, lhs.get(a)), a)
        
        return a
    })
}

let lensUserCity = compose(lensUserAddress, lensAddressCity)

type(of: lensUserCity)

lensUserCity.get(.me)
lensAddressCity.set("new york city", .one)

let composedUser = lensUserCity.set("new city", .me)
let newAddressOne = lensAddressBuilding.set(Building(id: 1), .one)

let lensUserBuilding = compose(lensUserAddress, lensAddressBuilding)

lensUserBuilding.set(Building(id: 1), .me)

// MARK: - Forward composition

infix operator >>>

public func >>> <A, B, C> (
    _ lhs: Lens<A, B>,
    _ rhs: Lens<B, C>
) -> Lens<A, C> {
    compose(lhs, rhs)
}

let lensUserStreet = lensUserAddress >>> lensAddressStreet
lensUserStreet.set("new address", .me)

(lensAddressCity <> lensAddressStreet).set(("city", "street"), Address.one)

(lensAddressCity <> lensAddressStreet).get(Address.one)

public struct LensLaw<A, B> {
    static func getSet<A, B> (
        _ lens: Lens<A, B>,
        _ whole: A,
        _ part: B
    ) -> Bool where B: Equatable {
        let newWhole = lens.set(part, lens.set(part, whole))
        
        return lens.get(newWhole) == part
    }
    
    static func setGet<A, B>(
        _ lens: Lens<A, B>,
        _ whole: A,
        _ part: B
    ) -> Bool where B: Equatable {
        lens.get(lens.set(part, whole)) == part
    }
    
    static func setSet<A: Equatable, B, D: Equatable>(
        _ lhs: Lens<A, B>,
        _ rhs: Lens<B, D>,
        _ a: A,
        _ part: D
    ) -> Bool {
        let r1 = compose(lhs, rhs).get(a) == rhs.get(lhs.get(a))
        let r2 = compose(lhs, rhs).set(part, a) == lhs.set(rhs.set(part, lhs.get(a)), a)
        
        return r1 && r2
    }
}

LensLaw<User, String>.setGet(lensUsernName, User.me, "mini me")

//lensUserStreet lensUserAddress >>> lensAddressStreet ~> Lens<User, String>

// MARK: Lens - (User, Address) Law

LensLaw<User, Address>.getSet(lensUserAddress, User.me, Address(street: "some way", city: "TO", building: nil))
LensLaw<User, Address>.setGet(lensUserAddress, User.me, Address(street: "some way", city: "TO", building: nil))

LensLaw<Address, String>.getSet(lensAddressStreet, Address.one, "street")
LensLaw<Address, String>.setGet(lensAddressStreet, Address.one, "street")

LensLaw<User, String>.setSet(lensUserAddress, lensAddressStreet, User.me, "street check")

LensLaw<User, String>.setGet(lensUserStreet, User.me, "new street")
LensLaw<User, String>.getSet(lensUserStreet, User.me, "street")

// MARK: Lens wrong

let lensWrong = Lens<User, String>(
    get: { $0.name + "something wrong" },
    set: { User(name: $0 + "wrong", address: $1.address) }
)

LensLaw<User, String>.getSet(lensWrong, User.me, "test name")
LensLaw<User, String>.setGet(lensWrong, User.me, "test name")

// MARK: - Over

let lensUserCityCapitalized = lensUserCity.over { $0.capitalized }

lensUserCityCapitalized(.me)
//- name: "One"
//▿ address:
//  - street: "Street 01"
//  - city: "Ny"
//  - building: nil

// MARK: - Zip

infix operator <>

public func zip<A, B, C>(
    _ lhs: Lens<A, B>,
    _ rhs: Lens<A, C>
) -> Lens<A, (B, C)> {
    Lens<A, (B, C)>(
        get: {
            (lhs.get($0), rhs.get($0))
    }, set: { (parts, whole) -> A in
        rhs.set(parts.1, lhs.set(parts.0, whole))
    })
}

public func <><A, B, C>(
    _ lhs: Lens<A, B>,
    _ rhs: Lens<A, C>
) -> Lens<A, (B, C)> {
    zip(lhs, rhs)
}

public func zip2<A, B, C, D>(
    _ first: Lens<A, B>,
    _ second: Lens<A, C>,
    _ third: Lens<A, D>
) -> Lens<A, (B, (C, D))> {
    Lens<A, (B, (C, D))>(
        get: { whole -> (B, (C, D)) in
            zip(first, second <> third).get(whole)
    }, set: { (parts, whole) -> A in
        zip(first, second <> third).set(parts, whole)
    })
}

public func zip3<A, B, C, D, E>(
    _ first: Lens<A, B>,
    _ second: Lens<A, C>,
    _ third: Lens<A, D>,
    _ fourth: Lens<A, E>
) -> Lens<A, (B, (C, (D, E)))> {
    Lens<A, (B, (C, (D, E)))>(
        get: { whole -> (B, (C, (D, E))) in
            zip(first, zip2(second, third, fourth)).get(whole)
    }, set: { (parts, whole) -> A in
        zip(first, zip2(second, third, fourth)).set(parts, whole)
    })
}

zip(lensAddressBuilding, zip(lensAddressCity, lensAddressStreet)).set((Building(id: 3), ("c", "s")), Address.one)

zip2(lensAddressBuilding, lensAddressCity, lensAddressStreet).get(Address.one)

let update = ("Zipped Me", Address(street: "Some street", city: "Turin", building: nil))

zip(lensUsernName, lensUserAddress).set(update, User.me)

(lensUsernName <> lensUserAddress).set(update, User.me)

let zipAndOver = zip(lensUsernName, lensUserAddress).over { (name: String, address: Address) -> (String, Address) in
    (
        name.lowercased() + " 😀",
        Address(
            street: address.street.capitalized,
            city: address.city.uppercased(),
            building: nil
        )
    )
}

zipAndOver(User.me)
