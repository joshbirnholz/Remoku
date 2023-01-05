//
//  IntentHandler.swift
//  Remoku Intents
//
//  Created by Josh Birnholz on 10/26/19.
//  Copyright © 2019 Josh Birnholz. All rights reserved.
//

import Intents

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        // This is the default implementation.  If you want different objects to handle different intents,
        // you can override this and return the handler you want for that particular intent.
        
        return self
    }
    
}
