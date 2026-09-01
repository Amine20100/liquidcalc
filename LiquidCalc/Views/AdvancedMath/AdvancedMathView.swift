//
//  AdvancedMathView.swift
//  LiquidCalc
//
//  Created for LiquidCalc iOS 18+.
//  Comprehensive Advanced Mathematics Workstation
//

import SwiftUI

public enum AdvancedMathSubCategory: String, CaseIterable, Identifiable {
    case algebra = "Algebra"
    case calculus = "Calculus"
    case matrices = "Matrices"
    case complex = "Complex"
    case statistics = "Stats"
    case numberTheory = "Theory"
    case grapher = "Grapher"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .algebra: return "x.squareroot"
        case .calculus: return "function"
        case .matrices: return "square.grid.3x3.fill"
        case .complex: return "number.circle"
        case .statistics: return "chart.bar.xaxis"
        case .numberTheory: return "number"
        case .grapher: return "waveform.path.ecg"
        }
    }
}

public struct AdvancedMathView: View {
    @State private var selectedCategory: AdvancedMathSubCategory = .algebra
    
    // Algebra States
    @State private var quadA: String = "1"
    @State private var quadB: String = "-5"
    @State private var quadC: String = "6"
    @State private var quadSolution: QuadraticSolution? = nil
    
    // Calculus States
    @State private var calcFormula: String = "x^2 + 3*x"
    @State private var calcPoint: String = "2"
    @State private var calcLower: String = "0"
    @State private var calcUpper: String = "3"
    @State private var calcDerivativeResult: String = ""
    @State private var calcIntegralResult: String = ""
    
    // Complex States
    @State private var compReal1: String = "3"
    @State private var compImag1: String = "4"
    @State private var compReal2: String = "1"
    @State private var compImag2: String = "-2"
    @State private var compResult: String = ""
    
    // Stats States
    @State private var statsInput: String = "12, 15, 18, 22, 25, 25, 29, 32, 35, 40"
    @State private var statsResult: DescriptiveStats? = nil
    
