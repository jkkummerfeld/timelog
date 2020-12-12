//
//  TodayViewController.swift
//  Time Tracking Widget
//
//  Created by Jonathan Kummerfeld on 6/9/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import UIKit
import NotificationCenter
import SwiftUI
import CoreData

class NSCustomPersistentContainer: NSPersistentContainer {
    override open class func defaultDirectoryURL() -> URL {
        var storeURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.name.jkk.TimeLog")
        storeURL = storeURL?.appendingPathComponent("TimeLog")
        return storeURL!
    }
}

struct LocalTimer: Identifiable, Hashable {
    let id: Int
    
    let color: Color
    let textColor: Color
    let name: String
    
    let timerLabel: PTimerLabel
}

class TodayViewController: UIViewController, NCWidgetProviding {

    struct WidgetView : View {
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
        
        func getColor(timerLabel: PTimerLabel?) -> Color {
            if let color = timerLabel?.color {
                let (_, h, s, b, _) = TimerLabelView.colorOptions[Int(color)]
                return Color(hue: h, saturation: s, brightness: b)
            } else {
                return Color.white
            }
        }
        func getTextColor(timerLabel: PTimerLabel?) -> Color {
            if let color = timerLabel?.color {
                let (_, _, _, _, useWhite) = TimerLabelView.colorOptions[Int(color)]
                if useWhite {
                    return Color.white
                } else {
                    return Color.black
                }
            } else {
                return Color.black
            }
        }
        
        func getTimerRows(width: CGFloat, boxSize: Double, height: CGFloat) -> [[LocalTimer]] {
            var ans: [[LocalTimer]] = [[]]
            var total = 0
            
            for timer in self.timerList {
                let ntimer = LocalTimer(
                    id: total,
                    color: self.getColor(timerLabel: timer),
                    textColor: self.getTextColor(timerLabel: timer),
                    name: timer.name ?? "",
                    timerLabel: timer)
                total += 1
                if (Double((ans.last!.count + 1)) * boxSize >= Double(width)) {
                    if (Double((ans.count + 1)) * boxSize >= Double(height)) {
                        break
                    }
                    ans.append([LocalTimer]())
                }
                ans[ans.count - 1].append(ntimer)
            }
            
            return ans;
        }
        
        func getCurTiming() -> PTiming? {
            if (timingList.count > 0) {
                return timingList[0]
            } else {
                return nil
            }
        }

        func addTiming(startTime: Date, timerLabel: PTimerLabel?) {
            let newTiming = PTiming(context: managedObjectContext)
            newTiming.startTime = startTime
            newTiming.timer = timerLabel
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
            GeometryReader { geometry in
                Spacer()
                VStack {
                    ForEach(self.getTimerRows(width: geometry.size.width, boxSize: 70, height: geometry.size.height), id: \.self) { timerRow in
                        HStack(spacing: 4) {
                            ForEach(timerRow, id: \.id) { timer in
                                ZStack {
                                    Rectangle()
                                        .fill(timer.color)
                                        .frame(width: 70, height: 70)
                                    Text(timer.name)
                                        .foregroundColor(timer.textColor)
                                        .frame(width: 70, height: 70)
                                }
                                .border(self.getCurTiming()?.timer != timer.timerLabel ? Color.white : Color.black)
                                .onTapGesture(count: 2) {
                                    // Apparently required in order to get single tap to work
                                }
                                .onTapGesture(count: 1) {
                                    self.getCurTiming().map{ cTiming in
                                        cTiming.endTime = Date()
                                    }
                                    self.addTiming(startTime: Date(), timerLabel: self.getCurTiming()?.timer != timer.timerLabel ? timer.timerLabel : nil)
                                }
                            }
                        }
                    }
                }
                Spacer()
            }
        }
    }
    
    private var coreDataManager: PersistentHistoryObserver? = nil
    
    @IBSegueAction func addSwiftUIHost(_ coder: NSCoder) -> UIViewController? {
        let hostingController = UIHostingController(coder: coder, rootView: WidgetView().environment(\.managedObjectContext, persistentContainer.viewContext))
        persistentContainer.viewContext.name = "today_context"
        persistentContainer.viewContext.transactionAuthor = "today_extension"
        
        coreDataManager = PersistentHistoryObserver(target: .todayExtension, persistentContainer: persistentContainer, userDefaults: UserDefaults.standard)
        coreDataManager?.startObserving()
        
        // Give a clear background
        //hostingController!.view.backgroundColor = UIColor.clear
        return hostingController
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        self.extensionContext?.widgetLargestAvailableDisplayMode = .expanded
    }
    
    func widgetActiveDisplayModeDidChange(_ activeDisplayMode: NCWidgetDisplayMode, withMaximumSize maxSize: CGSize) {
        if activeDisplayMode == .compact {
            self.preferredContentSize = maxSize
        } else if activeDisplayMode == .expanded {
            self.preferredContentSize = CGSize(width: maxSize.width, height: 150)
        }
    }
        
    func widgetPerformUpdate(completionHandler: (@escaping (NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
    
    // MARK: - Core Data stack
    
    var persistentContainer: NSPersistentContainer = {
        let container = NSCustomPersistentContainer(name: "TimeLog")
        if let description = container.persistentStoreDescriptions.first {
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()

    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
}
