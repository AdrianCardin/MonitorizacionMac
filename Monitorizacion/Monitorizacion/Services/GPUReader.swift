//
//  GPUReader.swift
//  Monitorizacion
//
//  Utilización del GPU. El driver publica sus contadores como propiedades del
//  registro de IOKit (IOAccelerator -> PerformanceStatistics), que es API
//  pública: basta con leer el registro, no hace falta root.
//

import Foundation
import IOKit
import Metal

nonisolated final class GPUReader {

    private let device = MTLCreateSystemDefaultDevice()

    func read() -> GPUMetrics {
        var metrics = GPUMetrics()
        metrics.name = device?.name ?? "GPU"
        metrics.memoryRecommendedMax = UInt64(device?.recommendedMaxWorkingSetSize ?? 0)

        guard let statistics = performanceStatistics() else { return metrics }
        metrics.available = true

        func percent(_ key: String) -> Double {
            guard let value = statistics[key] as? NSNumber else { return 0 }
            return min(max(value.doubleValue / 100, 0), 1)
        }
        func bytes(_ key: String) -> UInt64 {
            (statistics[key] as? NSNumber)?.uint64Value ?? 0
        }

        metrics.utilization = percent("Device Utilization %")
        metrics.rendererUtilization = percent("Renderer Utilization %")
        metrics.tilerUtilization = percent("Tiler Utilization %")
        metrics.memoryInUse = bytes("In use system memory")
        metrics.memoryAllocated = bytes("Alloc system memory")
        return metrics
    }

    /// Recorre los aceleradores y devuelve las estadísticas del primero que las
    /// publique (en los Apple Silicon hay un único GPU integrado).
    private func performanceStatistics() -> [String: Any]? {
        guard let matching = IOServiceMatching("IOAccelerator") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let properties = unmanaged?.takeRetainedValue() as? [String: Any],
                  let statistics = properties["PerformanceStatistics"] as? [String: Any] else { continue }
            return statistics
        }
        return nil
    }
}
