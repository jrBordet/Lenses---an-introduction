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
    static var one = User(name: "Me", address: .one)
}

struct Address {
    let street : String
    let city : String
    let building: Building?
}

struct Building {
    let id: Int
}

extension Address {
    static var one = Address(street: "Street 01", city: "NY", building: nil)
}

//Lens<User, String>(get: <#T##(User) -> String#>, set: <#T##(String, User) -> User#>)

let lensPersonName = Lens<User, String>(
    get: { person in
        person.name
}, set: { name, person in
    User(
        name: name,
        address: person.address
    )
})

let name = lensPersonName.get(.one)
let newUser = lensPersonName.set("mini Me", .one)

dump(name)
dump(newUser)

let lensUserAddress = Lens<User, Address>(
    get: { $0.address},
    set: { User(name: $1.name, address: $0)}
)

let lensAddressStret = Lens<Address, String>(
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

dump(lensUserAddress.get(.one))

// MARK: - Deep traverse

// lhs: Lens<User, Address>
// rhs: Lens<Address, String>

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

lensUserStreet(lensUserAddress, lensAddressStret).set("street update", .one)

// User.one.address.street = "street update"
// User.one.address.street

// MARK: - Composition (Map)

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

lensUserCity.get(.one)
lensAddressCity.set("new york city", .one)

let composedUser = lensUserCity.set("new city", .one)
let newAddressOne = lensAddressBuilding.set(Building(id: 1), .one)

// lhs: Lens<Address, String>
// rhs: Lens<Address, Building?>
// Lens<Address, Building?>

let lensUserBuilding = compose(lensUserAddress, lensAddressBuilding)

let a = lensUserBuilding.set(Building(id: 1), .one)
a.address.building?.id

// MARK: - Over

let lensUserCityCapitalized = lensUserCity.over { $0.capitalized }

lensUserCityCapitalized(.one)

//- name: "One"
//▿ address:
//  - street: "Street 01"
//  - city: "Ny"
//  - building: nil


dump(lensUserCityCapitalized(.one))

// MARK: - Forward composition

infix operator >>>

public func >>> <A, B, C> (
    _ lhs: Lens<A, B>,
    _ rhs: Lens<B, C>
) -> Lens<A, C> {
    compose(lhs, rhs)
}

let _lensUserAddress = lensUserAddress >>> lensAddressStret
_lensUserAddress.set("new address", .one)
