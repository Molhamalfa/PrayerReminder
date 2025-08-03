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

    private var datesInMonth: [Date?] {
        let range = calendar.range(of: .day, in: .month, for: selectedMonth)!
        let firstDayOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedMonth))!
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        var dates: [Date?] = Array(repeating: nil, count: firstWeekday - calendar.firstWeekday)
        
        for day in 1...range.count {
            if let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: selectedMonth), month: calendar.component(.month, from: selectedMonth), day: day)) {
                dates.append(date)
            }
        }
        return dates
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
                    .foregroundColor(isDay ? .primary : .white)
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
            
            VStack(spacing: 5) {
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 5) {
                    // FIX: Using the Date as the ID for the ForEach loop to ensure uniqueness.
                    ForEach(datesInMonth.compactMap { $0 }, id: \.self) { date in
                        DayCell(
                            date: date,
                            isCompleted: viewModel.checkIfAllPrayersCompleted(for: date),
                            isDay: isDay
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(isDay ? Color.white.opacity(0.8) : Color.gray.opacity(0.1))
        .cornerRadius(15)
        .padding(.horizontal)
    }

    private func changeMonth(by months: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: months, to: selectedMonth) {
            selectedMonth = newMonth
        }
    }
}

struct DayCell: View {
    let date: Date
    let isCompleted: Bool
    let isDay: Bool
    
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
        PrayerCalendarView(isDay: true)
            .environmentObject(PrayerReminderViewModel())
    }
}
