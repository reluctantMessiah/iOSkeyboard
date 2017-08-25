//
//  TrieModel.swift
//  KeyPad
//
//  Created by Steven Olthoff on 8/17/17.
//  Copyright © 2017 thinkerer. All rights reserved.
//

import Foundation

let SUGGESTION_DEPTH_DEFAULT = 3
let SUGGESTION_DEPTH_MAX = 10
let SUGGESTION_DEPTH_MIN = 0

internal class Node {
	internal var children: [Int : Node] = [:] // Digits map to Nodes
	internal var words: [String] = []  // Weights of each word in the node
	internal var leaf: Bool = false                 // True if this node is a leaf
	
	func addWord(_ word: String) {
		words.append(word)
	}
	
	// checks if node is a leaf (end of word)
	func isLeaf() -> Bool {
		return self.leaf
	}
	
	// Does NOT check if child exists. ONLY call after hasChild()
	// gets the next node based on key
	func getBranch(key: Int) -> Node {
		return self.children[key]!
	}
	
	// True if this node has a branch at this key
	func hasChild(key: Int) -> Bool {
		return self.children[key] != nil
	}
	
	// Adds a branch from this node to key
	func putNode(key: Int, nodeToInsert : Node) {
		self.children[key] = nodeToInsert
	}
	
	// makes node a leaf
	func setAsLeaf() {
		self.leaf = true
	}
}

public class Trie {
	
	// The reverse mapping from letters to key numbers
	internal let lettersToDigits = ["a" : 2, "b" : 2, "c" : 2,
	                                "d" : 3, "e" : 3, "f" : 3,
	                                "g" : 4, "h" : 4, "i" : 4,
	                                "j" : 5, "k" : 5, "l" : 5,
	                                "m" : 6, "n" : 6, "o" : 6,
	                                "p" : 7, "q" : 7, "r" : 7, "s" : 7,
	                                "t" : 8, "u" : 8, "v" : 8,
	                                "w" : 9, "x" : 9, "y" : 9, "z" : 9]
	
	internal var root: Node
	internal var minFreq: Int                   // stores min frequency of all words (for reduction, if necessary)
	internal var maxFreq: Int                   // stores max frequency of all words (for reduction, if necessary)
	internal var wordList: [String]             // stores all words (looped through to perform reduction, if necessary)
	internal var dictionaryFilename : String
	internal let dictURL: URL
	internal let dictPath: String
	
	
	internal let suggestionDepth: Int
	internal let maxSuggestions: Int
	internal var numWords: Int
	
	// A class that constructs a list of deeper suggestions
	internal class DeeperSuggestions {
		// How deep the Trie will be searched for longer words.
		// deeperSuggestions will have at most this many inner lists
		internal let suggestionDepth : Int
		
		// References a Node in this Trie (classes are by ref)
		internal let prefixNode : Node
		
		// Each inner list is a list of suggestions of the same length.
		// Every inner list is of a word length greater than the previous list.
		internal var deeperSuggestions = [[String]]()
		
		// The deeper suggestions will stored in their final form here.
		internal var suggestions: [String] = []
		
		internal let maxSuggestions: Int
		
		internal var suggestionCount = 0
		
		internal var suggestionSet: Set<String> = []
		
		// Upon initialization, DeeperSuggestions creates a list of suggestions
		// of words from 1 char longer than the key sequence to suggestionDepth
		// in length.
		// Input: suggestionDepth - the maximum length of chars longer (than the
		//                          key sequence) to search.
		//        prefixNode - the Node from which to begin the deeper probe.
		init(_ suggestionDepth: Int, prefixNode: Node!, maxSuggestions: Int, suggestionAlreadyFound: [String]) {
			self.suggestionDepth = suggestionDepth
			self.prefixNode = prefixNode
			self.maxSuggestions = maxSuggestions

			
			for word in suggestionAlreadyFound {
				suggestionSet.insert(word)
			}
			
			deeperSuggestions.append(breadthTraverse(prefixNode))
			flattenSuggestions()
		}
		
		// Returns the finalized deeper suggestions list.
		func get() -> [String] {
			return self.suggestions
		}
		
		// Adds deeper suggestions to deeperSuggestions, sorts them, and adds them
		// all to the final suggestions list.
		internal func setDeeperSuggestions() {
			self.traverse(self.prefixNode, currentDepth: 0)
			self.flattenSuggestions()
		}
		
		// To be used only by setDeeperSuggestions(). Finds all deeperSuggestions
		// up to the depth limit.
		internal func traverse(_ currentNode: Node, currentDepth: Int) {
			if (currentDepth > 0 && currentDepth < self.suggestionDepth) {
				
				for word in currentNode.words {
					
					if self.suggestionCount < self.maxSuggestions {
						self.deeperSuggestions[currentDepth-1].append(word)
						self.suggestionCount += 1
					} else {
						return
					}
					
					
				}
			}
			
			if currentDepth == self.suggestionDepth || currentNode.children.count == 0 {
				return
			}
			
			for (key, _) in currentNode.children {
				self.traverse(currentNode.children[key]!, currentDepth: currentDepth + 1)
			}
		}

		
		internal func breadthTraverse(_ currentNode: Node) -> [String] {
			var q = [currentNode]
			var suggestions: [String] = []
			while !q.isEmpty && suggestions.count < maxSuggestions {
				let n: Node = q.first!
				for word in n.words {
					if !self.suggestionSet.contains(word) {
						suggestions.append(word)
					}
					if suggestions.count == maxSuggestions {
						return suggestions
					}
				}
				q.removeFirst()
				for child in n.children {
					q.append(child.value)
					
				}
			}
			return suggestions
		}
		
