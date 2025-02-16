//
//  ContentView.swift
//  WorkoutVoiceTrackerWatchOS Watch App
//

import SwiftUI
import CoreData
import AVFoundation


struct ContentView: View {
    let viewContext: NSManagedObjectContext  // ✅ Injected manually

    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioURL: URL?
    @State private var audioMeterValues: [Float] = Array(repeating: 0, count: 50) // ✅ Increased buffer for smoother waveform
    @State private var recordingStartTime: Date? = nil
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer? = nil
    @State private var showCheckmark = false  // ✅ Tracks when to show the checkmark
    
    

    var body: some View {
        VStack {
            Spacer()

            // ✅ Live Waveform Behind the Button with Opacity Effect
            ZStack {
                if isRecording {
                    DynamicWaveformView(audioMeterValues: audioMeterValues)
                        .frame(height: 100)
                        .opacity(1.0) // ✅ Transparent to blend with the button
                        .scaleEffect(1.3)
                        .offset(y: -6)  // ✅ Adjusted opacity for better pass-through visibility
                        .transition(.opacity)
                        .animation(.easeInOut, value: isRecording)
                }

                // ✅ Transparent Record/Stop Button with Text Overlay
                Button(action: {
                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 5) // ✅ Semi-transparent border
                            .background(Circle().fill(showCheckmark ? Color.green.opacity(1.0) : Color.red.opacity(1.0))) // ✅ Turns Green on Success
                            .frame(width: 100, height: 100)

                        VStack {
                            if showCheckmark {
                                Image(systemName: "checkmark")  // ✅ Display Checkmark When Logging is Confirmed
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white)
                                    .font(.system(size: 40, weight: .heavy)) // ✅ Make checkmark bold
                                    .transition(.scale)
                            } else if isRecording {
                                Image(systemName: "stop.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)
                                    .foregroundColor(.white)
                            } else {
                                Text(" ") // ✅ Keeps size consistent
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.bottom, 10)
                .buttonStyle(PlainButtonStyle()) // ✅ Removes Gray Background Button
            }

            // ✅ Always Keep Space for Stopwatch Timer to Prevent UI Shift
            Text(isRecording ? formattedTime(elapsedTime) : "00:00.00") // ✅ Ensures space is always there
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .transition(.opacity)
                .animation(.easeInOut, value: isRecording)
                .padding(.top, 10) // ✅ Keeps spacing consistent

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // ✅ Keeps everything centered
        .onAppear {
            refreshData()
        }
    }

    // ✅ Start Audio Recording & Timer
    private func startRecording() {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    self.audioMeterValues = Array(repeating: 0, count: 50) // ✅ Reset waveform before recording starts
                    self.beginRecording()
                } else {
                    print("❌ Microphone access denied")
                }
            }
        }
    }

    private func beginRecording() {
       
    #if os(watchOS)
        let deviceType = "watchOS"
        let deviceModel = WKInterfaceDevice.current().localizedModel.replacingOccurrences(of: " ", with: "_")
    #elseif os(iOS)
        let deviceType = "iOS"
        let deviceModel = UIDevice.current.name.replacingOccurrences(of: " ", with: "_") // ✅ More accurate than `.model`
    #else
        let deviceType = "unknown"
        let deviceModel = "unknown_device"
    #endif
        
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let uniqueID = UUID().uuidString.prefix(8) // ✅ Shorten UUID to 8 chars for cleaner filenames
        let filename = "\(timestamp)_\(deviceType)_\(deviceModel)_\(uniqueID).m4a"// ✅ New file name format

        let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filePath = documentDir.appendingPathComponent(filename)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [])
            try session.setActive(true)

            try session.setMode(.voiceChat) // Helps prioritize built-in mic over Bluetooth

