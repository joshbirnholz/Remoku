//
//  PropertyListType.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/14/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public protocol NoArgumentInitializable {
	init()
}

extension String: NoArgumentInitializable { }
extension Bool: NoArgumentInitializable { }
extension Array: NoArgumentInitializable { }
extension Dictionary: NoArgumentInitializable { }
extension Int: NoArgumentInitializable { }
extension Double: NoArgumentInitializable { }
extension Date: NoArgumentInitializable { }
extension Data: NoArgumentInitializable { }
extension NSString: NoArgumentInitializable { }
extension NSData: NoArgumentInitializable { }
extension NSDate: NoArgumentInitializable { }
extension NSArray: NoArgumentInitializable { }
extension NSDictionary: NoArgumentInitializable { }
extension CGFloat: NoArgumentInitializable { }
extension CGSize: NoArgumentInitializable { }
extension CGRect: NoArgumentInitializable { }
extension CGPoint: NoArgumentInitializable { }

public protocol PropertyListType { }
extension String: PropertyListType { }
extension Data: PropertyListType { }
extension Date: PropertyListType { }
extension Int: PropertyListType { }
extension Bool: PropertyListType { }
extension NSString: PropertyListType { }
extension NSData: PropertyListType { }
extension NSDate: PropertyListType { }
extension Array: PropertyListType where Element: PropertyListType { }
extension Dictionary: PropertyListType where Key == String, Value: PropertyListType { }

fileprivate let encoder = PropertyListEncoder()
fileprivate let decoder = PropertyListDecoder()

public extension Encodable {
	func propertyListObject() throws -> PropertyListType {
		if let plistType = self as? PropertyListType {
			return plistType
		} else {
			return try encoder.encode(self)
		}
	}
}

public extension Decodable {
	static func fromPropertyListObject(_ object: Any) throws -> Self {
		
		if let object = object as? Self {
			return object
		} else if let data = object as? Data {
			return try decoder.decode(Self.self, from: data)
		} else {
			throw NSError(domain: "The object could not be created.", code: -1, userInfo: nil)
		}
	}
}
