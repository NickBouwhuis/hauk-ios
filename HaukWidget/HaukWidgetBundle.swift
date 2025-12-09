//
//  HaukWidgetBundle.swift
//  HaukWidget
//
//  Created by Nick Bouwhuis on 05/12/2025.
//

import WidgetKit
import SwiftUI

@main
struct HaukWidgetBundle: WidgetBundle {
    var body: some Widget {
        HaukWidget()
        HaukWidgetControl()
        HaukWidgetLiveActivity()
    }
}
