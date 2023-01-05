//
//  call.swift
//  Roku Remote
//
//  Created by Josh Birnholz on 10/24/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import Foundation

func call<T>(_ handler: @escaping ((T) -> Void), onQueue queue: DispatchQueue? = nil, with value: (() -> T)) {
	let value = value()
	if let queue = queue {
		queue.async {
			handler(value)
		}
	} else {
		handler(value)
	}
}
