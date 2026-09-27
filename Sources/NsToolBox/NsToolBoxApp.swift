import SwiftUI
import ToolboxUI

@main
struct NsToolBoxApp: App {
    var body: some Scene {
        WindowGroup("NsToolBox") {
            ToolboxRootView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1180, height: 780)
    }
}
