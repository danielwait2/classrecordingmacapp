//
//  TranscriptionServiceProtocol.swift
//  Sponge
//
//  Protocol for transcription services to allow version-agnostic implementation
//

import Foundation

protocol TranscriptionServiceProtocol: AnyObject {
    var transcribedText: String { get }
    var isTranscribing: Bool { get }
    var error: String? { get }

    func startTranscribing()
    func pauseTranscribing()
    func resumeTranscribing()
    func stopTranscribing()
    func reset()
}
