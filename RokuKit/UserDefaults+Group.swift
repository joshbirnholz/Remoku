//
//  UserDefaults+Group.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/11/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public extension UserDefaults {
	static let group = UserDefaults(suiteName: "group.com.josh.birnholz.Roku-Remote")!
}

public struct Global {
	@Stored(key: "foundDevices", store: UserDefaults.group) public static var foundDevices: [RokuDevice]
}
