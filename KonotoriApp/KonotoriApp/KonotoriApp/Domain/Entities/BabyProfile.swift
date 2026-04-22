import Foundation

// MARK: - BabyProfile Entity

struct BabyProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var dueDate: Date?
    var birthDate: Date?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        dueDate: Date? = nil,
        birthDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dueDate = dueDate
        self.birthDate = birthDate
        self.createdAt = createdAt
    }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case dueDate = "due_date"
        case birthDate = "birth_date"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// The reference date used for milestone scheduling.
    /// Uses birthDate if available, otherwise falls back to dueDate.
    var referenceDate: Date? {
        birthDate ?? dueDate
    }

    /// Returns true if the baby has already been born.
    var isBorn: Bool {
        birthDate != nil
    }

    /// Gestational age in weeks from dueDate (negative = before birth).
    var gestationalWeeks: Int? {
        guard let ref = referenceDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: ref, to: Date()).day ?? 0
        return days / 7
    }
}