		// Flattens deeperSuggestions lists into self.suggestions
		// Make sure to call self.sort() first
		internal func flattenSuggestions() {
			for suggestions in self.deeperSuggestions {
				for word in suggestions {
					self.suggestions.append(word)
				}
			}
		}
	} // DeeperSuggestions
	
	init(dictionaryFilename : String, maxSuggestions: Int, suggestionDepth: Int = SUGGESTION_DEPTH_DEFAULT) {
		self.root = Node()
		self.minFreq = Int.max
		self.maxFreq = Int.min
		self.wordList = [String]()
		self.numWords = 0
		
		self.maxSuggestions = maxSuggestions
		
		// Process filename
		self.dictionaryFilename = dictionaryFilename
		
		
		self.dictPath = Bundle.main.path(forResource: dictionaryFilename, ofType: "txt")!
		self.dictURL = URL(fileURLWithPath: self.dictPath)
		
		if suggestionDepth < SUGGESTION_DEPTH_MIN {
			self.suggestionDepth = SUGGESTION_DEPTH_MIN
			print("The suggestion depth is too low. Setting to \(SUGGESTION_DEPTH_MIN)...")
		} else if suggestionDepth > SUGGESTION_DEPTH_MAX {
			self.suggestionDepth = SUGGESTION_DEPTH_MAX
			print("The suggestion depth passed is too high. Setting to \(SUGGESTION_DEPTH_MAX)...")
		} else {
			self.suggestionDepth = suggestionDepth
		}

		self.loadTrie()
		print("Trie loaded with \(numWords) words")
	}
	
	func loadTrie() {
		do {
			let contents = try String(contentsOf: dictURL)
			// split contents by newline and put each line into a list
			let lines = contents.components(separatedBy: "\n")
			let size = lines.count
			
			for i in 0..<size {
				
				let word = lines[i]
				
				if word.characters.count < 1 {
					break
				}

				// add into trie
				self.insert(word)

				// store words for updates (if necessary)
				self.wordList.append(word)
				self.numWords += 1
			}
		} catch {
			print("Dictionary failed to load")
			return
		}
	}
	
	// reduces the frequencies in dictionary to prevent overflow
	// does not trigger unless the max count passes a certain threshold
	// if threshold is passed, then decrease all by the min count
	//    internal func reduceWeight(word: String, weight: Int) {
	//        _ = self.updateWeight(word: word)
	//    }
	//
	internal func insert(_ word: String) {
		var node = self.root
		var key = 0
		
		for c in word.characters {
			key = lettersToDigits[String(c)]!
			
			if !node.hasChild(key: key) {
				node.putNode(key: key, nodeToInsert: Node())
			}
			
			node = node.getBranch(key: key)
		}
		
		node.setAsLeaf()
		node.addWord(word)
	}
	
	// Returns node where prefix ends.
	// If prefix not in Trie, node is nil and Bool is false.
	internal func getPrefixLeaf(_ keySequence : [Int]) -> (Node?, Bool) {
		var node: Node? = self.root
		var prefixExists = true
		
		for (i, key) in keySequence.enumerated() {
			if node!.hasChild(key: key) {
				node = node!.getBranch(key: key)
			}
			else {
				// At this point, we have reached a node that ends the path in
				// the Trie. If this key is the last in the keySequence, then
				// we know that the prefix <keySequence> exists.
				if i == keySequence.count - 1 {
					prefixExists = true
				}
				else {
					prefixExists = false
					node = nil
					return (node, prefixExists)
				}
			}
		}
		return (node!, prefixExists)
	}
	
	// If the path keySequence exists, returns the node.
	// Otherwise, nil
	internal func getPrefixNode(_ keySequence : [Int]) -> Node? {
		let (node, prefixExists) = self.getPrefixLeaf(keySequence)
		
		if prefixExists {
			return node
		}
		else {
			return nil
		}
	}
	
	func getSuggestions(keySequence : [Int]) -> [String] {
		var suggestions = [String]()
		let prefixNode: Node? = self.getPrefixNode(keySequence)
		
		if prefixNode != nil {
			
			if (prefixNode?.words.count)! > 0 {
				
				// Only suggest words that are at least as long as the key sequence
				// and has at least the entire keySequence as the prefix
				if (prefixNode!.words.first?.characters.count)! < keySequence.count {
					return []
				}
				for word in prefixNode!.words {
					suggestions.append(word)
				}
				

			}
			if suggestionDepth > 1 {
				let deeperSuggestions = DeeperSuggestions(suggestionDepth, prefixNode: prefixNode, maxSuggestions: maxSuggestions - suggestions.count, suggestionAlreadyFound: suggestions).get()
				suggestions += deeperSuggestions
			}
		}
		
		return suggestions
	}
	
	internal func wordExists(_ word : String, keySequence: [Int]) -> Bool {
		let (node, _) = self.getPrefixLeaf(keySequence)
		
		if node != nil {
			if node!.isLeaf() {
				for nodeWord in node!.words {
					if nodeWord == word {
						return true
					}
				}
				return false
			}
			else {
				return false
			}
		}
		else {
			return false
		}
	}

	
	// Assumes presence of word in dictionary file. Thus, should only be called
	// after the word has been found in the Trie.
	internal func insertWordInFile(_ word: String) {
		do {
			//let data = try Data(contentsOf: self.dictURL)
			let fileHandle = try FileHandle(forUpdating: self.dictURL)
			let data = (word as String).data(using: String.Encoding.utf8)
			
			fileHandle.seekToEndOfFile()
			fileHandle.write(data!)
			fileHandle.closeFile()
			
			self.numWords += 1
		} catch {
			print("ERROR from insertWordInFile")
			return
		}
	}
	
}
