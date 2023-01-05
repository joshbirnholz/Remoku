//
//  UserDefaults+ObjectStore.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/14/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

extension UserDefaults: ObjectStore {
	
	public func set<T: Codable>(_ value: T?, forKey key: String) {
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
	
	public func value<T: Decodable>(forKey key: String) -> T? {
		guard let value = value(forKey: key) else { return nil }
		
		do {
			return try T.fromPropertyListObject(value)
		} catch {
			print("Warning: User defaults could not retreive object for key \"\(key)\". The error was: \(error.localizedDescription)")
		}
		
		return nil
	}
}
