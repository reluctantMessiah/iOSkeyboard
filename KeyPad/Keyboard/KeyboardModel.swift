//
//  KeyboardModel.swift
//  KeyPad
//
//  Created by Steven Olthoff on 8/16/17.
//  Copyright © 2017 thinkerer. All rights reserved.
//

import Foundation

let trie = Trie(dictionaryFilename: "dictionary", maxSuggestions: 5)

var digitSequence: [Int] = []

// Calling with no params reloads predictions for the current digit sequence
/**
	Returns a list of words that the user is potentially trying to type, given 
	the current digit sequence.

	- parameters
		- idOfCurrentButton: The digit corresponding the button just pressed. If
		  this parameter is not set, predictions will be returned for the
		  current digit sequence.
*/
func getPredictions(_ idOfCurrentButton: Int = -1) -> [String] {
	
	if idOfCurrentButton != -1 {
		digitSequence.append(idOfCurrentButton)
	}
	
	var predictions: [String] = []
	
	predictions = trie.getSuggestions(keySequence: digitSequence)
	
	if predictions.count == 0 {
		_ = digitSequence.popLast()
	}
	
//	print("Sequence: \(digitSequence)")
//	print("Predictions: \(predictions)")
	
	return predictions
}
