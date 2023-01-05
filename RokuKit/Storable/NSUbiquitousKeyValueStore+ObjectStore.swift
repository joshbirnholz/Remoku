//
//  NSUbiquitousKeyValueStore+ObjectStore.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/24/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import Foundation

extension NSUbiquitousKeyValueStore: ObjectStore {
	public func set<T>(_ value: T?, forKey key: String) where T : Decodable, T : Encodable {
		guard let value = value else {
			removeObject(forKey: key)
			return
		}
		
		do {
			let value = try value.propertyListObject()
			set(value, forKey: key)
		} catch {
			print("Warning: User defaults could not store object for key \"\(key)\". The error was: \(error.localizedDescription)")
		}
		
	}
	
	public func value<T>(forKey key: String) -> T? where T : Decodable, T : Encodable {
		guard let value = value(forKey: key) else { return nil }
		
		do {
			return try T.fromPropertyListObject(value)
		} catch {
			print("Warning: User defaults could not retreive object for key \"\(key)\". The error was: \(error.localizedDescription)")
		}
		
		return nil
	}
}
