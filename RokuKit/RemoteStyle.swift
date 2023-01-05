//
//  RemoteStyle.swift
//  RokuKit
//
//  Created by Josh Birnholz on 10/15/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public let preferencesURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("enabledDevices.plist")

public enum RemoteStyle: String {
	
	case swipe
	case button
	
	@Stored(key: "savedRemoteStyle", defaultValue: false) private static var saved
	
	public static var savedRemoteStyle: RemoteStyle {
		get {
			return saved ? .button : .swipe
		}
		set {
			saved = newValue == .button
		}
	}
	
}
