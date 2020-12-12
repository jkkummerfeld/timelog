//
//  TimerLabelView.swift
//  JKK-Tracker
//
//  Created by Jonathan Kummerfeld on 15/5/20.
//  Copyright © 2020 Jonathan Kummerfeld. All rights reserved.
//

import SwiftUI

struct TimerLabelView: View {
    static let DefaultName = "New Timer"
    static let DefaultColor = 0
    static let colorOptions = [
        (name: "Light Blue", 201.0/360.0, 0.27, 0.89, false),
        (name: "Light Green", 92.0/360.0, 0.38, 0.87, false),
        (name: "Light Red", 1.0/360.0, 0.39, 0.98, false),
        (name: "Light Purple", 280.0/360.0, 0.17, 0.84, false),
        (name: "Light Orange", 30.0/360.0, 0.100, 1.00, false),
        (name: "Yellow", 60.0/360.0, 0.40, 1.00, false),
        (name: "Dark Blue", 204.0/360.0, 0.83, 0.71, true),
        (name: "Dark Green", 116.0/360.0, 0.73, 0.63, true),
        (name: "Dark Red", 359.0/360.0, 0.89, 0.89, true),
        (name: "Dark Orange", 34.0/360.0, 0.56, 0.99, true),
        (name: "Dark Purple", 269.0/360.0, 0.60, 0.60, true),
        (name: "Brown", 21.0/360.0, 0.77, 0.69, true),
    ]
    
    var submitText: String
    @State var name: String
    @State var color: Int
    let onComplete: (String, Int) -> Void
    
    func getColor(index: Int) -> Color {
        let (_, h, s, b, _) = TimerLabelView.colorOptions[index]
        return Color(hue: h, saturation: s, brightness: b)
    }
    
    var body: some View {
        // Compare with example code
        NavigationView {
            Form {
                Section(header: Text("Label")) {
                    TextField("Timer Name", text: $name)
                }
            
                VStack {
                    Text("Color").bold()
                    Picker("Color", selection: $color) {
                        ForEach(0..<TimerLabelView.colorOptions.count) { index in
                            HStack {
                                Text(TimerLabelView.colorOptions[index].name).frame(width:200)
                                Spacer()
                                Circle().fill(self.getColor(index: index))
                            }
                        }
                    }
                    .labelsHidden()
                }
                    
                Section {
                  Button(action: addTimerLabelAction) {
                    Text(submitText)
                  }
                }
            }
            .navigationBarTitle(Text(submitText), displayMode: .inline)
        }
    }
    
    private func addTimerLabelAction() {
        onComplete(
            name.isEmpty ? TimerLabelView.DefaultName : name,
            color
        )
    }
}
