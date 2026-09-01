//
//  MatrixEngine.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Linear Algebra & Matrix Engine (Determinants, Inverses, RREF, Eigenvalues)
//

import Foundation

public struct Matrix: Equatable, Sendable {
    public let rows: Int
    public let cols: Int
    public var grid: [[Double]]
    
    public init(rows: Int, cols: Int, defaultValue: Double = 0.0) {
        self.rows = max(1, rows)
        self.cols = max(1, cols)
        self.grid = Array(repeating: Array(repeating: defaultValue, count: self.cols), count: self.rows)
    }
    
    public init(_ grid: [[Double]]) {
        self.rows = max(1, grid.count)
        self.cols = max(1, grid.first?.count ?? 1)
        self.grid = grid
    }
    
    public static func identity(size: Int) -> Matrix {
        var m = Matrix(rows: size, cols: size, defaultValue: 0.0)
        for i in 0..<size {
            m.grid[i][i] = 1.0
        }
        return m
    }
    
    public subscript(row: Int, col: Int) -> Double {
        get {
            guard row >= 0 && row < rows && col >= 0 && col < cols else { return 0.0 }
            return grid[row][col]
        }
        set {
            guard row >= 0 && row < rows && col >= 0 && col < cols else { return }
            grid[row][col] = newValue
        }
    }
}

public final class MatrixEngine: Sendable {
    
    public static let shared = MatrixEngine()
    
    public init() {}
    
    // MARK: - Matrix Addition: A + B
    
    public func add(_ a: Matrix, _ b: Matrix) -> Matrix? {
        guard a.rows == b.rows && a.cols == b.cols else { return nil }
        var result = Matrix(rows: a.rows, cols: a.cols)
        for r in 0..<a.rows {
            for c in 0..<a.cols {
                result[r, c] = a[r, c] + b[r, c]
            }
        }
        return result
    }
    
    // MARK: - Matrix Subtraction: A - B
    
    public func subtract(_ a: Matrix, _ b: Matrix) -> Matrix? {
        guard a.rows == b.rows && a.cols == b.cols else { return nil }
        var result = Matrix(rows: a.rows, cols: a.cols)
        for r in 0..<a.rows {
            for c in 0..<a.cols {
                result[r, c] = a[r, c] - b[r, c]
            }
        }
        return result
    }
    
    // MARK: - Scalar Multiplication: s * A
    
    public func scale(_ a: Matrix, by scalar: Double) -> Matrix {
        var result = Matrix(rows: a.rows, cols: a.cols)
        for r in 0..<a.rows {
            for c in 0..<a.cols {
                result[r, c] = a[r, c] * scalar
            }
        }
        return result
    }
    
    // MARK: - Matrix Multiplication: A * B
    
    public func multiply(_ a: Matrix, _ b: Matrix) -> Matrix? {
        guard a.cols == b.rows else { return nil }
        var result = Matrix(rows: a.rows, cols: b.cols, defaultValue: 0.0)
        for r in 0..<a.rows {
            for c in 0..<b.cols {
                var dot = 0.0
                for k in 0..<a.cols {
                    dot += a[r, k] * b[k, c]
                }
                result[r, c] = dot
            }
        }
        return result
    }
    
    // MARK: - Transpose: Aᵀ
    
    public func transpose(_ a: Matrix) -> Matrix {
        var result = Matrix(rows: a.cols, cols: a.rows)
        for r in 0..<a.rows {
            for c in 0..<a.cols {
                result[c, r] = a[r, c]
            }
        }
        return result
    }
    
    // MARK: - Trace: tr(A) (sum of main diagonal elements)
    
    public func trace(_ a: Matrix) -> Double? {
        guard a.rows == a.cols else { return nil }
        var sum = 0.0
        for i in 0..<a.rows {
            sum += a[i, i]
        }
        return sum
    }
    
    // MARK: - Determinant: det(A) via LU Decomposition
    
    public func determinant(_ a: Matrix) -> Double? {
        guard a.rows == a.cols else { return nil }
        let n = a.rows
        
        if n == 1 { return a[0, 0] }
        if n == 2 { return a[0, 0] * a[1, 1] - a[0, 1] * a[1, 0] }
        if n == 3 {
            return a[0, 0] * (a[1, 1] * a[2, 2] - a[1, 2] * a[2, 1])
                 - a[0, 1] * (a[1, 0] * a[2, 2] - a[1, 2] * a[2, 0])
                 + a[0, 2] * (a[1, 0] * a[2, 1] - a[1, 1] * a[2, 0])
        }
        
        // General NxN via Gaussian elimination with partial pivoting
        var m = a.grid
        var det = 1.0
        
        for i in 0..<n {
            var pivot = i
            for j in (i + 1)..<n {
                if abs(m[j][i]) > abs(m[pivot][i]) {
                    pivot = j
                }
            }
            
            if abs(m[pivot][i]) < 1e-12 { return 0.0 }
            
            if pivot != i {
                m.swapAt(i, pivot)
                det = -det
            }
            
            det *= m[i][i]
            
            for j in (i + 1)..<n {
                let factor = m[j][i] / m[i][i]
                for k in (i + 1)..<n {
                    m[j][k] -= factor * m[i][k]
                }
            }
        }
        
        return det
    }
    
    // MARK: - Matrix Inverse: A⁻¹ via Gauss-Jordan Elimination
    
    public func inverse(_ a: Matrix) -> Matrix? {
        guard a.rows == a.cols else { return nil }
        let n = a.rows
        
        var augmented = Array(repeating: Array(repeating: 0.0, count: 2 * n), count: n)
        for i in 0..<n {
            for j in 0..<n {
                augmented[i][j] = a[i, j]
                augmented[i][j + n] = (i == j) ? 1.0 : 0.0
            }
        }
        
        for i in 0..<n {
            var pivot = i
            for j in (i + 1)..<n {
                if abs(augmented[j][i]) > abs(augmented[pivot][i]) {
                    pivot = j
                }
            }
            
            guard abs(augmented[pivot][i]) > 1e-12 else { return nil } // Singular matrix
            
            if pivot != i {
                augmented.swapAt(i, pivot)
            }
            
            let pivotVal = augmented[i][i]
            for j in 0..<(2 * n) {
                augmented[i][j] /= pivotVal
            }
            
            for j in 0..<n {
                if j != i {
                    let factor = augmented[j][i]
                    for k in 0..<(2 * n) {
                        augmented[j][k] -= factor * augmented[i][k]
                    }
                }
            }
        }
        
        var inv = Matrix(rows: n, cols: n)
        for i in 0..<n {
            for j in 0..<n {
                inv[i, j] = augmented[i][j + n]
            }
        }
        return inv
    }
    
    // MARK: - Reduced Row Echelon Form (RREF)
    
    public func rref(_ a: Matrix) -> Matrix {
        var m = a.grid
        var lead = 0
        let rowCount = a.rows
        let colCount = a.cols
        
        for r in 0..<rowCount {
            if colCount <= lead { break }
            var i = r
            while abs(m[i][lead]) < 1e-12 {
                i += 1
                if rowCount == i {
                    i = r
                    lead += 1
                    if colCount == lead { break }
                }
            }
            if colCount <= lead { break }
            
            m.swapAt(i, r)
            let val = m[r][lead]
            if abs(val) > 1e-12 {
                for j in 0..<colCount {
                    m[r][j] /= val
                }
            }
            
            for j in 0..<rowCount {
                if j != r {
                    let factor = m[j][lead]
                    for k in 0..<colCount {
                        m[j][k] -= factor * m[r][k]
                    }
                }
            }
            lead += 1
        }
        
        return Matrix(m)
    }
}
