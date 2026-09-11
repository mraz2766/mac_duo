import Foundation
import LidAngleKit

/// Diagnostic tool for the lid angle sensor.
///
///     lidprobe            stream the angle until interrupted
///     lidprobe rate       measure how often the hardware value changes
///     lidprobe record 60  every read for 60 s, with a wall clock stamp
///     lidprobe watch 15   look for the angle rising while the lid closes

let sensor = LidAngleSensor()

guard sensor.isAvailable, let resolution = sensor.resolution else {
    FileHandle.standardError.write(Data("这台 Mac 上没有找到屏幕开合角度传感器\n".utf8))
    exit(1)
}

print("已找到传感器：\(resolution.describedName)")

let mode = CommandLine.arguments.dropFirst().first ?? "stream"

switch mode {
case "watch":
    let seconds = Double(CommandLine.arguments.dropFirst(2).first ?? "15") ?? 15
    print("将以 200 Hz 记录 \(Int(seconds)) 秒。请快速合上屏幕并短暂停留，然后重新打开。")
    let start = Date()
    var samples: [(t: Double, angle: Double)] = []
    var failures = 0
    while Date().timeIntervalSince(start) < seconds {
        let t = Date().timeIntervalSince(start)
        if let angle = sensor.angle() { samples.append((t, angle)) } else { failures += 1 }
        usleep(5000)
    }
    print("读取次数：\(samples.count)，失败次数：\(failures)")
    guard let lowest = samples.min(by: { $0.angle < $1.angle }) else { break }
    print(String(format: "最小角度 %.2f，出现于 %.2f 秒", lowest.angle, lowest.t))

    // Every value change: time, angle, step.
    var changes: [(t: Double, angle: Double, step: Double)] = []
    var previous = samples[0].angle
    for sample in samples where sample.angle != previous {
        changes.append((sample.t, sample.angle, sample.angle - previous))
        previous = sample.angle
    }
    print("数值变化次数：\(changes.count)")
    let rises = changes.filter { $0.step > 0.5 }
    print("大于 0.5° 的上升次数：\(rises.count)")
    for rise in rises.prefix(40) {
        print(String(format: "  时间 %6.3f 秒  角度 %7.2f  变化 %+6.2f", rise.t, rise.angle, rise.step))
    }
    // Largest gap between successive changes, to show the hardware rate.
    var widest = 0.0
    for index in 1..<max(1, changes.count) {
        widest = max(widest, changes[index].t - changes[index - 1].t)
    }
    print(String(format: "数值变化的最长间隔：%.3f 秒", widest))

case "record":
    // Every read with a wall clock stamp, so the trace lines up with the
    // app's own log.
    let seconds = Double(CommandLine.arguments.dropFirst(2).first ?? "30") ?? 30
    let clock = DateFormatter()
    clock.dateFormat = "HH:mm:ss.SSS"
    print("将记录 \(Int(seconds)) 秒，请立即重现操作。")
    fflush(stdout)

    // Written as it goes, so an interrupted run still leaves its trace.
    var reads = 0
    var failures = 0
    let start = Date()
    while Date().timeIntervalSince(start) < seconds {
        let stamp = clock.string(from: Date())
        if let angle = sensor.angle() {
            reads += 1
            print(stamp + " " + String(format: "%.2f", angle))
        } else {
            failures += 1
            let trace = sensor.lastRead
            let hex = trace.bytes.map { String(format: "%02x", $0) }.joined(separator: " ")
            let rejected = trace.rejectedDegrees.map { String(format: "%.2f", $0) } ?? "-"
            print(
                stamp + " 失败，状态码 0x" + String(UInt32(bitPattern: trace.status), radix: 16)
                    + "，长度 \(trace.length) 字节 [\(hex)]，异常值 \(rejected)"
            )
        }
        if (reads + failures) % 30 == 0 { fflush(stdout) }
        // 60 Hz, six times the hardware rate.
        usleep(14000)
    }
    print("# 读取次数：\(reads)，失败次数：\(failures)")

case "rate":
    print("将测量 8 秒——请保持屏幕静止，程序会根据传感器噪声计算刷新率")
    let start = Date()
    var changeTimes: [TimeInterval] = []
    var lastValue = -999.0
    var reads = 0
    while Date().timeIntervalSince(start) < 8 {
        if let angle = sensor.angle() {
            reads += 1
            if angle != lastValue {
                changeTimes.append(Date().timeIntervalSince(start))
                lastValue = angle
            }
        }
        usleep(4000)
    }
    var gaps: [TimeInterval] = []
    for index in 1..<max(1, changeTimes.count) {
        gaps.append(changeTimes[index] - changeTimes[index - 1])
    }
    print("读取次数：\(reads)   数值变化次数：\(changeTimes.count)")
    if gaps.isEmpty {
        print("数值没有变化，无法计算刷新率")
    } else {
        let sorted = gaps.sorted()
        let median = sorted[sorted.count / 2]
        print(String(format: "变化间隔：最小 %.1f 毫秒，中位数 %.1f 毫秒", sorted[0] * 1000, median * 1000))
        print(String(format: "有效刷新率：%.1f Hz", 1 / median))
    }

default:
    print("正以 30 Hz 输出，按 Control-C 停止")
    while true {
        if let angle = sensor.angle() {
            print(String(format: "%7.2f°", angle))
        } else {
            print("读取失败")
        }
        fflush(stdout)
        usleep(33_333)
    }
}
