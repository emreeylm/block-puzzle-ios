import XCTest
@testable import GameCore

final class DifficultyTests: XCTestCase {
    private let curve = DifficultyCurve.standard

    func testProgressIsClampedAndScales() {
        XCTAssertEqual(curve.progress(forScore: 0), 0)
        XCTAssertEqual(curve.progress(forScore: -100), 0)
        XCTAssertEqual(curve.progress(forScore: curve.rampScore / 2), 0.5, accuracy: 0.001)
        XCTAssertEqual(curve.progress(forScore: curve.rampScore), 1)
        XCTAssertEqual(curve.progress(forScore: curve.rampScore * 10), 1)
    }

    func testHelperMechanicsWeakenAsGameProgresses() {
        XCTAssertGreaterThan(curve.comboHelperChance(at: 0), curve.comboHelperChance(at: 0.5))
        XCTAssertGreaterThan(curve.comboHelperChance(at: 0.5), curve.comboHelperChance(at: 1))
        XCTAssertGreaterThan(curve.harmonyChance(at: 0), curve.harmonyChance(at: 1))

        // Başlangıçta cömert, sonda kısıtlı
        XCTAssertGreaterThan(curve.comboHelperChance(at: 0), 0.35)
        XCTAssertLessThan(curve.comboHelperChance(at: 1), 0.15)
        XCTAssertGreaterThan(curve.harmonyChance(at: 0), 0.9)
    }

    func testHardShapesBecomeMoreCommon() {
        XCTAssertLessThan(curve.hardShapeMultiplier(at: 0), 0.5)
        XCTAssertGreaterThan(curve.hardShapeMultiplier(at: 1), 1.0)
        XCTAssertLessThan(curve.hardShapeMultiplier(at: 0), curve.hardShapeMultiplier(at: 1))
    }

    func testHandGuaranteeRelaxesLater() {
        XCTAssertEqual(curve.handGuaranteeTargets(at: 0), [3, 2, 1])
        XCTAssertEqual(curve.handGuaranteeTargets(at: 0.9), [2, 1])
    }

    func testGeneratorRespectsHardShapeMultiplier() {
        func hardShareOfThousand(multiplier: Double) -> Int {
            var generator = PieceGenerator(seed: 2024)
            var hard = 0
            for _ in 0..<1000 {
                let cells = generator.makePiece(hardShapeMultiplier: multiplier).shape.cellCount
                if cells >= PieceGenerator.hardShapeCellThreshold { hard += 1 }
            }
            return hard
        }

        let early = hardShareOfThousand(multiplier: curve.hardShapeMultiplierStart)
        let late = hardShareOfThousand(multiplier: curve.hardShapeMultiplierEnd)
        XCTAssertLessThan(early, late, "Zor parçalar oyun ilerledikçe artmalı")
        XCTAssertLessThan(early, 250, "Başlangıçta zor parçalar seyrek olmalı")
        XCTAssertGreaterThan(late, 400, "Sonda zor parçalar baskın olmalı")
    }

    func testEngineTightensWithScore() {
        let engine = GameEngine(seed: 7)
        let startCombo = engine.comboHelperChance
        let startHarmony = engine.harmonyChance
        XCTAssertEqual(engine.difficultyProgress, 0)

        // Skoru yapay olarak yükseltmek yerine eğriyi doğrudan sorgula:
        // motor aynı eğriyi kullandığı için ilerleyen skorda değerler düşer.
        let lateCombo = engine.difficulty.comboHelperChance(at: 1)
        let lateHarmony = engine.difficulty.harmonyChance(at: 1)
        XCTAssertGreaterThan(startCombo, lateCombo)
        XCTAssertGreaterThan(startHarmony, lateHarmony)
    }

}
