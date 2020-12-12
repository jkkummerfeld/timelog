//
//  TimingSectionView.swift
//  Tracker-JKK
//
//  Created by Jonathan Kummerfeld on 10/7/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import SwiftUI
import CoreData

struct TimingSectionView: View {
    let dateStr: String
    let date: Date
    
    @State private var showEditTiming = false
    @State private var timingToEdit: PTiming? = nil
    @State private var timingToEditTimerPos: Int = 0
    @State private var timingToEditEndTime: Date? = nil
    @State private var timingToEditStartTime = Date()
    
    // TODO: use timer to auto-update
    
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
        NSSortDescriptor(keyPath: \PTiming.startTime, ascending: true)
      ]
    ) var timingList: FetchedResults<PTiming>

    func timingForDay(timingList: FetchedResults<PTiming>) -> [PTiming] {
        return timingList.filter{ timing in
            if let startTime = timing.startTime {
                if let endTime = timing.endTime {
                    if (date <= startTime && startTime <= date + 60*60*24) {
                        return true
                    } else if (date <= endTime && endTime <= date + 60*60*24) {
                        return true
                    } else if (startTime < date && date + 60*60*24 < endTime) {
                        return true
                    }
                } else if (startTime <= date + 60*60*24) {
                    return true
                }
            }
            return false
        }
    }
    
    func stringInterval(_ timing: PTiming) -> String {
        if let startTime = timing.startTime {
            let endTime = timing.endTime ?? Date()
            let timeDiff = endTime.timeIntervalSince(startTime)

            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .short
            if (timeDiff > 60) {
                formatter.allowedUnits = [.hour, .minute]
            } else {
                formatter.allowedUnits = [.second]
            }
            let time = formatter.string(from: timeDiff)!
            return "\(time)"
        }
        return "No time"
    }
    
    func timeString(_ time: Date?) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        timeFormatter.locale = Locale(identifier: "en_US")
        
        if let ctime = time {
            if (ctime < date) {
                return timeFormatter.string(from: date)
            } else {
                return timeFormatter.string(from: ctime)
            }
        } else {
            return "Error"
        }
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
    
    func deleteTiming(at offsets: IndexSet) {
        let options = timingForDay(timingList: timingList)
        offsets.forEach { index in
            options[index].timer = nil
        }
        saveContext()
    }

    func saveContext() {
        do {
            try managedObjectContext.save()
        } catch {
            print("Error saving managed object context: \(error)")
        }
    }
    
    var body: some View {
        ForEach(timingForDay(timingList: timingList), id: \.startTime) { timing in
            HStack(spacing: 20) {
                HStack {
                    Spacer()
                        .frame(width: 10)
                    VStack {
                        Text(self.timeString(timing.startTime))
                            .font(.system(size: 20))
                            .frame(minWidth: 100, alignment: .topLeading)
                        Spacer()
                    }
                    Text(timing.timer?.name ?? "Unallocated")
                        .frame(minHeight: 50)
                    Spacer()
                }.background(Color.white)
                Rectangle()
                    .fill(self.getColor(timerLabel: timing.timer))
                    .frame(width: 30, height: 20)
            }
            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            .background(self.getColor(timerLabel: timing.timer))
            .onTapGesture(count: 2) {
                self.timingToEditStartTime = timing.startTime!
                self.timingToEditEndTime = timing.endTime
                if let timer = timing.timer {
                    self.timingToEditTimerPos = self.timerList.firstIndex(of: timer) ?? 0
                } else {
                    self.timingToEditTimerPos = 0
                }
                self.timingToEdit = timing
                self.showEditTiming.toggle()
            }
            .onTapGesture(count: 1) {
                // todo
            }
        }
        .onDelete(perform: self.deleteTiming)
        .sheet(isPresented: $showEditTiming) {
            TimingView(
                timerPos: self.timingToEditTimerPos,
                startTime: self.timingToEditStartTime,
                endTime: self.timingToEditEndTime ?? Date()
            ) { timerPos, startTime, endTime in
                self.updateTiming(timing: self.timingToEdit, timerLabel: self.timerList[timerPos], startTime: startTime, endTime: endTime)
                self.timingToEditTimerPos = 0
                self.timingToEditEndTime = nil
                self.timingToEditStartTime = Date()
                self.showEditTiming = false
                self.timingToEdit = nil
            }
            .environment(\.managedObjectContext, self.managedObjectContext)
        }
    }
    
    func updateTiming(timing: PTiming?, timerLabel: PTimerLabel, startTime: Date, endTime: Date) {
        if let timingToEdit = timing {
            let impacted = timingList.filter{ otherTiming in
                if let otherStart = otherTiming.startTime {
                    if let otherEnd = otherTiming.endTime {
                        return (startTime <= otherStart && otherStart < endTime) || (startTime < otherEnd && otherEnd <= endTime)
                    }
                    return startTime <= otherStart && otherStart < endTime
                } else if let otherEnd = otherTiming.endTime {
                    return startTime < otherEnd && otherEnd <= endTime
                } else {
                    return false
                }
            }
            
            if (impacted.last == timingToEdit) {
                if let curEnd = timingToEdit.endTime {
                    if (curEnd > endTime) {
                        if (timingList.last != timingToEdit) {
                            // Create a blank chunk
                            let newTiming = PTiming(context: managedObjectContext)
                            newTiming.startTime = endTime
                            newTiming.endTime = curEnd
                            newTiming.timer = nil
                        }
                    }
                }
            } else if let firstTiming = impacted.last {
                // If first timing is not fully within the new time, edit it to start at endTime
                if let firstStart = firstTiming.startTime {
                    if (endTime > firstStart) {
                        firstTiming.startTime = endTime
                    }
                }
            }
            if (impacted.first == timingToEdit) {
                if let curStart = timingToEdit.startTime {
                    if (curStart < startTime) {
                        // Create a blank chunk
                        let newTiming = PTiming(context: managedObjectContext)
                        newTiming.startTime = curStart
                        newTiming.endTime = startTime
                        newTiming.timer = nil
                    }
                }
            } else if let lastTiming = impacted.first {
                // If last timing is not fully within the new time, edit it to end at startTime
                if let lastEnd = lastTiming.endTime {
                    if (startTime < lastEnd) {
                        lastTiming.endTime = startTime
                    }
                }
            }
            
            // Remove all that are completely within the new timing
            impacted.forEach{ otherTiming in
                if let otherStart = otherTiming.startTime {
                    if let otherEnd = otherTiming.endTime {
                        if (otherTiming != timingToEdit && startTime <= otherStart && otherEnd <= endTime) {
                            self.managedObjectContext.delete(otherTiming)
                        }
                    }
                }
            }
            
            // Update the current timing
            timingToEdit.timer = timerLabel
            timingToEdit.startTime = startTime
            if (timingList.last != timingToEdit) {
                timingToEdit.endTime = endTime
            }
            
            // TODO: If the adjacent one (maybe in impacted list, maybe not) has the same label, merge them
            
            saveContext()
        }
    }
}
