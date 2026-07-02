import SwiftUI
import AppKit

enum Theme {
    static let windowBG  = Color(red: 0.173, green: 0.173, blue: 0.180)
    static let sidebarBG = Color(red: 0.145, green: 0.145, blue: 0.149)
    static let panelBG   = Color(red: 0.227, green: 0.227, blue: 0.235)
    static let cardBG    = Color(red: 0.227, green: 0.227, blue: 0.235)
    static let cardHover = Color(red: 0.259, green: 0.259, blue: 0.267)
    static let logBG     = Color(red: 0.110, green: 0.110, blue: 0.118)
    static let statusBar = Color(red: 0.118, green: 0.118, blue: 0.125)

    static let primaryText   = Color.white.opacity(0.90)
    static let secondaryText = Color.white.opacity(0.65)
    static let tertiaryText  = Color.white.opacity(0.35)
    static let mutedText     = Color.white.opacity(0.25)

    static let accent   = Color(red: 0.388, green: 0.702, blue: 0.929)
    static let blueLink = Color(red: 0.039, green: 0.518, blue: 1.000)

    static let green   = Color(red: 0.188, green: 0.820, blue: 0.345)
    static let red     = Color(red: 1.000, green: 0.271, blue: 0.227)
    static let orange  = Color(red: 1.000, green: 0.584, blue: 0.000)
    static let yellow  = Color(red: 1.000, green: 0.839, blue: 0.039)
    static let gray    = Color(red: 0.388, green: 0.388, blue: 0.400)

    static let separator   = Color.white.opacity(0.06)
    static let hairline    = Color.white.opacity(0.07)
    static let inputBorder = Color.white.opacity(0.10)
    static let windowShadow = Color.black.opacity(0.70)
}
