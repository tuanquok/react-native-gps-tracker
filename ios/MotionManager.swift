import CoreMotion
import Foundation

enum MotionState: String {
  case stationary
  case walking
  case running
  case cycling
  case automotive
  case moving
  case unknown

  var isMoving: Bool {
    switch self {
    case .walking, .running, .cycling, .automotive, .moving:
      return true
    case .stationary, .unknown:
      return false
    }
  }
}

protocol MotionManagerDelegate: AnyObject {
  func motionManager(_ manager: MotionManager, didChangeState state: MotionState)
}

@objcMembers
public class MotionManager: NSObject {
  public static let shared = MotionManager()

  weak var delegate: MotionManagerDelegate?

  private let activityManager = CMMotionActivityManager()
  private var currentState: MotionState = .unknown
  private var isMonitoring = false

  public func startMonitoring() {
    guard CMMotionActivityManager.isActivityAvailable() else {
      print("GpsTracker motion activity unavailable")
      return
    }

    guard !isMonitoring else {
      return
    }

    isMonitoring = true
    activityManager.startActivityUpdates(to: .main) { [weak self] activity in
      guard let self, let activity else {
        return
      }

      let nextState = self.resolveState(from: activity)
      self.updateState(nextState)
    }
  }

  public func stopMonitoring() {
    guard isMonitoring else {
      return
    }

    isMonitoring = false
    activityManager.stopActivityUpdates()
    currentState = .unknown
  }

  private func resolveState(from activity: CMMotionActivity) -> MotionState {
    if activity.stationary {
      return .stationary
    }

    if activity.automotive {
      return .automotive
    }

    if activity.cycling {
      return .cycling
    }

    if activity.running {
      return .running
    }

    if activity.walking {
      return .walking
    }

    return activity.confidence == .high ? .moving : .unknown
  }

  private func updateState(_ nextState: MotionState) {
    guard nextState != currentState else {
      return
    }

    currentState = nextState
    print("GpsTracker motion state: \(nextState.rawValue)")
    delegate?.motionManager(self, didChangeState: nextState)
  }
}
