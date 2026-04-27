//
//  AudioCueManager.swift
//  toilet-assist-yolo
//
//  Created by Katharina Grünwald on 27.04.26.
//

import AVFoundation

final class AudioCueManager {
    
    // TOn abspielen: https://developer.apple.com/documentation/avfaudio/avaudioplayer
    //Audio Tutorial:,https://www.kodeco.com/2434-audio-tutorial-for-ios-file-and-data-formats-2014-edition
  

    private var player: AVAudioPlayer?
    private var lastBeepTime = Date.distantPast

    func update(direction: Float, closeness: Float) {
        let interval = beepInterval(closeness: closeness)
        let now = Date()

        guard now.timeIntervalSince(lastBeepTime) >= interval else {
            return
        }

        lastBeepTime = now
        playBeep(direction: direction, closeness: closeness)
    }

    func stop() {
        player?.stop()
    }

    private func beepInterval(closeness: Float) -> TimeInterval {
        if closeness > 0.80 {
            return 0.25
        } else if closeness > 0.55 {
            return 0.45
        } else if closeness > 0.30 {
            return 0.75
        } else {
            return 1.10
        }
    }

    private func playBeep(direction: Float, closeness: Float) {
        let frequency: Double = closeness > 0.55 ? 880 : 660
        let duration: Double = 0.08
        let sampleRate: Double = 44100

        let frameCount = Int(sampleRate * duration)
        var samples = [Int16](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            let sine = sin(2.0 * Double.pi * frequency * t)
            samples[i] = Int16(sine * 8000)
        }

        let data = Data(bytes: samples, count: samples.count * MemoryLayout<Int16>.size)

        do {
            player = try AVAudioPlayer(data: wavData(fromPCM: data, sampleRate: Int(sampleRate)))
            // rechts und links über Richtung: https://developer.apple.com/documentation/avfaudio/avaudioplayer/pan
            player?.pan = max(-1.0, min(1.0, direction))
            player?.volume = 0.7
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("❌ Beep konnte nicht abgespielt werden: \(error)")
        }
    }

    private func wavData(fromPCM pcmData: Data, sampleRate: Int) -> Data {
        var data = Data()

        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * bitsPerSample / 8
        let subchunk2Size = UInt32(pcmData.count)
        let chunkSize = UInt32(36) + subchunk2Size

        data.append("RIFF".data(using: .ascii)!)
        data.append(chunkSize.littleEndianData)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        data.append(UInt32(16).littleEndianData)
        data.append(UInt16(1).littleEndianData)
        data.append(channels.littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(byteRate.littleEndianData)
        data.append(blockAlign.littleEndianData)
        data.append(bitsPerSample.littleEndianData)
        data.append("data".data(using: .ascii)!)
        data.append(subchunk2Size.littleEndianData)
        data.append(pcmData)

        return data
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
