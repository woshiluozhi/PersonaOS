import XCTest
@testable import PersonaOS

final class AISuggestionSanitizerTests: XCTestCase {
    func testCleanTrimsAndCollapsesWhitespace() {
        let sanitizer = AISuggestionSanitizer()

        XCTAssertEqual(sanitizer.clean("  补齐\n验收\t测试  "), "补齐 验收 测试")
    }

    func testCleanedUniqueItemsSkipsBlankAndDeduplicatesNormalizedText() {
        let sanitizer = AISuggestionSanitizer()

        let results = sanitizer.cleanedUniqueItems([
            " \n\t ",
            "补齐\n验收\t测试",
            " 补齐 验收 测试 ",
            "Cafe",
            "cafe",
            "写 今日 复盘"
        ])

        XCTAssertEqual(results, ["补齐 验收 测试", "Cafe", "写 今日 复盘"])
    }

    func testNormalizedKeyCollapsesCaseDiacriticsAndWhitespace() {
        let sanitizer = AISuggestionSanitizer()

        XCTAssertEqual(
            sanitizer.normalizedKey(" Cafe\n计划 "),
            sanitizer.normalizedKey("cafe 计划")
        )
    }

    func testRiskTitleNormalizesKnownFlagsAndFallsBackToCleanText() {
        let sanitizer = AISuggestionSanitizer()

        XCTAssertEqual(sanitizer.riskTitle(for: " SCOPE_CREEP "), "范围膨胀：新项目会分散主线火力。")
        XCTAssertEqual(sanitizer.riskTitle(for: "unfinished_main_quest"), "主线未闭环：先交付可验证结果。")
        XCTAssertEqual(sanitizer.riskTitle(for: "overdue_tasks"), "逾期任务：先清理一个真实阻塞。")
        XCTAssertEqual(sanitizer.riskTitle(for: " custom\nrisk "), "custom risk")
        XCTAssertEqual(sanitizer.riskTitle(for: " \n\t "), "未知风险")
    }
}
