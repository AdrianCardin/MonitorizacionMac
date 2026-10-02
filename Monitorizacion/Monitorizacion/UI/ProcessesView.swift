//
//  ProcessesView.swift
//  Monitorizacion
//
//  Qué procesos están cargando el equipo.
//

import SwiftUI

struct ProcessesView: View {
    let processes: [ProcessUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Table(processes) {
                TableColumn("Proceso") { process in
                    Text(process.name).lineLimit(1)
                }
                TableColumn("PID") { process in
                    Text("\(process.id)").monospacedDigit().foregroundStyle(.secondary)
                }
                .width(60)
                TableColumn("CPU") { process in
                    Text(String(format: "%.1f %%", process.cpuPercent))
                        .monospacedDigit()
                }
                .width(70)
                TableColumn("Memoria") { process in
                    Text(process.memoryBytes.byteSize).monospacedDigit()
                }
                .width(90)
            }

            Text("El porcentaje es relativo a un núcleo: con \(ProcessInfo.processInfo.processorCount) núcleos el máximo teórico es \(ProcessInfo.processInfo.processorCount * 100) %. Solo se listan los procesos del usuario.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
        }
    }
}
