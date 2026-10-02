//
//  CPUReader.swift
//  Monitorizacion
//
//  Uso de CPU a partir de los contadores de ticks del kernel
//  (`host_processor_info`). Son acumulativos, así que el uso se calcula
//  comparando dos lecturas consecutivas.
//

import Foundation

nonisolated final class CPUReader {

    /// Ticks por núcleo de la lectura anterior.
    private var previous: [[UInt32]] = []
    private let clusters = HardwareInfo.clusters()

    func read() -> CPUMetrics {
        var metrics = CPUMetrics()
        metrics.loadAverage = Self.loadAverage()

        let current = Self.ticks()
        defer { previous = current }
        guard !current.isEmpty, previous.count == current.count else { return metrics }

        var totalBusy = 0.0, totalTicks = 0.0, totalUser = 0.0, totalSystem = 0.0
        var perCore: [Double] = []
        perCore.reserveCapacity(current.count)

        for core in current.indices {
            // Resta sin comprobación de desbordamiento: los contadores son
            // acumulativos de 32 bits y dan la vuelta cada cierto tiempo.
            let user = Double(current[core][Int(CPU_STATE_USER)] &- previous[core][Int(CPU_STATE_USER)])
            let system = Double(current[core][Int(CPU_STATE_SYSTEM)] &- previous[core][Int(CPU_STATE_SYSTEM)])
            let idle = Double(current[core][Int(CPU_STATE_IDLE)] &- previous[core][Int(CPU_STATE_IDLE)])
            let nice = Double(current[core][Int(CPU_STATE_NICE)] &- previous[core][Int(CPU_STATE_NICE)])

            let ticks = user + system + idle + nice
            perCore.append(ticks > 0 ? (ticks - idle) / ticks : 0)

            totalTicks += ticks
            totalBusy += ticks - idle
            totalUser += user + nice
            totalSystem += system
        }

        metrics.perCore = perCore
        if totalTicks > 0 {
            metrics.total = totalBusy / totalTicks
            metrics.user = totalUser / totalTicks
            metrics.system = totalSystem / totalTicks
        }
        metrics.clusters = Self.split(perCore, into: clusters)
        return metrics
    }

    /// Reparte el uso por núcleo entre los clusters, en orden de nivel.
    private static func split(_ perCore: [Double], into clusters: [ClusterUsage]) -> [ClusterUsage] {
        var start = 0
        return clusters.map { cluster in
            var updated = cluster
            let end = min(start + cluster.coreCount, perCore.count)
            if start < end {
                let slice = perCore[start..<end]
                updated.usage = slice.reduce(0, +) / Double(slice.count)
            }
            start = end
            return updated
        }
    }

    /// Ticks acumulados por núcleo y por estado (user, system, idle, nice).
    private static func ticks() -> [[UInt32]] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                 &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        let states = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { core in
            (0..<states).map { UInt32(bitPattern: info[core * states + $0]) }
        }
    }

    private static func loadAverage() -> [Double] {
        var averages = [Double](repeating: 0, count: 3)
        guard getloadavg(&averages, 3) == 3 else { return [] }
        return averages
    }
}
