//
//  StatisticsEngine.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Statistics & Probability Engine: Descriptive Stats, Regression, Normal Distributions & Combinatorics
//

import Foundation

public struct DescriptiveStats: Equatable, Sendable {
    public let count: Int
    public let sum: Double
    public let mean: Double
    public let median: Double
    public let mode: [Double]
    public let min: Double
    public let max: Double
    public let range: Double
    public let sampleVariance: Double
    public let sampleStdDev: Double
    public let popVariance: Double
    public let popStdDev: Double
    public let q1: Double
    public let q3: Double
    public let iqr: Double
}

public struct LinearRegressionResult: Equatable, Sendable {
    public let slope: Double
    public let intercept: Double
    public let correlationR: Double
    public let rSquared: Double
    public let equation: String
    
    public func predict(x: Double) -> Double {
        slope * x + intercept
    }
}

public final class StatisticsEngine: Sendable {
    
    public static let shared = StatisticsEngine()
    
    public init() {}
    
    // MARK: - Descriptive Statistics
    
    public func calculateStats(for values: [Double]) -> DescriptiveStats? {
        guard !values.isEmpty else { return nil }
        let n = Double(values.count)
        let sorted = values.sorted()
        
        let sum = values.reduce(0.0, +)
        let mean = sum / n
        let minVal = sorted.first!
        let maxVal = sorted.last!
        let range = maxVal - minVal
        
        // Median
        let median: Double
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            median = (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            median = sorted[mid]
        }
        
        // Mode
        var freq: [Double: Int] = [:]
        for v in values { freq[v, default: 0] += 1 }
        let maxFreq = freq.values.max() ?? 1
        let mode: [Double] = (maxFreq > 1) ? freq.filter { $0.value == maxFreq }.map { $0.key }.sorted() : []
        
        // Variance & StdDev
        let sumSqDiff = values.reduce(0.0) { $0 + pow($1 - mean, 2) }
        let popVar = sumSqDiff / n
        let popStd = sqrt(popVar)
        let sampVar = (values.count > 1) ? (sumSqDiff / (n - 1.0)) : 0.0
        let sampStd = sqrt(sampVar)
        
        // Quartiles (Tukey method)
        let lowerHalf = Array(sorted[0..<mid])
        let upperHalf = (sorted.count % 2 == 0) ? Array(sorted[mid..<sorted.count]) : Array(sorted[(mid + 1)..<sorted.count])
        
        let q1 = computeMedian(of: lowerHalf) ?? minVal
        let q3 = computeMedian(of: upperHalf) ?? maxVal
        let iqr = q3 - q1
        
        return DescriptiveStats(
            count: values.count,
            sum: sum,
            mean: mean,
            median: median,
            mode: mode,
            min: minVal,
            max: maxVal,
            range: range,
            sampleVariance: sampVar,
            sampleStdDev: sampStd,
            popVariance: popVar,
            popStdDev: popStd,
            q1: q1,
            q3: q3,
            iqr: iqr
        )
    }
    
    private func computeMedian(of arr: [Double]) -> Double? {
        guard !arr.isEmpty else { return nil }
        let mid = arr.count / 2
        if arr.count % 2 == 0 {
            return (arr[mid - 1] + arr[mid]) / 2.0
        } else {
            return arr[mid]
        }
    }
    
    // MARK: - Combinatorics: nPr, nCr
    
    public func permutation(n: Int, r: Int) -> Double? {
        guard n >= 0 && r >= 0 && r <= n else { return nil }
        var result = 1.0
        for i in 0..<r {
            result *= Double(n - i)
        }
        return result
    }
    
    public func combination(n: Int, r: Int) -> Double? {
        guard n >= 0 && r >= 0 && r <= n else { return nil }
        let k = min(r, n - r)
        var result = 1.0
        for i in 1...k {
            result = result * Double(n - i + 1) / Double(i)
        }
        return result
    }
    
    // MARK: - 2-Variable Linear Regression: y = mx + b
    
    public func linearRegression(x: [Double], y: [Double]) -> LinearRegressionResult? {
        guard x.count == y.count && x.count >= 2 else { return nil }
        let n = Double(x.count)
        
        let sumX = x.reduce(0.0, +)
        let sumY = y.reduce(0.0, +)
        let meanX = sumX / n
        let meanY = sumY / n
        
        var ssXX = 0.0
        var ssYY = 0.0
        var ssXY = 0.0
        
        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            ssXX += dx * dx
            ssYY += dy * dy
            ssXY += dx * dy
        }
        
        guard abs(ssXX) > 1e-12 else { return nil }
        
        let slope = ssXY / ssXX
        let intercept = meanY - slope * meanX
        let r = (ssYY > 1e-12) ? (ssXY / sqrt(ssXX * ssYY)) : 0.0
        let r2 = r * r
        
        let sign = intercept >= 0 ? "+" : "-"
        let eq = String(format: "y = %.4gx %@ %.4g", slope, sign, abs(intercept))
        
        return LinearRegressionResult(
            slope: slope,
            intercept: intercept,
            correlationR: r,
            rSquared: r2,
            equation: eq
        )
    }
    
    // MARK: - Gaussian Normal Distribution PDF & CDF
    
    public func normalPDF(x: Double, mean: Double = 0.0, stdDev: Double = 1.0) -> Double {
        guard stdDev > 0 else { return 0.0 }
        let z = (x - mean) / stdDev
        return (1.0 / (stdDev * sqrt(2.0 * .pi))) * Foundation.exp(-0.5 * z * z)
    }
    
    public func normalCDF(x: Double, mean: Double = 0.0, stdDev: Double = 1.0) -> Double {
        guard stdDev > 0 else { return 0.0 }
        let z = (x - mean) / (stdDev * sqrt(2.0))
        return 0.5 * (1.0 + erf(z))
    }
}
