//
//  TimingStatsView.swift
//  Tracker-JKK
//
//  Created by Jonathan Kummerfeld on 2/8/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation

extension Date {
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay)!
    }
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: startOfDay)
        return Calendar.current.date(from: components)!
    }
    var endOfMonth: Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth)!
    }
    var startOfWeek: Date {
        let gregorian = Calendar(identifier: .gregorian)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE"
        let dayName = dateFormatter.string(from: self)
        if (dayName == "Monday") { return startOfDay }
        if (dayName == "Tuesday") { return gregorian.date(byAdding: .day, value: -1, to: startOfDay)! }
        if (dayName == "Wednesday") { return gregorian.date(byAdding: .day, value: -2, to: startOfDay)! }
        if (dayName == "Thursday") { return gregorian.date(byAdding: .day, value: -3, to: startOfDay)! }
        if (dayName == "Friday") { return gregorian.date(byAdding: .day, value: -4, to: startOfDay)! }
        return gregorian.date(byAdding: .day, value: -5, to: startOfDay)!
    }
    var endOfWeek: Date {
        var components = DateComponents()
        components.day = 7
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfWeek)!
    }
}

struct TimingStatsView: View {
    var startOfDay = Date().startOfDay
    var endOfDay = Date().endOfDay
    var startOfMonth = Date().startOfMonth
    var endOfMonth = Date().endOfMonth
    var startOfWeek = Date().startOfWeek
    var endOfWeek = Date().endOfWeek
    
    @Environment(\.managedObjectContext) var managedObjectContext

