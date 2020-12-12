//
//  ContentView.swift
//  JKK-Tracker
//
//  Created by Jonathan Kummerfeld on 12/5/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State private var selection = 0
    @State private var showNewTimerLabel = false
    @State private var timerLabelToEdit: PTimerLabel? = nil
    @State private var timerLabelToEditName = ""
    @State private var timerLabelToEditColor = 0
    @State private var showNewTimerLabelSubmitText = "Add Timer"
    @State private var showEditTiming = false
    
    @State var statsStart: Date = Date().startOfDay
    @State var statsEnd: Date = Date().endOfDay
    @State var logDate: Date = Date().startOfDay
    @State var logScale: Double = 100.0
    
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
    
    func dayInDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    func timingStartDays(timingList: FetchedResults<PTiming>) -> [Date] {
        let dates: [Date] = timingList.map{ timing in
            if let startTime = timing.startTime {
                return startTime
            } else {
                return Date(timeIntervalSince1970: 0.0)
            }
        }.filter{ date in
            return date > Date(timeIntervalSince1970: 1.0)
        }.map{date in
            let calendar = Calendar.current
            return calendar.startOfDay(for: date)
        }
        return dates.reduce(into: [Date]()) {(dates, date) in
            if dates.count == 0 || dates[dates.count - 1] != date {
                dates.append(date)
            }
        }
    }
    
    func getCurTiming() -> PTiming? {
        if (timingList.count > 0) {
            return timingList[0]
        } else {
            return nil
        }
    }
    
    // TODO: Change to make default colour white
    func getColor(timerLabel: PTimerLabel?) -> Color {
        if let color = timerLabel?.color {
            let (_, h, s, b, _) = TimerLabelView.colorOptions[Int(color)]
            return Color(hue: h, saturation: s, brightness: b)
        } else {
            return Color.white
        }
    }
    
    func textColor(timerLabel: PTimerLabel) -> Color {
        if (getCurTiming()?.timer == timerLabel) {
            return Color.white
        } else {
            return Color.black
        }
    }
    
    var timerLabelListView: some View {
        List {
            ForEach(timerList, id: \.name) { timerLabel in
                HStack(spacing: 20) {
                    HStack {
                        Spacer()
                            .frame(width: 10)

                        VStack {
                            Spacer()
                            Text(timerLabel.name ?? "Unknown Timer")
                                .foregroundColor(self.textColor(timerLabel: timerLabel))
                                .frame(minHeight: 50)
                            Spacer()
                        }
                        Spacer()
                        
                    }.background(self.getCurTiming()?.timer == timerLabel ? Color.gray : Color.white)
                    Rectangle()
                        .fill(self.getColor(timerLabel: timerLabel))
                        .frame(width: 100, height: 20)
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .background(self.getColor(timerLabel: timerLabel))
                .onTapGesture(count: 2) {
                    self.timerLabelToEditName = timerLabel.name ?? ""
                    self.timerLabelToEditColor = Int(timerLabel.color)
                    self.timerLabelToEdit = timerLabel
                    self.showNewTimerLabelSubmitText = "Apply Edits to Timer"
                    self.showNewTimerLabel.toggle()
                }
                .onTapGesture(count: 1) {
                    self.getCurTiming().map{ cTiming in
                        cTiming.endTime = Date()
                    }
                    self.addTiming(startTime: Date(), timerLabel: self.getCurTiming()?.timer != timerLabel ? timerLabel : nil)
                }
            }
            .onDelete(perform: deleteTimerLabel)
            .onMove { sourceIndices, destinationIndex in
                sourceIndices.forEach { val in
                    if (val > destinationIndex) {
                        let upper = self.timerList[destinationIndex].position
                        let lower = destinationIndex == 0 ? upper - 1000 : self.timerList[destinationIndex - 1].position
                        self.timerList[val].position = (upper + lower) / 2
                        self.saveContext()
                    } else if (val < destinationIndex) {
                        let lower = self.timerList[destinationIndex - 1].position
                        let upper = destinationIndex == self.timerList.count ? lower + 1000 : self.timerList[destinationIndex].position
                        self.timerList[val].position = (upper + lower) / 2
                        self.saveContext()
                    }
                }
            }
        }
        .navigationBarTitle("Timers", displayMode: .inline)
        .navigationBarItems(
            leading: EditButton(),
            trailing: Button(action: {
                self.timerLabelToEditName = ""
                let options = (0...TimerLabelView.colorOptions.count).filter { num in
                    return !timerList.contains(where: { timerLabel in
                        return timerLabel.color == num
                    })
                }
                self.timerLabelToEditColor = options.first ?? 0
                self.showNewTimerLabelSubmitText = "Add Timer"
                self.showNewTimerLabel.toggle()
            }, label: {
                Image(systemName: "plus.circle")
            })
        )
        .sheet(isPresented: $showNewTimerLabel) {
            TimerLabelView(
                submitText: self.showNewTimerLabelSubmitText,
                name: self.timerLabelToEditName,
                color: self.timerLabelToEditColor
            ) { name, color in
                self.addTimerLabel(timerLabel: self.timerLabelToEdit, name: name, color: color)
                self.showNewTimerLabel = false
                self.timerLabelToEdit = nil
            }
        }
    }
    
    var timingListView: some View {
        List {
            ForEach(timingStartDays(timingList: timingList), id: \.self) { date in
                Section(header: Text(self.dayInDate(date: date))) {
                    TimingSectionView(dateStr: self.dayInDate(date: date), date: date)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Time History", displayMode: .inline)
    }
    
    var body: some View {
        TabView(selection: $selection){
            NavigationView {
                timerLabelListView
            }.navigationViewStyle(StackNavigationViewStyle())
            .font(.title)
            .tabItem {
                VStack {
                    Image(systemName: "stopwatch")
                    Text("Timers")
                }
            }
            .tag(0)
            
            
            
            TimingBoxView(currentDate: $logDate, scale: $logScale)
            .tabItem {
                VStack {
                    Image(systemName: "calendar")
                    Text("Timeline")
                }
            }
            .tag(1)
            
            NavigationView {
                timingListView
            }.navigationViewStyle(StackNavigationViewStyle())
            .font(.title)
            .tabItem {
                VStack {
                    Image(systemName: "book")
                    Text("Record")
                }
            }
            .tag(2)
            
            TimingStatsView(startTime: $statsStart, endTime: $statsEnd)
            .font(.title)
            .tabItem {
                VStack {
                    Image(systemName: "percent")
                    Text("Stats")
                }
            }
            .tag(3)
            
            Form {
                Section(header: Text("Gesture Instructions")) {
                    Text("Start or stop a timer by tapping it.")
                    Text("Edit a timer by double tapping it.")
                    Text("In Timeline, edit a timer by either (1) dragging an end up or down, or (2) double tapping it.")
                    Text("In Record, edit a timer by double tapping it.")
                }
                //Section(header: Text("Settings")) {
                //    Text("Coming soon!")
                // Ideas:
                // - Colourblind safe set of colours
                // - Export to file
                // - Choose first day of week
                // - Which style of History and Stats (add % info)
                //}
                
                Section(header: Text("Notes")) {
                    Text("For a convenient way to change your current timer, use the Today View widget, which is accessible from the home screen or lock screen by swiping right.")
                    Text("This app was created by Jonathan K. Kummerfeld as a project to learn Swift (and because I didn't like the UI of existing time tracking apps).")
                }
                
                Section(header: Text("Contact")) {
                    Link("https://jkk.name/timelog/", destination: URL(string: "https://jkk.name/timelog/")!)
                }
                Section(header: Text("Privacy Policy")) {
                    Link("http://jkk.name/timelog/privacy", destination: URL(string: "http://jkk.name/timelog/privacy")!)
                }
            }
            .font(.title)
            .tabItem {
                VStack {
                    Image(systemName: "dial")
                    Text("Settings")
                }
            }
            .tag(4)
        }
    }
    
    func addTimerLabel(timerLabel: PTimerLabel?, name: String, color: Int) {
        let newTimer = timerLabel ?? PTimerLabel(context: managedObjectContext)
        newTimer.name = name
        newTimer.color = Int16(color)
        if (timerLabel == nil) {
            newTimer.position = Double(1000 * (timerList.count + 1))
        }
        saveContext()
    }
    
    func addTiming(startTime: Date, timerLabel: PTimerLabel?) {
        let newTiming = PTiming(context: managedObjectContext)
        newTiming.startTime = startTime
        newTiming.timer = timerLabel
        saveContext()
    }
    
    func deleteTimerLabel(at offsets: IndexSet) {
      offsets.forEach { index in
        let timerLabel = self.timerList[index]
        self.managedObjectContext.delete(timerLabel)
      }
      saveContext()
    }
    
    func deleteTiming(at offsets: IndexSet) {
      offsets.forEach { index in
        self.timingList[index].timer = nil
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
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        return ContentView().environment(\.managedObjectContext, context)
    }
}
#endif

