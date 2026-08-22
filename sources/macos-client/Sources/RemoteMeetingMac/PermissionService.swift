import AVFoundation
import CoreGraphics
import Foundation

enum PermissionService {
    static func microphoneStatusText() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            "已授权"
        case .notDetermined:
            "未询问"
        case .denied:
            "已拒绝"
        case .restricted:
            "受限制"
        @unknown default:
            "未知"
        }
    }

    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }
}
