//
//  PrayerCalendarView.swift
//  PrayerReminder
//
//  Created by Mac on 27.07.2025.
//

import SwiftUI

struct PrayerCalendarView: View {
    @EnvironmentObject var viewModel: PrayerReminderViewModel
    let isDay: Bool
    
    @State private var selectedMonth: Date = Date()

    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    private var weekdaySymbols: [String] {
        calendar.shortWeekdaySymbols
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(LocalizedStringKey("Prayer History Calendar"))
                .font(.headline)
                .foregroundColor(isDay ? Color.blue.opacity(0.8) : Color.blue.opacity(0.7))
                .padding(.horizontal)

            HStack {
                Button(action: {
                    changeMonth(by: -1)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .foregroundColor(isDay ? .primary : .white.opacity(0.8))
                }
                Spacer()
                Text(dateFormatter.string(from: selectedMonth))
                    .font(.subheadline.bold())
                    // FIX: Adjusted month/year color for better clarity
                    .foregroundColor(isDay ? Color.blue.opacity(0.8) : .white.opacity(0.9)) // Matches titles
                Spacer()
                Button(action: {
                    changeMonth(by: 1)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(isDay ? .primary : .white.opacity(0.8))
                }
            }
            .padding(.horizontal)

            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        // FIX: Adjusted weekday symbol color for better clarity
                        .foregroundColor(isDay ? .black.opacity(0.7) : .white.opacity(0.8)) // Darker for day, more visible for night
                }
            }
            .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 5) {
                ForEach(daysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(date: date, isDay: isDay, isCompleted: viewModel.checkIfAllPrayersCompleted(for: date))
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            Group {
                if isDay {
                    Color.white.opacity(0.8)
                } else {
                    LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.black.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        )
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 3)
        .padding(.horizontal)
    }

    private func daysInMonth() -> [Date?] {
        var days: [Date?] = []
        guard let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth)) else {
            return days
        }
        
        let weekdayOfFirstDay = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfEmptyLeadingDays = (weekdayOfFirstDay - calendar.firstWeekday + 7) % 7

        for _ in 0..<numberOfEmptyLeadingDays {
            days.append(nil)
        }

        guard let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else { return days }
        for i in 0..<range.count {
            if let date = calendar.date(byAdding: .day, value: i, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        return days
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
}

struct DayCell: View {
    let date: Date
    let isDay: Bool
    let isCompleted: Bool
    
    private let calendar = Calendar.current
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        VStack {
            Text(dayFormatter.string(from: date))
                .font(.callout)
                .foregroundColor(isDay ? .black.opacity(0.8) : .white)
                .frame(width: 30, height: 30)
                .background(isCompleted ? Color.green.opacity(0.3) : Color.clear)
                .cornerRadius(5)
            
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else if isToday() {
                Circle()
                    .fill(isDay ? Color.blue.opacity(0.2) : Color.blue.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(isToday() && !isCompleted ? (isDay ? Color.blue.opacity(0.1) : Color.blue.opacity(0.15)) : Color.clear)
        .cornerRadius(8)
    }
    
    private func isToday() -> Bool {
        calendar.isDateInToday(date)
    }
}


#Preview {
    ZStack {
        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.purple.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        PrayerCalendarView(isDay: false)
            .environmentObject(PrayerReminderViewModel())
    }
}