    // Number Theory States
    @State private var numTheoryInput: String = "360"
    @State private var primeFactorsResult: String = ""
    @State private var isPrimeResult: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 12) {
            // Horizontal Segmented Category Selector Bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(AdvancedMathSubCategory.allCases) { cat in
                        Button(action: {
                            SoundAndHapticManager.shared.triggerHaptic(.selection)
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: cat.iconName)
                                    .font(.system(size: 11))
                                Text(cat.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.vertical, 7)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == cat ? Color.cyan.opacity(0.35) : Color.white.opacity(0.08))
                            )
                            .foregroundColor(selectedCategory == cat ? .cyan : .white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 2)
            
            // Sub-Workstation Content
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedCategory {
                    case .algebra:
                        algebraWorkstation
                    case .calculus:
                        calculusWorkstation
                    case .matrices:
                        matrixWorkstation
                    case .complex:
                        complexWorkstation
                    case .statistics:
                        statisticsWorkstation
                    case .numberTheory:
                        numberTheoryWorkstation
                    case .grapher:
                        FunctionGrapherView()
                            .frame(height: 380)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            solveQuadratic()
            computeCalculus()
            computeStats()
            computeNumberTheory()
        }
    }
    
    // MARK: - Algebra Sub-Workstation
    
    private var algebraWorkstation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quadratic Equation: ax² + bx + c = 0")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            HStack(spacing: 8) {
                mathInputField(title: "a", text: $quadA)
                mathInputField(title: "b", text: $quadB)
                mathInputField(title: "c", text: $quadC)
                
                Button(action: solveQuadratic) {
                    Text("Solve")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Capsule().fill(Color.cyan))
                }
            }
            
            if let sol = quadSolution {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Root 1 (x₁)")
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                            Text(sol.root1String)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("Root 2 (x₂)")
                                .font(.caption).foregroundColor(.white.opacity(0.6))
                            Text(sol.root2String)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.06)))
                    
                    Text("Step-by-Step Derivation:")
                        .font(.caption).bold().foregroundColor(.white.opacity(0.8))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(sol.steps, id: \.self) { step in
                            Text("• " + step)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.35)))
                }
            }
        }
    }
    
    // MARK: - Calculus Sub-Workstation
    
    private var calculusWorkstation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calculus Operations: f(x)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            TextField("f(x) = x^2 + 3*x", text: $calcFormula)
                .font(.system(size: 14, design: .monospaced))
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
            
            HStack(spacing: 8) {
                mathInputField(title: "x₀", text: $calcPoint)
                mathInputField(title: "∫ a", text: $calcLower)
                mathInputField(title: "∫ b", text: $calcUpper)
                
                Button(action: computeCalculus) {
                    Text("Compute")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Capsule().fill(Color.cyan))
                }
            }
            
            VStack(spacing: 8) {
                resultRow(title: "Derivative f'(x₀)", value: calcDerivativeResult)
                resultRow(title: "Definite Integral ∫[a,b] f(x)dx", value: calcIntegralResult)
            }
        }
    }
    
    // MARK: - Matrices Sub-Workstation
    
    private var matrixWorkstation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("2x2 & 3x3 Matrix Determinants & Inverses")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            Text("Matrix A = [[4, 7], [2, 6]]")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))
            
            let matA = Matrix([[4, 7], [2, 6]])
            let detA = MatrixEngine.shared.determinant(matA) ?? 0.0
            let invA = MatrixEngine.shared.inverse(matA)
            
            VStack(spacing: 8) {
                resultRow(title: "det(A)", value: String(format: "%.4g", detA))
                resultRow(title: "tr(A)", value: String(format: "%.4g", MatrixEngine.shared.trace(matA) ?? 0))
                if let inv = invA {
                    resultRow(title: "A⁻¹ [0,0]", value: String(format: "%.4g", inv[0, 0]))
                    resultRow(title: "A⁻¹ [0,1]", value: String(format: "%.4g", inv[0, 1]))
                    resultRow(title: "A⁻¹ [1,0]", value: String(format: "%.4g", inv[1, 0]))
                    resultRow(title: "A⁻¹ [1,1]", value: String(format: "%.4g", inv[1, 1]))
                }
            }
        }
    }
    
    // MARK: - Complex Sub-Workstation
    
    private var complexWorkstation: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Complex Numbers: z₁ and z₂")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            HStack(spacing: 8) {
                mathInputField(title: "Re(z₁)", text: $compReal1)
                mathInputField(title: "Im(z₁)", text: $compImag1)
                mathInputField(title: "Re(z₂)", text: $compReal2)
                mathInputField(title: "Im(z₂)", text: $compImag2)
            }
            
            let z1 = ComplexNumber(real: Double(compReal1) ?? 0, imag: Double(compImag1) ?? 0)
            let z2 = ComplexNumber(real: Double(compReal2) ?? 0, imag: Double(compImag2) ?? 0)
            
            VStack(spacing: 8) {
                resultRow(title: "z₁ Polar Form", value: z1.polarDescription)
                resultRow(title: "z₁ + z₂", value: (z1 + z2).description)
                resultRow(title: "z₁ * z₂", value: (z1 * z2).description)
                resultRow(title: "z₁ / z₂", value: (z1 / z2).description)
                resultRow(title: "√z₁", value: z1.sqrt().description)
            }
        }
    }
    
    // MARK: - Statistics Sub-Workstation
    
    private var statisticsWorkstation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Descriptive Statistics")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            TextField("Numbers separated by comma", text: $statsInput)
                .font(.system(size: 13, design: .monospaced))
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                .onChange(of: statsInput) { computeStats() }
            
            if let st = statsResult {
                VStack(spacing: 6) {
                    resultRow(title: "Sample Size (n)", value: "\(st.count)")
                    resultRow(title: "Mean (μ)", value: String(format: "%.4g", st.mean))
                    resultRow(title: "Median", value: String(format: "%.4g", st.median))
                    resultRow(title: "Sample StdDev (s)", value: String(format: "%.4g", st.sampleStdDev))
                    resultRow(title: "Range (Max - Min)", value: String(format: "%.4g", st.range))
                    resultRow(title: "IQR (Q3 - Q1)", value: String(format: "%.4g", st.iqr))
                }
            }
        }
    }
    
    // MARK: - Number Theory Sub-Workstation
    
    private var numberTheoryWorkstation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prime Factorization & Primality")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.cyan)
            
            HStack(spacing: 8) {
                TextField("Enter integer", text: $numTheoryInput)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.08)))
                
                Button(action: computeNumberTheory) {
                    Text("Factorize")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Capsule().fill(Color.cyan))
                }
            }
            
            VStack(spacing: 8) {
                resultRow(title: "Is Prime?", value: isPrimeResult)
                resultRow(title: "Prime Factors", value: primeFactorsResult)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func mathInputField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.6))
            TextField(title, text: text)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.08)))
        }
    }
    
    private func resultRow(title: String, value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 12)).foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }
    
    private func solveQuadratic() {
        let a = Double(quadA) ?? 1.0
        let b = Double(quadB) ?? 0.0
        let c = Double(quadC) ?? 0.0
        quadSolution = AlgebraicSolver.shared.solveQuadratic(a: a, b: b, c: c)
    }
    
    private func computeCalculus() {
        let eval = MathEvaluator()
        let x0 = Double(calcPoint) ?? 2.0
        let a = Double(calcLower) ?? 0.0
        let b = Double(calcUpper) ?? 3.0
        
        let f: @Sendable (Double) -> Double = { val in
            let expr = calcFormula
                .replacingOccurrences(of: "x", with: "(\(val))")
                .replacingOccurrences(of: "X", with: "(\(val))")
            return (try? eval.evaluate(expression: expr)) ?? 0.0
        }
        
        let d = CalculusEngine.shared.derivative(at: x0, function: f)
        let integ = CalculusEngine.shared.integrate(from: a, to: b, function: f)
        
        calcDerivativeResult = String(format: "%.5g", d)
        calcIntegralResult = String(format: "%.5g", integ)
    }
    
    private func computeStats() {
        let nums = statsInput
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        statsResult = StatisticsEngine.shared.calculateStats(for: nums)
    }
    
    private func computeNumberTheory() {
        if let n = Int64(numTheoryInput) {
            let isP = NumberTheoryEngine.shared.isPrime(n)
            isPrimeResult = isP ? "YES (Prime)" : "NO (Composite)"
            let factors = NumberTheoryEngine.shared.primeFactorization(of: n)
            primeFactorsResult = factors.map { $0.description }.joined(separator: " × ")
        }
    }
}
