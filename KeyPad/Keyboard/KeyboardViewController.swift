//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Steven Olthoff on 8/7/17.
//  Copyright © 2017 thinkerer. All rights reserved.
//

import UIKit

class KeyboardViewController: UIInputViewController {

	
	@IBOutlet var buttons: [UIButton]!
	@IBOutlet var textButtons: [UIButton]!
	@IBOutlet var predictionButtons: [UIButton]!
	
	// The spacebar and the return button also choose predictions/manually typed
	// words.
	enum ChoiceButton {
		case spaceButton, returnButton
	}
	
	let alphabetSet = CharacterSet.letters
	let buttonTitleToId: [String : Int] =
		[".,!?" : 1, "abc" : 2, "def"  : 3,
		 "ghi"  : 4, "jkl" : 5, "mno"  : 6,
		 "pqrs" : 7, "tuv" : 8, "wxyz" : 9]
	let letterToId: [String : Int] =
		["a" : 2, "b" : 2, "c" : 2,
		 "d" : 3, "e" : 3, "f" : 3,
		 "g" : 4, "h" : 4, "i" : 4,
		 "j" : 5, "k" : 5, "l" : 5,
		 "m" : 6, "n" : 6, "o" : 6,
		 "p" : 7, "q" : 7, "r" : 7, "s" : 7,
		 "t" : 8, "u" : 8, "v" : 8,
		 "w" : 9, "x" : 9, "y" : 9, "z" : 9]
	let buttonIdToLetters: [Int : [String]] =
		[1 : [".", ",", "!", "?", "'"],
		 2 : ["a", "b", "c"],
		 3 : ["d", "e", "f"],
		 4 : ["g", "h", "i"],
		 5 : ["j", "k", "l"],
		 6 : ["m", "n", "o"],
		 7 : ["p", "q", "r", "s"],
		 8 : ["t", "u", "v"],
		 9 : ["w", "x", "y", "z"]]
	var wordPredictions: [String] = []
	var mostRecentChar: String = ""
	var shiftOn = false
	let manualModePrompt = "Aa"
	var manualModeOn: Bool = false
	var charSequence: [String] = []
	var shiftSequence: [Bool] = []
	
	// Color settings
	let borderWidth = CGFloat(1.0)
	let borderColor = UIColor.darkGray.cgColor
	let backgroundColor = UIColor.lightGray
	let highlightColor = UIColor.white
	let titleColor = UIColor.black
	
	// Vars for manual mode
	// The id of the last button to be pressed while in manual mode
	var prevManualButtonId = -1
	// The time that the last button was pressed while in manual mode
	var prevManualButtonTime = Date.timeIntervalSinceReferenceDate
	// While in manual mode, time to wait for another key press is .25 seconds
	let manualModeMaxWaitTime = TimeInterval(0.75)
	var manualModeTimerStarted = false
	var manualModeLetterIndex = 0
	
    override func updateViewConstraints() {
        super.updateViewConstraints()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

		view.backgroundColor = UIColor.darkGray
		
		for button in buttons {
			button.layer.borderWidth = borderWidth
			button.layer.borderColor = borderColor
			button.backgroundColor = backgroundColor
			button.setTitleColor(titleColor, for: UIControlState.normal)
		}
		
		for button in predictionButtons {
			button.setTitle("", for: .normal)
		}
    }
	
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func textWillChange(_ textInput: UITextInput?) {
	}
	
	// Clears the prediction buttons when the text field is cleared.
    override func textDidChange(_ textInput: UITextInput?) {
		if !textDocumentProxy.hasText {
			clearPredictions()
			if manualModeOn {
				manualModeOn = false
				manualModeTimerStarted = false
				manualModeLetterIndex = 0
			}
			shiftOn = false
			shiftSequence = []
			digitSequence = []
		}

    }

//	@IBAction func nextKeyboardButtonPressed(_ sender: UIButton) {
//		print("nextKeyboardButton pressed")
//		advanceToNextInputMode()
//	}
	
