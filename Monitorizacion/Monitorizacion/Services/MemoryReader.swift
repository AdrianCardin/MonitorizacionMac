//
//  MemoryReader.swift
//  Monitorizacion
//
//  Memoria física, comprimida y de intercambio, con los mismos criterios que
//  usa Monitor de Actividad.
//

import Foundation

nonisolated final class MemoryReader {

    private let pageSize: UInt64 = {
        var size: vm_size_t = 0
        host_page_size(mach_host_self(), &size)
        return UInt64(size)
    }()

    func read() -> MemoryMetrics {
        var metrics = MemoryMetrics()
        metrics.total = ProcessInfo.processInfo.physicalMemory
        metrics.pressure = Self.pressure()

        if let stats = vmStatistics() {
            let bytes = { (pages: UInt32) in UInt64(pages) * self.pageSize }
            metrics.wired = bytes(stats.wire_count)
            metrics.compressed = UInt64(stats.compressor_page_count) * pageSize
            // Resta saturada: en teoría `purgeable` es un subconjunto de
            // `internal`, pero las dos cifras no se leen de forma atómica.
            metrics.app = bytes(stats.internal_page_count) - min(bytes(stats.purgeable_count), bytes(stats.internal_page_count))
            metrics.cached = bytes(stats.external_page_count) + bytes(stats.purgeable_count)
            // "Memoria usada" = apps + residente del sistema + comprimida.
            metrics.used = metrics.app + metrics.wired + metrics.compressed
        }

        if let swap = Sysctl.value("vm.swapusage", as: xsw_usage.self) {
            metrics.swapTotal = swap.xsu_total
            metrics.swapUsed = swap.xsu_used
        }
        return metrics
    }

    private func vmStatistics() -> vm_statistics64? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        return result == KERN_SUCCESS ? stats : nil
    }

    /// El kernel publica el nivel de presión directamente; es la misma señal que
    /// dispara la compresión y el intercambio.
    private static func pressure() -> MemoryPressure {
        guard let raw = Sysctl.integer("kern.memorystatus_vm_pressure_level"),
              let level = MemoryPressure(rawValue: raw) else { return .normal }
        return level
    }
}
