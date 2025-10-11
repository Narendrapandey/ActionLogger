//
//  ScreenRecorderModifier.swift
//  ActionLogger
//
//  Created by Priyanka Pandey on 11/10/25.
//


import SwiftUI

public struct ScreenRecorderModifier: ViewModifier {
    var screenName: String
    
    public func body(content: Content) -> some View {
        content
            .onAppear {
                Task {
                    await RecordingManager.shared.logNavigation(screenName, title: screenName)
                }
            }
    }
}

public extension View {
    func recordScreen(_ name: String) -> some View {
        self.modifier(ScreenRecorderModifier(screenName: name))
    }
}