	/**
		Inserts the first prediction, if it exists, followed by a space.
		If in manual mode, the manually typed word is inserted and remembered.
	
		- parameters:
			- sender: The spacebar button.
	*/
	@IBAction func spaceButtonPressed(_ sender: UIButton) {
		chooseWord(ChoiceButton.spaceButton)
	}

	
	/**
		Inserts the first prediction, if it exists, followed by a newline.
		If in manual mode, the manually typed word is inserted and remembered.
	
		- parameters:
			- sender: The return button.
	*/
	@IBAction func returnButtonPressed(_ sender: UIButton) {
		chooseWord(ChoiceButton.returnButton)
	}
	
	@IBOutlet var shiftButton: UIButton!
	func toggleShift() {
		shiftOn = (shiftOn ? false :  true)
		if shiftOn {
			shiftButton.backgroundColor = highlightColor
			for (i, button) in textButtons.enumerated() {
				button.setTitle(concatenateAll(buttonIdToLetters[i+2]!).uppercased(), for: .normal)
			}
		} else {
			shiftButton.backgroundColor = backgroundColor
			for (i, button) in textButtons.enumerated() {
				button.setTitle(concatenateAll(buttonIdToLetters[i+2]!).lowercased(), for: .normal)
			}
		}
	}
	
	/**
		FIXME
	
	*/
	@IBAction func shiftButtonPressed(_ sender: UIButton) {
		toggleShift()
	}
	
	@IBAction func manualModeButtonPressed(_ sender: UIButton) {
		
		if manualModeOn {
			sender.backgroundColor = backgroundColor
			manualModeOn = false
			manualModeTimerStarted = false
//			clearPredictions()
			// If the last char is a letter, reload this word.
			if isAlpha(getLastChar()) {
				reloadDigitSequence()
				updatePredictionButtons()
			}
			
			prevManualButtonId = -1
			print("Manual mode OFF")
		} else {
			clearPredictions()
			
			sender.backgroundColor = highlightColor
			manualModeOn = true
			print("Manual mode ON")
			digitSequence = []
			
//			let lastChar = getLastChar()
			
			// Get the chars of the most recent word
//			if isAlpha(lastChar) {
//				prevManualButtonId = letterToId[String(lastChar)]!
//				
//				charSequence = getMostRecentWord()
//				updateCharSequenceOnButton()
//				print("Current word: \(concatenateAll(charSequence))")
//			}
		}
	}
	
	
	/**
		Inserts the selected prediction into the text field, and clears all
		prediction buttons.
	
		- parameters:
			- sender: A prediction button.
	*/
	@IBAction func predictionButtonPressed(_ sender: UIButton) {
		if sender.currentTitle != "" {
			for _ in 0..<digitSequence.count {
				textDocumentProxy.deleteBackward()
			}
			textDocumentProxy.insertText(sender.currentTitle!)
			textDocumentProxy.insertText(" ")
			mostRecentChar = " "
			clearPredictions()
			digitSequence = []
			shiftSequence = []
		}
		if shiftOn {
			toggleShift()
		}
	}
	
	@IBAction func punctuationButtonPressed(_ sender: UIButton) {
		for (i, char) in buttonIdToLetters[1]!.enumerated() {
			predictionButtons[i].setTitle(char, for: .normal)
		}
		digitSequence = []
		shiftSequence = []
		
		if shiftOn {
			toggleShift()
		}
	}
	
