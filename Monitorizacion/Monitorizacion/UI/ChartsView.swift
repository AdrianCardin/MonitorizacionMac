//
//  ChartsView.swift
//  Monitorizacion
//
//  Histórico y resumen de la sesión: para mirar después de una partida o de
//  haber ejecutado un modelo en local.
//

import SwiftUI

struct ChartsView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var minutes = 5

    private var samples: [Snapshot] { monitor.history(lastMinutes: minutes) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                controls
                peaks

                HistoryChart(title: "Temperatura del chip",
                             samples: samples,
                             value: { $0.thermal.chipTemperature },
                             unit: "°C",
                             tint: .red,
                             upperBound: 110)

                HistoryChart(title: "CPU",
                             samples: samples,
                             value: { $0.cpu.total * 100 },
                             unit: "%",
                             tint: .blue,
                             upperBound: 100)

                HistoryChart(title: "GPU",
                             samples: samples,
                             value: { $0.gpu.available ? $0.gpu.utilization * 100 : nil },
                             unit: "%",
                             tint: .purple,
                             upperBound: 100)

                HistoryChart(title: "Memoria usada",
                             samples: samples,
                             value: { Double($0.memory.used) / 1_073_741_824 },
                             unit: "GB",
                             tint: .teal)

                HistoryChart(title: "Consumo",
                             samples: samples,
                             value: { $0.power.watts },
                             unit: "W",
                             tint: .pink)
            }
            .padding(16)
        }
    }

    private var controls: some View {
        HStack {
            Picker("Ventana", selection: $minutes) {
                Text("1 min").tag(1)
                Text("5 min").tag(5)
                Text("15 min").tag(15)
                Text("30 min").tag(30)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            Button("Reiniciar sesión", systemImage: "arrow.counterclockwise") {
                monitor.resetSession()
            }
            .help("Borra el histórico y los máximos para medir una sesión nueva")
        }
    }

    private var peaks: some View {
        let session = monitor.session
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Máximos de la sesión").font(.headline)
                Spacer()
                Text(session.duration.compactDuration)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                peak("Temp. máxima", session.maxTemperature?.degrees,
                     tint: session.maxTemperature.map(TemperatureScale.color) ?? .secondary)
                peak("Temp. media", session.averageTemperature?.degrees)
                peak("CPU máxima", session.maxCPU.percent)
                peak("GPU máxima", session.maxGPU.percent)
                peak("Consumo máximo", session.maxWatts.map { "\($0.oneDecimal) W" })
                peak("Memoria máxima", session.maxMemoryUsed > 0 ? session.maxMemoryUsed.byteSize : nil)
                peak("Tiempo limitado", session.secondsThrottled > 0
                     ? session.secondsThrottled.compactDuration : "nada",
                     tint: session.secondsThrottled > 0 ? .orange : .green)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }

    private func peak(_ title: String, _ value: String?, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
