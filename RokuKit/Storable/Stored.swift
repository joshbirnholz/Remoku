//
//  Storable.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/14/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public protocol ObjectStore {
	func set<T: Codable>(_ value: T?, forKey key: String)
	func value<T: Codable>(forKey key: String) -> T?
}

@propertyWrapper public struct Stored<T: Codable> {
	
	private let key: String
	private let store: ObjectStore
	
	private class DefaultValueProvider {
		private let valueProvider: () -> T
		fileprivate lazy var defaultValue = valueProvider()
		init(_ valueProvider: @escaping () -> T) {
			self.valueProvider = valueProvider
		}
	}
	
	private let defaultValueProvider: DefaultValueProvider
	
	public init(key: String, store: ObjectStore = UserDefaults.standard, defaultValue: @escaping @autoclosure () -> T) {
		self.key = key
		self.store = store
		self.defaultValueProvider = DefaultValueProvider(defaultValue)
	}
	
	public init<U>(key: String, store: ObjectStore = UserDefaults.standard) where T == U? {
		self.init(key: key, store: store, defaultValue: nil)
	}
	
	public var wrappedValue: T {
		set {
			store.set(newValue, forKey: key)
		}
		get {
			return store.value(forKey: key) ?? defaultValueProvider.defaultValue
		}
	}
}

public extension Stored where T: NoArgumentInitializable {
	init(key: String, store: ObjectStore = UserDefaults.standard) {
		self.init(key: key, store: store, defaultValue: T())
	}
}