	/**
		Appends to the digit sequence and updates the prediction buttons for
		this new sequence.
	
		- parameters:
			- sender: The alphabet buttons.
	*/
	@IBAction func textButtonPressed(_ sender: UIButton) {
		
		let buttonTitle = sender.currentTitle
		let buttonId = buttonTitleToId[(buttonTitle?.lowercased())!]
		print("Button Title\t\(buttonTitle!)")
		print("Button Id\t\(buttonId!)")
		
		if manualModeOn {
			
			func advanceManualMode() {
				
				func setNextManualModeIndex() {
					manualModeLetterIndex = (manualModeLetterIndex + 1) % (buttonIdToLetters[buttonId!]?.count)!
				}
				
				var letterToInsert: String = ""
				
				func advanceToNextLetter() {
					letterToInsert = (buttonIdToLetters[buttonId!]?[manualModeLetterIndex])!
					if shiftOn {
						letterToInsert = letterToInsert.uppercased()
					}
					textDocumentProxy.insertText(letterToInsert)
					setNextManualModeIndex()
				}
				
				func prepareForNextManualPress() {
					prevManualButtonTime = Date.timeIntervalSinceReferenceDate
					prevManualButtonId = buttonId!
				}
				
				advanceToNextLetter()
				prepareForNextManualPress()
			}
			
			// The timer has not yet been started. Start it now.
			if !manualModeTimerStarted {
				manualModeTimerStarted = true
				manualModeLetterIndex = 0
			} else {
				let currentTime = Date.timeIntervalSinceReferenceDate
				let elapsedTime: TimeInterval = currentTime - prevManualButtonTime
				print("Wait time\t\(elapsedTime)")
				// The same button was tapped right away
				if elapsedTime < manualModeMaxWaitTime && buttonId == prevManualButtonId {
					textDocumentProxy.deleteBackward()
				} else {
					manualModeLetterIndex = 0
				}
			}
			advanceManualMode()
		} else {
			if shiftOn {
				shiftSequence.append(true)
			} else {
				shiftSequence.append(false)
			}
			
			updatePredictionButtons(mostRecentDigit: buttonId!)
			
			if wordPredictions.count > 0 {
				// Delete the current word and replace it with the newest best prediction
				// up to the same length
				var shouldDeleteCurrentWord = false
				if mostRecentChar != "" && alphabetSet.contains(UnicodeScalar(mostRecentChar)!) && wordPredictions.count > 0 {
					shouldDeleteCurrentWord = true
				}
				
				if shouldDeleteCurrentWord {
					if (wordPredictions.first?.characters.count)! >= digitSequence.count {
						for _ in 0..<digitSequence.count - 1 {
							textDocumentProxy.deleteBackward()
						}
					}
				}
				updateWordInProgress()
			} else {
				_ = shiftSequence.popLast()
			}
			print("Shifts\t\(shiftSequence)")
		}
		
		if shiftOn {
			toggleShift()
		}
	}
	
	/**
		Deletes the most recent character and updates the prediction buttons and
		text field such that they are operating on whatever digit sequence is
		the one of concern.
	
		- parameters
			- sender: The backspace button.
	
	*/
	@IBAction func backspaceButtonPressed(_ sender: UIButton) {
		
		if manualModeOn {
			if textDocumentProxy.hasText {
				textDocumentProxy.deleteBackward()
				_  = shiftSequence.popLast()
			}
			
		} else {
			if digitSequence.count == 0 {
				
				if textDocumentProxy.hasText {
					textDocumentProxy.deleteBackward()
					
					// If, after deleting one character, there are no more chars,
					// we are finished.
					
					if !textDocumentProxy.hasText {
						return
					}
					// Find index of most recent letter
					let currentText = Array(textDocumentProxy.documentContextBeforeInput!.characters)
					
					if !isAlpha(currentText[currentText.count-1]) {
						return
					}
					
					var indexOfMostRecentLetter = currentText.count - 1
					while !isAlpha(currentText[indexOfMostRecentLetter]) &&
						  indexOfMostRecentLetter >= 0 {
							
						indexOfMostRecentLetter -= 1
					}
					
					// If there is a letter, reload the digit sequence of this word
					if indexOfMostRecentLetter > 0 ||
					   (indexOfMostRecentLetter == 0 &&
						isAlpha(currentText[indexOfMostRecentLetter])) {
						
						mostRecentChar = String(currentText[indexOfMostRecentLetter])
						
						let prevWordEndIndex = indexOfMostRecentLetter
						var prevWordStartIndex = prevWordEndIndex
						
						while prevWordStartIndex >= 0 &&
							  isAlpha(currentText[prevWordStartIndex]) {
								let currentChar = String(currentText[prevWordStartIndex])
								digitSequence.append(letterToId[currentChar.lowercased()]!)
								prevWordStartIndex -= 1
						}
						digitSequence.reverse()

						
						updatePredictionButtons()
						
					}
				}
			} else if digitSequence.count == 1 {
				_ = digitSequence.popLast()
				mostRecentChar = ""
				_ = shiftSequence.popLast()
				clearPredictions()
				textDocumentProxy.deleteBackward()
			} else if digitSequence.count > 1 {
				_ = digitSequence.popLast()
				_ = shiftSequence.popLast()
				updatePredictionButtons()
				
				// delete the current word
				var i = 0
				while i < digitSequence.count + 1 {
					textDocumentProxy.deleteBackward()
					i += 1
				}
				
				updateWordInProgress()
			}
		}
		if shiftOn {
			toggleShift()
		}
		print("Shifts\t\(shiftSequence)")
	}
	
