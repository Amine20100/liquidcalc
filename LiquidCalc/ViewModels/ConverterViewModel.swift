//
//  ConverterViewModel.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//

import Foundation
import SwiftUI

public typealias UnitConverterViewModel = ConverterViewModel

@Observable
public final class ConverterViewModel {
    private let engine = UnitConverterEngine()
    
    public var selectedCategory: UnitCategoryType = .length {
        didSet {
            sourceUnit = selectedCategory.units.first!
            targetUnit = selectedCategory.units.count > 1 ? selectedCategory.units[1] : selectedCategory.units.first!
            recalculate()
        }
    }
    
    public var sourceUnit: UnitItem
    public var targetUnit: UnitItem
    
    public var inputString: String = "1" {
        didSet {
            recalculate()
        }
    }
    
    public var outputString: String = "0"
    
    public init() {
        let initialCat = UnitCategoryType.length
        self.selectedCategory = initialCat
        self.sourceUnit = initialCat.units[0] // Meters
        self.targetUnit = initialCat.units[1] // Kilometers
        recalculate()
    }
    
    public func recalculate() {
        guard let value = Double(inputString) else {
            outputString = "0"
            return
        }
        let result = engine.convert(value: value, from: sourceUnit, to: targetUnit, category: selectedCategory)
        outputString = MathEvaluator.formatResult(result)
    }
    
    public func swapUnits() {
        let temp = sourceUnit
        sourceUnit = targetUnit
        targetUnit = temp
        recalculate()
    }
    
    public func appendDigit(_ digit: String) {
        if inputString == "0" {
            inputString = digit
        } else {
            inputString += digit
        }
    }
    
    public func appendDecimal() {
        if !inputString.contains(".") {
            inputString += "."
        }
    }
    
    public func deleteBackward() {
        if !inputString.isEmpty {
            inputString.removeLast()
            if inputString.isEmpty {
                inputString = "0"
            }
        }
    }
    
    public func clear() {
        inputString = "0"
    }
}
