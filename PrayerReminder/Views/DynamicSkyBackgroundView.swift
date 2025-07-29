//
//  DynamicSkyBackgroundView.swift
//  PrayerReminder
//
//  Created by Mac on 26.07.2025.
//

import SwiftUI

struct DynamicSkyBackgroundView: View {
    let prayers: [Prayer] // Still needed for gradient calculation logic, but isDay comes from VM
    let isDay: Bool // NEW: Receive isDay from ViewModel
    @State private var currentDate = Date()
    
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let skyGradient = calculateSkyGradient()

            skyGradient
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 5), value: isDay)

            Image(systemName: isDay ? "sun.max.fill" : "moon.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(isDay ? .yellow : .white)
                .shadow(color: isDay ? .yellow.opacity(0.6) : .white.opacity(0.4), radius: 15)
                .position(x: geometry.size.width / 2, y: geometry.size.height * 0.2)
                .animation(.easeInOut(duration: 5), value: isDay)

            if isDay {
                Group {
                    Image(systemName: "cloud.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 60)
                        .foregroundColor(Color.white.opacity(0.7))
                        .position(x: geometry.size.width * 0.2, y: geometry.size.height * 0.15)
                    Image(systemName: "cloud.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 70)
                        .foregroundColor(Color.white.opacity(0.6))
                        .position(x: geometry.size.width * 0.8, y: geometry.size.height * 0.25)
                }
                .animation(.easeInOut(duration: 2), value: isDay)
            }

            if !isDay {
                Group {
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                        .foregroundColor(.white)
                        .opacity(Double.random(in: 0.5...1.0))
                        .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.05)
                        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: currentDate)
                    
                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.white)
                        .opacity(Double.random(in: 0.5...1.0))
                        .position(x: geometry.size.width * 0.9, y: geometry.size.height * 0.1)
                        .animation(Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: currentDate)

                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .foregroundColor(.white)
                        .opacity(Double.random(in: 0.5...1.0))
                        .position(x: geometry.size.width * 0.35, y: geometry.size.height * 0.08)
                        .animation(Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: currentDate)

                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 8, height: 8)
                        .foregroundColor(.white)
                        .opacity(Double.random(in: 0.5...1.0))
                        .position(x: geometry.size.width * 0.65, y: geometry.size.height * 0.03)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: currentDate)

                    Image(systemName: "star.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 10, height: 10)
                        .foregroundColor(.white)
                        .opacity(Double.random(in: 0.5...1.0))
                        .position(x: geometry.size.width * 0.55, y: geometry.size.height * 0.15)
                        .animation(Animation.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: currentDate)

                }
                .animation(.easeInOut(duration: 5), value: isDay)
            }
        }
        .onReceive(timer) { input in
            currentDate = input
        }
    }

    // Removed internal isDaytime() as it's now passed from ViewModel
    
    private func calculateSkyGradient() -> LinearGradient {
        // Define day colors
        let dayColorTop = Color(red: 0.53, green: 0.81, blue: 0.98)
        let dayColorBottom = Color(red: 0.88, green: 0.94, blue: 1.0)

        // Define night colors (black at top, dark blue/purple in middle, white/light gray at bottom)
        let nightColorTop = Color.black // Pure black at the very top
        let nightColorMiddle = Color(red: 0.1, green: 0.05, blue: 0.2, opacity: 0.9) // Deep dark purple/blue
        let nightColorBottom = Color(red: 0.15, green: 0.1, blue: 0.25, opacity: 0.7) // Slightly lighter dark purple/blue

        let colors: [Color]
        let startPoint: UnitPoint
        let endPoint: UnitPoint

        if isDay {
            colors = [dayColorTop, dayColorBottom]
            startPoint = .top
            endPoint = .bottom
        } else {
            // FIX: More nuanced night gradient
            colors = [nightColorTop, nightColorMiddle, nightColorBottom]
            startPoint = .top
            endPoint = .bottom
        }

        return LinearGradient(gradient: Gradient(colors: colors), startPoint: startPoint, endPoint: endPoint)
    }

    private func interpolateColor(from color1: Color, to color2: Color, progress: Double) -> Color {
        let clampedProgress = min(1.0, max(0.0, progress))
        
        guard let c1 = UIColor(color1).cgColor.components,
              let c2 = UIColor(color2).cgColor.components else { return color1 }
        
        let r = c1[0] + (c2[0] - c1[0]) * clampedProgress
        let g = c1[1] + (c2[1] - c1[1]) * clampedProgress
        let b = c1[2] + (c2[2] - c1[2]) * clampedProgress
        let a = c1.count > 3 ? c1[3] + (c2[3] - c1[3]) * clampedProgress : 1.0
        
        return Color(red: r, green: g, blue: b, opacity: a)
    }

    private let timeLogicHelper = PrayerTimeLogicHelper()
}

#Preview {
    DynamicSkyBackgroundView(
        prayers: [
            Prayer(name: "Fajr", time: "04:30", status: .upcoming),
            Prayer(name: "Sunrise", time: "06:00", status: .upcoming),
            Prayer(name: "Dhuhr", time: "13:00", status: .upcoming),
            Prayer(name: "Asr", time: "17:00", status: .upcoming),
            Prayer(name: "Maghrib", time: "19:30", status: .upcoming),
            Prayer(name: "Isha", time: "21:00", status: .upcoming)
        ],
        isDay: false // Set to false for night mode preview
    )
}