	/**
		Chooses the current word when a word-choice button, such as spacebar or
		return, is pressed,
	
		- parameters:
			- buttonType: An enum indicating which button was pressed to choose
			  the current word.
	*/
	func chooseWord(_ buttonType: ChoiceButton) {
		let strToFollow: String
		switch buttonType {
		case .returnButton:
			strToFollow = "\n"
			break
		case .spaceButton:
			strToFollow = " "
			break
		}
		
		if manualModeOn {
			if isAlpha(getLastChar()) {
				
				let newWord = concatenateAll(getMostRecentWord()).lowercased()
				trie.insert(newWord)
				trie.insertWordInFile(newWord)
				clearPredictions()
				
				print("Manually chosen word\t\(newWord)")
			}
		} else {
			chooseFirstPrediction()
			mostRecentChar = strToFollow
		}
		shiftSequence.removeAll()
		if shiftOn {
			toggleShift()
		}
		textDocumentProxy.insertText(strToFollow)
	}
	
	/**
		Alters the letters of the current word in the text field to match the
	first prediction button to the same number of characters.
	*/
	internal func updateWordInProgress() {
		for i in 0..<digitSequence.count {
			let charToInsert = String(Array(wordPredictions.first!.characters)[i])
			textDocumentProxy.insertText(charToInsert)
			mostRecentChar = charToInsert
		}
	}
	
	/**
		Returns true if the Character is a letter (in the alphabet).
	
		- parameters:
			- char: The Character being checked.
	*/
	internal func isAlpha(_ char: Character) -> Bool {
		return alphabetSet.contains(UnicodeScalar(String(char))!)
	}
	
	/**
		Updates the prediction buttons with the new predictions. If there are no
		predictions for the digit sequence, the user is offered to turn on
		manual entry mode.
	
		- parameters:
			- mostRecentDigit: The id of the button pressed. If this parameter
			  is not provided, the prediction buttons are updated to show
			  predictions for the current digit sequence.
	*/
	func updatePredictionButtons(mostRecentDigit: Int = -1) {
		
		func shiftify() {
			for (i, word) in wordPredictions.enumerated() {
				var wordWithShifts = ""
				for (j, char) in word.characters.enumerated() {
					if j >= shiftSequence.count {
						
						let restOfWordStartIndex =
							word.index(word.startIndex, offsetBy: j)

						wordWithShifts += word.substring(from: restOfWordStartIndex)
						
						break
					}
					if shiftSequence[j] {
						wordWithShifts.append(String(char).uppercased())
					} else {
						wordWithShifts.append(String(char))
					}
				}
				
				if wordWithShifts != "" {
					swap(&wordPredictions[i], &wordWithShifts)
				}
				
			}
		}
		
		clearPredictions()

		if mostRecentDigit != -1 {
			wordPredictions = getPredictions(mostRecentDigit)
		} else {
			wordPredictions = getPredictions()
			
			let mostRecentWord = concatenateAll(getMostRecentWord())
			for char in mostRecentWord.characters {
				if CharacterSet.uppercaseLetters.contains(UnicodeScalar(String(char))!) {
					shiftSequence.append(true)
				} else {
					shiftSequence.append(false)
				}
			}
		}
		
		if wordPredictions.count > 0 {
			
			
			
			if shiftSequence.contains(true) {
				shiftify()
			}
			var i = 0
			while i < wordPredictions.count {
				predictionButtons[i].setTitle(wordPredictions[i], for: .normal)
				i += 1
			}

			
		}
		
		print("Sequence\t\(digitSequence)")
		
		print("Predictions\t\(wordPredictions)")
	}
	
