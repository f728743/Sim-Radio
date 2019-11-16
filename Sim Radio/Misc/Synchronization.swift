//
//  SynchronizedDictionary.swift
//  RadioDownloader
//

import Foundation

public class SynchronizedDictionary<Key, Value> where Key: Hashable {
    private var dictionary: [Key: Value] = [:]
    private let accessQueue = DispatchQueue(
        label: "SynchronizedDictionaryAccess",
        attributes: .concurrent)

    public var count: Int {
        var count = 0
        accessQueue.sync {
            count = dictionary.count
        }
        return count
    }

    public subscript(key: Key) -> Value? {
        set {
            accessQueue.async(flags: .barrier) {
                self.dictionary[key] = newValue
            }
        }
        get {
            var value: Value?
            accessQueue.sync {
                value = dictionary[key]
            }
            return value
        }
    }

    public var values: [Value] {
        var result: [Value] = []
        accessQueue.sync {
            result = Array(dictionary.values)
        }
        return result
    }
}

public class SynchronizedArray<T> {
    private var array: [T] = []
    private let accessQueue = DispatchQueue(
        label: "SynchronizedArrayAccess",
        attributes: .concurrent)

    public func append(newElement: T) {
        accessQueue.async(flags: .barrier) {
            self.array.append(newElement)
        }
    }

    public subscript(index: Int) -> T {
        set {
            accessQueue.async(flags: .barrier) {
                self.array[index] = newValue
            }
        }
        get {
            var element: T!
            accessQueue.sync {
                element = self.array[index]
            }
            return element
        }
    }

    public var elements: [T] {
        var result: [T] = []
        accessQueue.sync {
            result = array
        }
        return result
    }
}

struct AtomicBoolean {
    private var semaphore = DispatchSemaphore(value: 1)
    private var internalValue: Bool = false
    var val: Bool {
        get {
            semaphore.wait()
            let tmp = internalValue
            semaphore.signal()
            return tmp
        }
        set {
            semaphore.wait()
            internalValue = newValue
            semaphore.signal()
        }
    }
}
