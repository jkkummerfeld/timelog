//
//  TimerLabelView.swift
//  JKK-Tracker
//
//  Created by Jonathan Kummerfeld on 15/5/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import SwiftUI
import CoreData

struct TimingView: View {
    // TODO: Show view to:
    // change the timer it is assigned to (if the choice is the same as an adjacent timer, merge them instead)
    // split in two

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
    
    @State var timerPos: Int
    @State var startTime: Date
    @State var endTime: Date
    let onComplete: (Int, Date, Date) -> Void
    
    func getColor(timerLabel: PTimerLabel?) -> Color {
        if let color = timerLabel?.color {
            let (_, h, s, b, _) = TimerLabelView.colorOptions[Int(color)]
            return Color(hue: h, saturation: s, brightness: b)
        } else {
            return Color.white
        }
    }
    
    func stringInterval(_ timing: PTiming) -> String {
        if let cstartTime = timing.startTime {
            if let cendTime = timing.endTime {
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                dateFormatter.timeStyle = .none
                dateFormatter.locale = Locale(identifier: "en_US")
                let timeFormatter = DateFormatter()
                timeFormatter.dateStyle = .none
                timeFormatter.timeStyle = .short
                timeFormatter.locale = Locale(identifier: "en_US")
                
                let sday = dateFormatter.string(from: cstartTime)
                let eday = dateFormatter.string(from: cendTime)
                let stime = timeFormatter.string(from: cstartTime)
                let etime = timeFormatter.string(from: cendTime)
                if (sday == eday) {
                    let spos = stime.lastIndex(of: " ")!
                    let epos = stime.lastIndex(of: " ")!
                    let send = stime[spos...]
                    let sstart = stime[...spos]
                    let eend = etime[epos...]
                    let estart = etime[...epos]
                    if (send == eend) {
                        return "\(sday)\n\(sstart)- \(estart)\(send)"
                    } else {
                        return "\(sday)\n\(stime) - \(etime)"
                    }
                } else {
                    return "\(sday), \(stime) -\n\(eday), \(etime)"
                }
            }
        }
        return "No time"
    }
    
    func timingsCovered(timingList: FetchedResults<PTiming>) -> [PTiming] {
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
    
    var body: some View {
        // TODO fix Warning: Attempt to present <_TtGC7SwiftUIP13$7fff2c9bdf5c22SheetHostingControllerVS_7AnyView_: 0x7fe9c2ce80f0>  on <_TtGC7SwiftUI19UIHostingControllerVVS_22_VariadicView_Children7Element_: 0x7fe9c2e28e00> which is already presenting (null)
        //
        NavigationView {
            Form {
                Section(header: Text("Timer")) {
                    Picker("Timer", selection: $timerPos) {
                        ForEach(0..<self.timerList.count, id: \.self) { index in
                            HStack(spacing: 20) {
                                HStack {
                                    Spacer()
                                        .frame(width: 10)
                                    Text(self.timerList[index].name ?? "Unallocated")
                                        .frame(minHeight: 50)
                                    Spacer()
                                }
                                .background(Color.white)
                                Rectangle()
                                    .fill(self.getColor(timerLabel: self.timerList[index]))
                                    .frame(width: 100, height: 20)
                            }
                            .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .background(self.getColor(timerLabel: self.timerList[index]))
                        }
                    }
                    .labelsHidden()
                }
                
                Section(header: Text("Time Span")) {
                    DatePicker(selection: $startTime, in: ...endTime, displayedComponents: .date) {
                        Text("Start Date")
                    }
                    DatePicker(selection: $startTime, in: ...endTime, displayedComponents: .hourAndMinute) {
                        Text("Start Time")
                    }
                    DatePicker(selection: $endTime, in: startTime...Date(), displayedComponents: .date) {
                        Text("End Date")
                    }
                    DatePicker(selection: $endTime, in: startTime...Date(), displayedComponents: .hourAndMinute) {
                        Text("End Time")
                    }
                }
                
                Section(header: Text("Timings Affected")) {
                    ForEach(timingsCovered(timingList: timingList), id: \.startTime) { timing in
                        HStack(spacing: 20) {
                            HStack {
                                Spacer()
                                    .frame(width: 10)
                                VStack {
                                    Spacer()
                                    Text(self.stringInterval(timing))
                                        .frame(minWidth: 100, alignment: .leading)
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
                    }
                }
                    
                Section {
                  Button(action: editTimingAction) {
                    Text("Apply Edits")
                  }
                }
            }
            .navigationBarTitle(Text("Apply Edits"), displayMode: .inline)
        }
    }
    
    private func editTimingAction() {
        onComplete(
            timerPos,
            startTime,
            endTime
        )
    }
}
