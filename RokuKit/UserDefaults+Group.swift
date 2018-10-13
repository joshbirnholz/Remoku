//
//  UserDefaults+Group.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/11/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public extension UserDefaults {
	
	static var group: UserDefaults {
		return UserDefaults(suiteName: "group.com.josh.birnholz.Roku-Remote")!
	}
	
}
