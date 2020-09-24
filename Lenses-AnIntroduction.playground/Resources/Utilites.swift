
import Foundation

public struct Lens <A, B> {
    let get: (A) -> B
    let set: (B, A) -> A
    
    public init(
        get: @escaping(A) -> B,
        set: @escaping (B, A) -> A) {
        self.get = get
        self.set = set
    }
    
    public func over(_ f: @escaping (B) -> B) -> ((A) -> A) {
        return { a in
            let b = self.get(a)
            let transformedB = f(b)
            
            return self.set(transformedB, a)
        }
    }
}
