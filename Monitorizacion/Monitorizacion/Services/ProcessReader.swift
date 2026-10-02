//
//  ProcessReader.swift
//  Monitorizacion
//
//  Procesos que más CPU y memoria consumen, para saber qué está calentando el
//  Mac. Se usa libproc en lugar de lanzar `ps`, así no se crean procesos nuevos
//  en cada muestreo.
//
//  Sin privilegios de administrador solo son visibles los procesos del usuario;
//  los del sistema se omiten en silencio.
//

import Darwin
import Foundation

nonisolated final class ProcessReader {

    /// Tiempo de CPU acumulado por proceso en la lectura anterior, en nanosegundos.
    private var previousCPUTime: [Int32: UInt64] = [:]
    private var previousDate = Date()

    func read(limit: Int = 8) -> [ProcessUsage] {
        let now = Date()
        let elapsed = now.timeIntervalSince(previousDate)
        defer { previousDate = now }

        var current: [Int32: UInt64] = [:]
        var usages: [ProcessUsage] = []

        for pid in pids() {
            var info = proc_taskallinfo()
            let size = Int32(MemoryLayout<proc_taskallinfo>.stride)
            guard proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &info, size) == size else { continue }

            let cpuTime = info.ptinfo.pti_total_user + info.ptinfo.pti_total_system
            current[pid] = cpuTime

            // El primer muestreo no tiene referencia previa: se omite el % de CPU.
            guard elapsed > 0, let before = previousCPUTime[pid], cpuTime >= before else { continue }
            let percent = Double(cpuTime - before) / (elapsed * 1_000_000_000) * 100

            let name = withUnsafeBytes(of: info.pbsd.pbi_name) { raw in
                String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
            }
            usages.append(ProcessUsage(id: pid,
                                       name: name.isEmpty ? "pid \(pid)" : name,
                                       cpuPercent: percent,
                                       memoryBytes: info.ptinfo.pti_resident_size))
        }

        previousCPUTime = current
        return Array(usages.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(limit))
    }

    private func pids() -> [Int32] {
        let needed = proc_listallpids(nil, 0)
        guard needed > 0 else { return [] }
        // Margen extra: entre la consulta del tamaño y la lectura pueden
        // aparecer procesos nuevos.
        var buffer = [Int32](repeating: 0, count: Int(needed) + 64)
        let bytes = proc_listallpids(&buffer, Int32(buffer.count * MemoryLayout<Int32>.stride))
        guard bytes > 0 else { return [] }
        return Array(buffer.prefix(Int(bytes) / MemoryLayout<Int32>.stride)).filter { $0 > 0 }
    }
}
