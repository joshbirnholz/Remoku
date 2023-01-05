//
//  NotificationNames.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/15/18.
//  Copyright © 2018 Josh Birnholz. All rights reserved.
//

import Foundation

public extension Notification.Name {
	public static var WCSessionActivationDidComplete = Notification.Name("WCSessionActivationDidComplete")
	public static var WCSessionDidReceiveFile = Notification.Name("WCSessionDidReceiveFile")
	public static var WCSessionDidReceiveMessage = Notification.Name("WCSessionDidReceiveMessage")
	public static var WCSessionDidReceiveApplicationContext = Notification.Name("WCSessionDidReceiveApplicationContext")
	public static var WCSessionDidBecomeInactive = Notification.Name("WCSessionDidBecomeInactive")
	public static var WCSessionDidDeactivate = Notification.Name("WCSessionDidDeactivate")
}