	/**
		Inserts the word on the first prediction button, if it exists.
	*/
	internal func chooseFirstPrediction() {
		
		if wordPredictions.count > 0 {
			for _ in 0..<digitSequence.count {
				textDocumentProxy.deleteBackward()
			}
			let proxy = textDocumentProxy
			digitSequence = []
			
			proxy.insertText(wordPredictions.first!)
			
			print("Word chosen: \(wordPredictions.first!)")
			
			
		}
		shiftSequence.removeAll()
		clearPredictions()
	}
	
	/**
		Empties the stored list of predictions and clears the titles of the
		prediction buttons.
	*/
	internal func clearPredictions() {
		wordPredictions = []
		for button in predictionButtons {
			button.setTitle("", for: .normal)
		}
	}
	
	internal func lastCharInTextIsAlpha() -> Bool {
		if !textDocumentProxy.hasText {
			return false
		}
		let currentText = Array(textDocumentProxy.documentContextBeforeInput!.characters)
		return isAlpha(currentText.last!)
	}
	
	internal func getMostRecentWord() -> [String] {
		let currentText = Array(textDocumentProxy.documentContextBeforeInput!.characters)
		
		var indexOfMostRecentLetter = currentText.count - 1
		while !isAlpha(currentText[indexOfMostRecentLetter]) &&
			indexOfMostRecentLetter >= 0 {
				
				indexOfMostRecentLetter -= 1
		}
		
		// If there is a letter, reload the word
		if indexOfMostRecentLetter > 0 ||
			(indexOfMostRecentLetter == 0 &&
				isAlpha(currentText[indexOfMostRecentLetter])) {
			
			mostRecentChar = String(currentText[indexOfMostRecentLetter])
			
			let prevWordEndIndex = indexOfMostRecentLetter
			var prevWordStartIndex = prevWordEndIndex
			
			var mostRecentWord: [String] = []
			
			while prevWordStartIndex >= 0 &&
				isAlpha(currentText[prevWordStartIndex]) {
					let currentChar = String(currentText[prevWordStartIndex])
					mostRecentWord.append(currentChar)
					prevWordStartIndex -= 1
			}
			mostRecentWord.reverse()
			return mostRecentWord
		} else {
			return []
		}
	}
	
	internal func concatenateAll(_ list: [String]) -> String {
		var word: String = ""
		for member in list {
			for char in member.characters {
				word.append(char)
			}
		}
		return word
	}
	
	internal func updateCharSequenceOnButton() {
		let currentWord = concatenateAll(charSequence)
		predictionButtons[0].setTitle(currentWord, for: .normal)
	}
	
	/**
		digitSequence is loaded with the corresponding digits of the most far
		right word.
	*/
	func reloadDigitSequence() {
		let mostRecentWord = getMostRecentWord()
		digitSequence = []
		for letter in mostRecentWord {
			digitSequence.append(letterToId[letter.lowercased()]!)
		}
	}
	
	func getLastChar() -> Character {
		if textDocumentProxy.hasText {
			let currentText = Array(textDocumentProxy.documentContextBeforeInput!.characters)
			let lastChar = currentText[currentText.count - 1]
			return lastChar
		} else {
			return Character("\0")
		}
	}
}