            audioRecorder = try AVAudioRecorder(url: filePath, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()

            isRecording = true
            audioURL = filePath
            startUpdatingAudioLevels()
            startStopwatch()

            print("🎤 Recording started using system-preferred mic: \(filePath)")
        } catch {
            print("❌ Failed to start recording: \(error.localizedDescription)")
        }
    }

    // ✅ Stop Recording & Sync Pending Files
    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        stopStopwatch() // ✅ Stop timer
        print("✅ Recording saved: \(audioURL?.absoluteString ?? "Unknown location")")

        // ✅ Sync all pending files before logging the workout
        syncAllPendingFiles()

        // ✅ Save the latest audio file to iCloud
        if let fileURL = audioURL {
            saveToiCloud(fileURL: fileURL)
        } else {
            print("❌ No audio file found to save.")
        }

        // ✅ Now log the workout after ensuring sync has been attempted
        logWorkout()

        // ✅ Show checkmark confirmation
        showCheckmark = true
        WKInterfaceDevice.current().play(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCheckmark = false
        }
    }

    // ✅ Function to Sync All Pending Files
    private func syncAllPendingFiles() {
        DispatchQueue.global(qos: .background).async {
            let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentDir, includingPropertiesForKeys: nil)

                for fileURL in files {
                    self.saveToiCloud(fileURL: fileURL)
                }

                DispatchQueue.main.async {
                    print("✅ Sync complete. UI is responsive.")
                }
            } catch {
                DispatchQueue.main.async {
                    print("❌ Failed to fetch local files for syncing: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // ✅ Save Audio File to iCloud Drive
    private func saveToiCloud(fileURL: URL) {
        guard let iCloudDirectory = FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents/Copper") else {
            print("❌ iCloud Drive not available.")
            return
        }

        // ✅ Get the base filename
        let originalFileName = fileURL.lastPathComponent
        var destinationURL = iCloudDirectory.appendingPathComponent(originalFileName)

        do {
            if !FileManager.default.fileExists(atPath: iCloudDirectory.path) {
                try FileManager.default.createDirectory(at: iCloudDirectory, withIntermediateDirectories: true)
                print("📂 Created iCloud directory: \(iCloudDirectory.path)") // ✅ Log folder creation
            } else {
                print("📁 iCloud directory already exists: \(iCloudDirectory.path)") // ✅ Log if already exists
            }

            // ✅ Check if a file with the same name exists
            var counter = 1
            while FileManager.default.fileExists(atPath: destinationURL.path) {
                let newFileName = originalFileName.replacingOccurrences(of: ".m4a", with: "_\(counter).m4a")
                destinationURL = iCloudDirectory.appendingPathComponent(newFileName)
                counter += 1
            }

            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
            print("✅ Audio file successfully saved to iCloud: \(destinationURL.path)") // ✅ Log file copy success

            // ✅ File successfully saved to iCloud, delete local copy
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("🗑️ Local file deleted after successful iCloud sync: \(fileURL.path)") // ✅ Log file deletion success
            } catch {
                print("❌ Failed to delete local file: \(error.localizedDescription)")
            }

        } catch {
            print("❌ Failed to save audio to iCloud: \(error.localizedDescription)")
        }
    }

    // ✅ Update Waveform in Real-Time
    private func startUpdatingAudioLevels() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard let recorder = audioRecorder, recorder.isRecording else {
                timer.invalidate()
                return
            }

            recorder.updateMeters()
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0, min(1, (level + 60) / 60)) // Normalize to 0-1 range
            audioMeterValues.append(normalizedLevel)
            if audioMeterValues.count > 50 {
                audioMeterValues.removeFirst()
            }
        }
    }

    // ✅ Start Stopwatch Timer (With Milliseconds)
    private func startStopwatch() {
        recordingStartTime = Date()
        elapsedTime = 0

        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in // ✅ Updates every 10ms
            if let startTime = recordingStartTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    // ✅ Stop Stopwatch Timer
    private func stopStopwatch() {
        timer?.invalidate()
        timer = nil
        recordingStartTime = nil
        elapsedTime = 0
    }

    // ✅ Format Stopwatch Time with Milliseconds
    private func formattedTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100) // ✅ Capture milliseconds
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }

    // ✅ Log Exercise After Recording
    private func logWorkout() {
        let newWorkout = Workout(context: viewContext)
        newWorkout.id = UUID()
        newWorkout.date = Date()
        newWorkout.duration = Double(elapsedTime) // ✅ Store duration
        newWorkout.source = "Watch"

        do {
            try viewContext.save()
            print("✅ Workout logged successfully.")
        } catch {
            print("❌ Failed to log workout: \(error.localizedDescription)")
        }
    }

    // ✅ Refresh data function (unchanged)
    private func refreshData() {
        let request: NSFetchRequest<Workout> = Workout.fetchRequest()
        do {
            let workouts = try viewContext.fetch(request)
            print("🔄 Fetched \(workouts.count) workouts.")
        } catch {
            print("❌ Error fetching workouts: \(error.localizedDescription)")
        }
    }
}

// ✅ Dynamic Live Waveform Using Real Audio Input
struct DynamicWaveformView: View {
    let audioMeterValues: [Float]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(audioMeterValues, id: \.self) { value in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.opacity(1.0)) // ✅ Changed to full opacity for a clearer waveform
                    .frame(width: 1, height: CGFloat(value * 50) + 15)
            }
        }
        .frame(width: 140, height: 100)
    }
}
