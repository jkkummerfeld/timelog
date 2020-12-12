//
//  TimingStatsView.swift
//  Tracker-JKK
//
//  Created by Jonathan Kummerfeld on 7/8/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation
import Combine

struct TimeBox: Identifiable {
    let id: Int
    
    var color: Color
    var start: Double
    var end: Double
    
    var timing: PTiming
}

struct TimingBoxView: View {
    // Known issue:
    // If you create an unallocated chunk at the top, then double tap to edit, the new timing will have an endTime.
    // Instead, to add something new at the top, start the timer, then pull down
    
    // TODO:
    // - Code for 'Pick' button
    // - Update view every minute
    
    var startOfToday = Date().startOfDay
    
    @State private var showDatePicker = false
    
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
    
    @Binding var currentDate: Date
    @Binding var scale: Double
        
    // Edit by dragging
    @State private var editedRect = -1
    @State private var editedStart = 0.0
    @State private var editedEnd = 0.0
    @State private var editedScale = 0.0
    @State private var whichChanged = ""
    @State private var draggedToTop = false

    // edit by sheet
    @State private var showEditTiming = false
    @State private var timingToEdit: PTiming? = nil
    @State private var timingToEditTimerPos: Int = 0
    @State private var timingToEditEndTime: Date? = nil
    @State private var timingToEditStartTime = Date()
    
    func getScale() -> Double {
        if (editedScale > 0) {
            return min(500, max(25, scale * editedScale))
        } else {
            return scale
        }
    }
    
