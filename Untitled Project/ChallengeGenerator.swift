import Foundation

struct MathChallenge: Equatable, Sendable {
    let prompt: String
    let answer: Int
}

enum ChallengeGenerator {
    static func math(for difficulty: ChallengeDifficulty) -> MathChallenge {
        switch difficulty {
        case .easy:
            let first = Int.random(in: 20...69)
            let second = Int.random(in: 11...49)
            let multiplier = Int.random(in: 3...9)
            let usesAddition = Bool.random()
            let inner = usesAddition ? first + second : max(first, second) - min(first, second)
            let symbol = usesAddition ? "+" : "−"
            let left = usesAddition ? first : max(first, second)
            let right = usesAddition ? second : min(first, second)
            return MathChallenge(
                prompt: "(\(left) \(symbol) \(right)) × \(multiplier) = ?",
                answer: inner * multiplier
            )

        case .medium:
            let a = Int.random(in: 12...24)
            let b = Int.random(in: 4...12)
            let c = Int.random(in: 11...23)
            let d = Int.random(in: 3...11)
            let subtracts = Bool.random()
            let firstProduct = a * b
            let secondProduct = c * d
            let answer = subtracts ? firstProduct - secondProduct : firstProduct + secondProduct
            return MathChallenge(
                prompt: "\(a) × \(b) \(subtracts ? "−" : "+") \(c) × \(d) = ?",
                answer: answer
            )

        case .hard:
            let a = Int.random(in: 14...29)
            let b = Int.random(in: 5...12)
            let c = Int.random(in: 13...27)
            let d = Int.random(in: 4...11)
            let offset = Int.random(in: 31...89)
            return MathChallenge(
                prompt: "(\(a) × \(b)) + (\(c) × \(d)) − \(offset) = ?",
                answer: a * b + c * d - offset
            )
        }
    }

    static func memorySequence(for difficulty: ChallengeDifficulty) -> String {
        var digits: [Int] = []
        while digits.count < difficulty.memoryLength {
            let next = Int.random(in: digits.isEmpty ? 1...9 : 0...9)
            if digits.suffix(2).allSatisfy({ $0 == next }) {
                continue
            }
            digits.append(next)
        }
        return digits.map(String.init).joined()
    }
}
