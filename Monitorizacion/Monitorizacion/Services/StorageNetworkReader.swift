//
//  StorageNetworkReader.swift
//  Monitorizacion
//
//  Espacio y actividad del disco, y tráfico de red. Los contadores de bytes son
//  acumulativos: las tasas se calculan por diferencia entre dos lecturas.
//
//  Los contadores pueden retroceder: los de red son de 32 bits por interfaz y
//  dan la vuelta cada 4 GB, y el total cambia cuando se conecta o desconecta un
//  disco o una interfaz. En ese caso se devuelve 0 para esa muestra, en lugar de
//  una resta envolvente que produciría una tasa absurda.
//

import Foundation
import IOKit

/// Diferencia entre dos contadores acumulativos. Devuelve 0 si el contador ha
/// retrocedido, que es lo que ocurre al dar la vuelta o al cambiar de hardware.
private func rate(_ current: UInt64, _ previous: UInt64, over elapsed: TimeInterval) -> Double {
    guard elapsed > 0, current >= previous else { return 0 }
    return Double(current - previous) / elapsed
}

nonisolated final class StorageNetworkReader {

    private var previousDisk: (read: UInt64, written: UInt64, date: Date)?
    private var previousNetwork: (received: UInt64, sent: UInt64, date: Date)?

    // MARK: Disco

    func readStorage() -> StorageMetrics {
        var metrics = StorageMetrics()

        if let values = try? URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            metrics.total = UInt64(values.volumeTotalCapacity ?? 0)
            metrics.free = UInt64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        }

        let counters = diskCounters()
        let now = Date()
        if let previous = previousDisk {
            let elapsed = now.timeIntervalSince(previous.date)
            metrics.readRate = rate(counters.read, previous.read, over: elapsed)
            metrics.writeRate = rate(counters.written, previous.written, over: elapsed)
        }
        previousDisk = (counters.read, counters.written, now)
        return metrics
    }

    /// Suma los bytes leídos y escritos por todos los discos de bloque.
    private func diskCounters() -> (read: UInt64, written: UInt64) {
        var read: UInt64 = 0
        var written: UInt64 = 0
        guard let matching = IOServiceMatching("IOBlockStorageDriver") else { return (0, 0) }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return (0, 0)
        }
        defer { IOObjectRelease(iterator) }

        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            guard let statistics = IORegistryEntryCreateCFProperty(
                service, "Statistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any] else { continue }
            read += (statistics["Bytes (Read)"] as? NSNumber)?.uint64Value ?? 0
            written += (statistics["Bytes (Write)"] as? NSNumber)?.uint64Value ?? 0
        }
        return (read, written)
    }

    // MARK: Red

    func readNetwork() -> NetworkMetrics {
        var metrics = NetworkMetrics()
        let counters = interfaceCounters()
        let now = Date()
        if let previous = previousNetwork {
            let elapsed = now.timeIntervalSince(previous.date)
            metrics.downloadRate = rate(counters.received, previous.received, over: elapsed)
            metrics.uploadRate = rate(counters.sent, previous.sent, over: elapsed)
        }
        previousNetwork = (counters.received, counters.sent, now)
        return metrics
    }

    /// Suma los bytes de todas las interfaces físicas, saltándose `lo0`.
    /// `if_data` expone contadores de 32 bits, así que el total retrocede cada
    /// vez que una interfaz pasa de 4 GB.
    private func interfaceCounters() -> (received: UInt64, sent: UInt64) {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return (0, 0) }
        defer { freeifaddrs(head) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            guard interface.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) else { continue }
            let name = String(cString: interface.ifa_name)
            guard name != "lo0" else { continue }
            guard let data = interface.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }
            received += UInt64(data.pointee.ifi_ibytes)
            sent += UInt64(data.pointee.ifi_obytes)
        }
        return (received, sent)
    }
}
