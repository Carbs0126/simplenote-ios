import Foundation

extension Date {
    func increased(byDays days: Int) -> Date? {
        var components = DateComponents()
        components.day = days
        let calendar = Calendar.current
        return calendar.date(byAdding: components, to: self)
    }
}