    func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            print("Error saving managed object context: \(error)")
        }
    }
    
    private func setToToday() {
        currentDate = startOfToday
    }
    
    func dayInDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    func timeToDouble(time: Date) -> Double {
        let calendar = Calendar.current
        let hour: Double = Double(calendar.component(.hour, from: time))
        let minute: Double = Double(calendar.component(.minute, from: time)) / 60.0
        let second: Double = Double(calendar.component(.second, from: time)) / 3600.0
        
        return hour + minute + second
    }
    
    // TODO: Avoid having a copy of this code
    func getColor(timerLabel: PTimerLabel?) -> Color {
        if let color = timerLabel?.color {
            let (_, h, s, b, _) = TimerLabelView.colorOptions[Int(color)]
            return Color(hue: h, saturation: s, brightness: b)
        } else {
            return Color.white
        }
    }
    
    func timingForDay(timingList: FetchedResults<PTiming>) -> [TimeBox] {
        return timingList.filter{ timing in
            if let startTime = timing.startTime {
                if let endTime = timing.endTime {
                    if (currentDate.startOfDay <= startTime && startTime <= currentDate.endOfDay) {
                        return true
                    } else if (currentDate.startOfDay <= endTime && endTime <= currentDate.endOfDay) {
                        return true
                    } else if (startTime < currentDate.startOfDay && currentDate.endOfDay < endTime) {
                        return true
                    }
                } else if (startTime <= currentDate.endOfDay) {
                    return true
                }
            }
            return false
        }.reduce([], { finalList, timing in
            let start = self.timeToDouble(time: max(currentDate.startOfDay, timing.startTime ?? currentDate.startOfDay))
            let end = self.timeToDouble(time: min(currentDate.endOfDay, timing.endTime ?? Date()))
            let color = self.getColor(timerLabel: timing.timer)
            
            let box = TimeBox(id: finalList.count, color: color, start: start, end: end, timing: timing)
            return finalList + [box]
        })
    }
    
    func hoursForDay(timingList: FetchedResults<PTiming>) -> [(Double, String)] {
        let timings = timingForDay(timingList: timingList)
        if (timings.count == 0) {
            return []
        } else {
            let maxTime = timings[0].end
            let maxHour = (currentDate == startOfToday ? Int(floor(maxTime)) : 24)
            var hours: [(Double, String)] = []
            
            for hour in 1...maxHour {
                if (hour == 12) {
                    hours.append((1.0, "\(12)pm"))
                } else if (hour == 0 || hour == 24) {
                    hours.append((1.0, "\(12)am"))
                } else if (hour > 12) {
                    hours.append((1.0, "\(hour-12)pm"))
                } else {
                    hours.append((1.0, "\(hour)am"))
                }
            }
            hours.append((maxTime - Double(maxHour) + (currentDate == startOfToday ? 0.5 : 0), ""))
            
            return hours.reversed()
        }
    }
    
    func getName(box: TimeBox) -> String {
        if (box.id == 0 && self.editedStart <= box.start && box.end <= self.editedEnd) {
            return ""
        } else {
            return box.timing.timer?.name ?? ""
        }
    }
    
    func editBoxColor(box: TimeBox, after: Bool = false, above: Bool = false, before: Bool = false) -> Color {
        if (after && self.editedRect == box.id && self.editedStart > box.start) {
            return Color.white
        } else if (above && self.editedRect == box.id && self.editedEnd < box.end) {
            return Color.white
        } else if (before && box.id == 0 && self.editedStart <= box.start && box.end <= self.editedEnd) {
            return Color.white
        } else {
            return box.color
        }
    }
    
    func boxHeight(box: TimeBox, above: Bool = false, before: Bool = false, after: Bool = false) -> CGFloat {
        // Default
        var start = box.start
        var end = box.end
        if (above || before) {
            start = end
        } else if (after) {
            end = start
        }
        if (box.id == 0 && !(above || before || after)) {
            if (currentDate == startOfToday) {
                end += 0.5
            }
        }
        
        if (self.editedRect == box.id) {
            // This one is being dragged
            if (!(above || before || after)) {
                if (self.editedStart > box.start) {
                   start = self.editedStart
                }
            } else if (above) {
                if (self.editedEnd < box.end) {
                    start = max(box.start, self.editedEnd)
                }
            } else if (before) {
                if (self.editedEnd > box.end) {
                    end = self.editedEnd
                }
            } else if (after) {
                if (self.editedStart < box.start) {
                    start = self.editedStart
                } else if (self.editedStart > box.start) {
                    end = self.editedStart
                }
           }
        } else if (self.editedRect >= 0) {
            if (!(above || before || after)) {
                // Something else is being dragged
                if (self.editedStart <= start && end <= self.editedEnd) {
                    // This is being completely covered
                    start = 0
                    end = 0
                } else if (self.editedStart <= start && start <= self.editedEnd) {
                    // This is partially covered, starting later
                    start = self.editedEnd
                    if (box.id == 0 && self.editedStart <= box.start && box.end <= self.editedEnd) {
                        end = start
                    }
                } else if (self.editedStart <= end && end <= self.editedEnd) {
                    // This is partially covered, ending earlier
                    end = self.editedStart
                }
            } else if (before) {
                if (box.id == 0 && self.editedStart <= box.start && box.end <= self.editedEnd) {
                    start = 0
                    if (currentDate == startOfToday) {
                        end = 0.5
                    } else {
                        end = 0
                    }
                }
            }
        }
        
        return CGFloat(max(0, end - start) * getScale())
    }
    
    func updateTiming(timing: PTiming?, timerLabel: PTimerLabel?, startTime: Date, endTimeOpt: Date?) {
        let endTime = endTimeOpt ?? Date()
        
        if let timingVal = timing {
            // List of timings that partially overlap with [startTime, endTime], sorted oldest to newest
            let impacted = timingList.filter{ otherTiming in
                if (otherTiming == timing) {
                    return true
                } else if let otherStart = otherTiming.startTime {
                    if let otherEnd = otherTiming.endTime {
                        return (startTime <= otherStart && otherStart < endTime) || (startTime < otherEnd && otherEnd <= endTime)
                    }
                    return startTime <= otherStart && otherStart < endTime
                } else if let otherEnd = otherTiming.endTime {
                    return startTime < otherEnd && otherEnd <= endTime
                } else {
                    return false
                }
            }.sorted{
                if let time0 = $0.startTime, let time1 = $1.startTime {
                    return time0 < time1
                } else {
                    return false
                }
            }
            
            if (impacted.count == 1) {
                // Making this smaller
                if let curStartTime = timingVal.startTime {
                    if (curStartTime < startTime) {
                        // Moving start time later
                        let newTiming = PTiming(context: managedObjectContext)
                        newTiming.startTime = curStartTime
                        newTiming.endTime = startTime
                        newTiming.timer = nil
                    } else if (curStartTime > startTime) {
                        // Moving start time earlier, but there are no earlier timings
                    } else if let curEndTime = timingVal.endTime {
                        // Currently has an end time
                        if (curEndTime > endTime) {
                            // Moving end time earlier
                            let newTiming = PTiming(context: managedObjectContext)
                            newTiming.startTime = endTime
                            newTiming.endTime = curEndTime
                            newTiming.timer = nil
                        }
                    } else if endTimeOpt != nil {
                        // Currently has no end time, but is getting one
                        let newTiming = PTiming(context: managedObjectContext)
                        newTiming.startTime = endTime
                        newTiming.endTime = nil
                        newTiming.timer = nil
                    }
                }
            } else {
                // Making this larger
                impacted.forEach{ otherTiming in
                    if (otherTiming != timingVal) {
                        if let otherStart = otherTiming.startTime {
                            if let otherEnd = otherTiming.endTime {
                                if (startTime <= otherStart && otherEnd <= endTime) {
                                    // Remove as it is completely covered
                                    self.managedObjectContext.delete(otherTiming)
                                } else if (startTime <= otherStart && otherStart < endTime) {
                                    // Partially covered, now starting later
                                    otherTiming.startTime = endTime
                                } else if (startTime <= otherEnd && otherEnd < endTime) {
                                    // Partially covered, now ending earlier
                                    otherTiming.endTime = startTime
                                }
                            } else {
                                if (startTime <= otherStart && endTimeOpt == nil) {
                                    // Remove as it is completely covered
                                    self.managedObjectContext.delete(otherTiming)
                                } else {
                                    // Partially covered, now starting later
                                    otherTiming.startTime = endTime
                                }
                            }
                        }
                    }
                }
            }
            
            // Update the current timing
            timingVal.timer = timerLabel
            timingVal.startTime = startTime
            if (endTimeOpt == nil) {
                timingVal.endTime = nil
            } else {
                timingVal.endTime = endTime
            }
            // TODO: If the adjacent one (maybe in impacted list, maybe not) has the same label, merge them
            
            saveContext()
        }
    }
    
    func endDrag(timing: PTiming) {
        let startTime: Date = whichChanged == "end" ? timing.startTime! : Date(timeInterval: self.editedStart * 3600, since: self.currentDate.startOfDay)
        let endTime: Date? = self.draggedToTop ? nil : (whichChanged == "start" ? timing.endTime : Date(timeInterval: self.editedEnd * 3600, since: self.currentDate.startOfDay))
        self.updateTiming(timing: timing, timerLabel: timing.timer, startTime: startTime, endTimeOpt: endTime)
    }
    
    func updateDrag(startY: CGFloat, currentY: CGFloat, timeBox: TimeBox) {
        let zeroExtra = (timeBox.id == 0 ? 0.5 : 0)
        let boxSize = (timeBox.end - timeBox.start + zeroExtra) * getScale()
        let shift = Double(currentY - startY)/getScale()
        if (startY < 80 && Double(startY) < boxSize / 2) {
            self.editedStart = timeBox.start
            let max_val = (currentDate == startOfToday) ? timeToDouble(time: Date()) : 24
            self.editedEnd = min(max_val, max(timeBox.start, timeBox.end - shift))
            self.whichChanged = "end"
            self.draggedToTop = self.editedEnd == max_val
        } else if (Double(startY) > boxSize - 80) {
            self.editedStart = max(0, min(timeBox.end, timeBox.start - shift))
            self.editedEnd = timeBox.end
            self.whichChanged = "start"
        } else {
            self.editedStart = timeBox.start
            self.editedEnd = timeBox.end
            self.whichChanged = ""
        }
    }
    
    func getEditedTime() -> (String, Double) {
        if (whichChanged == "") {
            return ("", 0)
        } else {
            let time = whichChanged == "start" ? editedStart : editedEnd
            let hours = Int(floor(time))
            let minutes = Int(round(60.0 * (time - Double(hours))))
            let timings = timingForDay(timingList: timingList)
            let maxTime = timings[0].end
            let diff = maxTime - time + (currentDate == startOfToday ? 0.5 : 0)
            
            let hourString = hours > 12 ? "\(hours - 12)" : "\(hours)"
            let minuteString = minutes < 10 ? "0\(minutes)" : "\(minutes)"
            return ("\(hourString):\(minuteString)", diff)
        }
    }
    
    struct DrawHour: View {
        let height: Double
        let time: String
        let minutes: Double
        
        var body: some View {
            ZStack(alignment: .top) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 100, height: CGFloat(height))
                VStack(spacing: 0) {
                    // TODO: Dynamic positions so we can have it for the partial hour at the top
                    Spacer()
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(time == "" ? Color.white : Color.gray)
                            .frame(width: 10, height: 1)
                    }.frame(width: 100)
                    Spacer()
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(time == "" ? Color.white : Color.gray)
                            .frame(width: 10, height: 1)
                    }.frame(width: 100)
                    Spacer()
                    HStack {
                        Spacer()
                        Rectangle()
                            .fill(time == "" ? Color.white : Color.gray)
                            .frame(width: 10, height: 1)
                    }.frame(width: 100)
                    Spacer()
                }.frame(width: 100, height: CGFloat(height))
                Text(time)
                    .frame(width: 100, height: CGFloat(height), alignment: .top)
                Rectangle()
                    .fill(time == "" ? Color.white : Color.gray)
                    .frame(width: 100, height: 1)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 2)
                    HStack(alignment: .top, spacing: 0) {
                        ZStack(alignment: .top) {
                            VStack(spacing: 0) {
                                ForEach(hoursForDay(timingList: timingList), id: \.1) { time in
                                    DrawHour(height: time.0 * self.getScale(), time: time.1, minutes: time.0 * 60)
                                }
                            }
                            .contentShape(Rectangle())
                            .gesture(
                                MagnificationGesture().onChanged{ rescale in
                                    self.editedScale = Double(rescale)
                                }.onEnded{ finalScale in
                                    self.scale = self.getScale()
                                    self.editedScale = 0.0
                                })
                            VStack(spacing: 0) {
                                Spacer().frame(height: CGFloat(max(10, getEditedTime().1 * self.getScale() - 10)))
                                HStack {
                                    Spacer()
                                    Text(getEditedTime().0).foregroundColor(Color.blue)
                                    Spacer().frame(width: 10)
                                }.frame(width: 100)
                            }
                        }
                        
                        VStack(spacing: 0) {
                            ForEach(timingForDay(timingList: timingList), id: \.id) { timeBox in
                                // TODO: Extract into its own struct
                                VStack(alignment: .leading, spacing: 0) {
                                    Rectangle()
                                        .fill(self.editBoxColor(box: timeBox, before: true))
                                        .frame(width: 100, height: self.boxHeight(box: timeBox, before: true))
                                    ZStack(alignment: .topLeading) {
                                        HStack(alignment: .top, spacing: 10) {
                                            Rectangle()
                                                .fill(timeBox.color)
                                                .frame(width: 100, height: self.boxHeight(box: timeBox))
                                                .highPriorityGesture(
                                                    DragGesture(minimumDistance: 5).onChanged{ value in
                                                        if (self.editedRect != timeBox.id) {
                                                            self.editedRect = timeBox.id
                                                        }
                                                        self.updateDrag(startY: value.startLocation.y, currentY: value.location.y, timeBox: timeBox)
                                                    }.onEnded{ value in
                                                        self.updateDrag(startY: value.startLocation.y, currentY: value.location.y, timeBox: timeBox)
                                                        self.endDrag(timing: timeBox.timing)
                                                        self.editedRect = -1
                                                        self.editedStart = 0.0
                                                        self.editedEnd = 0.0
                                                        self.whichChanged = ""
                                                    })
                                            ZStack(alignment: .top) {
                                                Rectangle()
                                                    .fill(Color.white)
                                                    .frame(minWidth: 100, maxWidth: 400, minHeight: self.boxHeight(box: timeBox), maxHeight: self.boxHeight(box: timeBox)
                                                    )
                                                Text(self.getName(box: timeBox))
                                                    .frame(minWidth: 100, maxWidth: 400, minHeight: self.boxHeight(box: timeBox), maxHeight: self.boxHeight(box: timeBox), alignment: .topLeading)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture(count: 2) {
                                            self.timingToEditStartTime = timeBox.timing.startTime!
                                            self.timingToEditEndTime = timeBox.timing.endTime
                                            if let timer = timeBox.timing.timer {
                                                self.timingToEditTimerPos = self.timerList.firstIndex(of: timer) ?? 0
                                            } else {
                                                self.timingToEditTimerPos = 0
                                            }
                                            self.timingToEdit = timeBox.timing
                                            self.showDatePicker = false
                                            self.showEditTiming.toggle()
                                        }
                                        Rectangle()
                                            .fill(self.editBoxColor(box: timeBox, above: true))
                                            .frame(width: 100, height: self.boxHeight(box: timeBox, above: true))
                                    }
                                    Rectangle()
                                        .fill(self.editBoxColor(box: timeBox, after: true))
                                        .frame(width: 100, height: self.boxHeight(box: timeBox, after: true))
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(
                Text(""),
                displayMode: .inline
            )
            .navigationBarItems(
                leading: HStack(spacing: 20) {
                    Button(action: {
                        self.currentDate -= TimeInterval(3600 * 24)
                    }) {
                        Image(systemName: "arrowtriangle.left.fill")
                    }
                    Spacer()
                    DatePicker("", selection: self.$currentDate, in: ...Date(), displayedComponents: .date)
                },
                trailing: HStack(spacing: 20) {
                    Button(action: {
                        self.currentDate = self.startOfToday
                    }) {
                        Text("Today")
                    }.disabled(self.currentDate == startOfToday)
                    Button(action: {
                        self.currentDate += TimeInterval(3600 * 24)
                    }) {
                        Image(systemName: "arrowtriangle.right.fill")
                    }.disabled(self.currentDate == startOfToday)
                }
            )
            .sheet(isPresented: $showEditTiming) {
                if (self.showDatePicker) {
                    VStack {
                        DatePicker("Set:", selection: self.$currentDate, in: ...Date(), displayedComponents: .date)
                        Button(action: {
                            self.showEditTiming = false
                        }) {
                          Text("Done")
                        }
                    }
                } else {
                    TimingView(
                        timerPos: self.timingToEditTimerPos,
                        startTime: self.timingToEditStartTime,
                        endTime: self.timingToEditEndTime ?? Date()
                    ) { timerPos, startTime, endTime in
                        self.updateTiming(timing: self.timingToEdit, timerLabel: self.timerList[timerPos], startTime: startTime, endTimeOpt: endTime)
                        self.timingToEditTimerPos = 0
                        self.timingToEditEndTime = nil
                        self.timingToEditStartTime = Date()
                        self.showEditTiming = false
                        self.timingToEdit = nil
                    }
                    .environment(\.managedObjectContext, self.managedObjectContext)
                }
            }
        }.navigationViewStyle(StackNavigationViewStyle())
    }
}