    @FetchRequest(
        entity: PTimerLabel.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \PTimerLabel.position, ascending: true)
        ]
    ) var timerList: FetchedResults<PTimerLabel>
    
    @FetchRequest(
      entity: PTiming.entity(),
      sortDescriptors: [
        NSSortDescriptor(keyPath: \PTiming.startTime, ascending: false)
      ]
    ) var timingList: FetchedResults<PTiming>
    
    @Binding var startTime: Date
    @Binding var endTime: Date

    func timingsInRange() -> [PTiming] {
        return timingList.filter{ timing in
            if let otherStart = timing.startTime {
                if let otherEnd = timing.endTime {
                    return (startTime <= otherStart && otherStart < endTime) || (startTime < otherEnd && otherEnd <= endTime)
                }
                return startTime <= otherStart && otherStart < endTime
            } else if let otherEnd = timing.endTime {
                return startTime < otherEnd && otherEnd <= endTime
            } else {
                return false
            }
        }
    }
    
    func totalTimeForTimer(timer: PTimerLabel) -> String {
        let covered = timingsInRange()
        
        let time = covered.filter{ timing in
            return timing.timer == timer
        }.reduce(0.0, {(totalTime, timing) in
            if let cstart = timing.startTime {
                let start = max(startTime, cstart)
                let end = min(endTime, timing.endTime ?? Date())
                let timeDiff = end.timeIntervalSince(start)
                return totalTime + timeDiff
            } else {
                return totalTime
            }
        })
        
        let minutes = time.truncatingRemainder(dividingBy: 3600) / 60
        let hours = (time / 3600).rounded(.towardZero)
        if (hours < 100) {
            let timeString = String(format: "% 2.0f:%02.0f", hours, minutes)
            return timeString
        } else {
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .full
            formatter.allowedUnits = [.day, .hour]
            let timeString = formatter.string(from: time)!
            return timeString.components(separatedBy: ", ").joined(separator: ",\n")
        }
    }
    
    func getColor(timerLabel: PTimerLabel?) -> Color {
        if let color = timerLabel?.color {
            let (_, h, s, b, _) = TimerLabelView.colorOptions[Int(color)]
            return Color(hue: h, saturation: s, brightness: b)
        } else {
            return Color.white
        }
    }
    
    
    private func setToToday() {
        startTime = startOfDay
        endTime = endOfDay
    }
    private func setToThisWeek() {
        startTime = startOfWeek
        endTime = endOfWeek
    }
    private func setToThisMonth() {
        startTime = startOfMonth
        endTime = endOfMonth
    }
    
    var dayButton: some View {
        return VStack {
            Spacer()
            Button(action: setToToday) {
                Text("Today").multilineTextAlignment(.center)
            }
                .disabled(startTime == startOfDay && endTime == endOfDay)
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(startTime == startOfDay && endTime == endOfDay ? Color.gray : Color.blue)
            HStack {
                Button(action: {
                    self.startTime -= TimeInterval(3600 * 24)
                    self.endTime -= TimeInterval(3600 * 24)
                }) {
                    Image(systemName: "arrowtriangle.left.fill")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    self.startTime += TimeInterval(3600 * 24)
                    self.endTime += TimeInterval(3600 * 24)
                }) {
                    Image(systemName: "arrowtriangle.right.fill")
                }.disabled(self.startTime == startOfDay)
                .buttonStyle(BorderlessButtonStyle())
            }
            Spacer()
        }
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
    var weekButton: some View {
        return VStack {
            Spacer()
            Button(action: setToThisWeek) {
                Text("This week").multilineTextAlignment(.center)
            }
                .disabled(startTime == startOfWeek && endTime == endOfWeek)
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(startTime == startOfWeek && endTime == endOfWeek ? Color.gray : Color.blue)
            HStack {
                Button(action: {
                    self.startTime -= TimeInterval(3600 * 24 * 7)
                    self.endTime -= TimeInterval(3600 * 24 * 7)
                }) {
                    Image(systemName: "arrowtriangle.left.fill")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    self.startTime += TimeInterval(3600 * 24 * 7)
                    self.endTime += TimeInterval(3600 * 24 * 7)
                }) {
                    Image(systemName: "arrowtriangle.right.fill")
                }.disabled(self.endTime + TimeInterval(3600 * 24 * 7) > endOfWeek)
                .buttonStyle(BorderlessButtonStyle())
            }
            Spacer()
        }
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
    var monthButton: some View {
        return VStack {
            Spacer()
            Button(action: setToThisMonth) {
                Text("This month").multilineTextAlignment(.center)
            }
                .disabled(startTime == startOfMonth && endTime == endOfMonth)
                .buttonStyle(BorderlessButtonStyle())
                .foregroundColor(startTime == startOfMonth && endTime == endOfMonth ? Color.gray : Color.blue)
            HStack {
                Button(action: {
                    var components = DateComponents()
                    components.month = -1
                    self.startTime = Calendar.current.date(byAdding: components, to: self.startTime)!
                    components.month = 1
                    components.second = -1
                    self.endTime = Calendar.current.date(byAdding: components, to: self.startTime)!
                }) {
                    Image(systemName: "arrowtriangle.left.fill")
                }
                .buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    var components = DateComponents()
                    components.month = 1
                    self.startTime = Calendar.current.date(byAdding: components, to: self.startTime)!
                    components.month = 1
                    components.second = -1
                    self.endTime = Calendar.current.date(byAdding: components, to: self.startTime)!
                }) {
                    Image(systemName: "arrowtriangle.right.fill")
                }.disabled(self.endTime + TimeInterval(3600 * 24 * 28) > endOfMonth)
                .buttonStyle(BorderlessButtonStyle())
            }
            Spacer()
        }
            .padding(EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10))
    }
    
    var body: some View {
        NavigationView {
            List {
                HStack {
                    dayButton
                    Spacer()
                    weekButton
                    Spacer()
                    monthButton
                }
                DatePicker(selection: $startTime, in: ...endTime, displayedComponents: .date) {
                    Text("Start Date")
                }
                DatePicker(selection: $endTime, in: startTime..., displayedComponents: .date) {
                    Text("End Date")
                }
            
                ForEach(timerList, id: \.name) { timerLabel in
                  //  totalTimeForTimer
                    HStack(spacing: 20) {
                        HStack {
                            Text(self.totalTimeForTimer(timer: timerLabel))
                                .padding(.leading, 10)
                                .frame(width: 120, alignment: .leading)

                            VStack {
                                Spacer()
                                Text(timerLabel.name ?? "Unknown Timer")
                                    .frame(minHeight: 50)
                                Spacer()
                            }
                            Spacer()
                        }.background(Color.white)
                        Rectangle()
                            .fill(self.getColor(timerLabel: timerLabel))
                            .frame(width: 50, height: 20)
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .background(self.getColor(timerLabel: timerLabel))
                }
            }
            //.listStyle(GroupedListStyle())
            .navigationBarTitle("Timer Stats", displayMode: .inline)
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
