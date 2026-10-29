import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // Room for the task grid and a few weeks of the chart.
    self.setContentSize(NSSize(width: 1440, height: 860))
    self.contentMinSize = NSSize(width: 1000, height: 560)
    self.center()
    self.title = "Ganttly"

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
