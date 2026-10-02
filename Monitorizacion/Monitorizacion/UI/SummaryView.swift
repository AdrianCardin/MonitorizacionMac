//
//  SummaryView.swift
//  Monitorizacion
//
//  Vista de un vistazo: lo que interesa mientras el Mac está trabajando.
//

import SwiftUI

struct SummaryView: View {
    let snapshot: Snapshot
    let hardware: HardwareSummary

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LazyVGrid(columns: columns, spacing: 12) {
                    temperatureCard
                    cpuCard
                    gpuCard
                    memoryCard
                    powerCard
                    diskCard
                }

                clusters
                cores
                transfers
            }
            .padding(16)
        }
    }

    // MARK: Tarjetas

    private var temperatureCard: some View {
        let temperature = snapshot.thermal.chipTemperature
        return MetricCard(
            title: "Chip",
            value: temperature?.degrees ?? "—",
            caption: captionForTemperature,
            tint: temperature.map(TemperatureScale.color) ?? .secondary)
    }

    private var captionForTemperature: String {
        var parts: [String] = []
        if let battery = snapshot.thermal.hottest(.battery) {
            parts.append("batería \(battery.degrees)")
        }
        if let storage = snapshot.thermal.hottest(.storage) {
            parts.append("SSD \(storage.degrees)")
        }
        return parts.isEmpty ? "máximo de los sensores del SoC" : parts.joined(separator: " · ")
    }

    private var cpuCard: some View {
        MetricCard(title: "CPU",
                   value: snapshot.cpu.total.percent,
                   caption: "sistema \(snapshot.cpu.system.percent) · usuario \(snapshot.cpu.user.percent)",
                   tint: .blue) {
            ProgressView(value: snapshot.cpu.total).tint(.blue)
        }
    }

    private var gpuCard: some View {
        MetricCard(title: "GPU",
                   value: snapshot.gpu.available ? snapshot.gpu.utilization.percent : "—",
                   caption: snapshot.gpu.memoryInUse > 0
                       ? "\(snapshot.gpu.memoryInUse.byteSize) en uso"
                       : snapshot.gpu.name,
                   tint: .purple) {
            ProgressView(value: snapshot.gpu.utilization).tint(.purple)
        }
    }

    private var memoryCard: some View {
        MetricCard(title: "Memoria",
                   value: snapshot.memory.used.byteSize,
                   caption: "de \(snapshot.memory.total.byteSize) · presión \(snapshot.memory.pressure.label.lowercased())",
                   tint: snapshot.memory.pressure == .normal ? .teal : .orange) {
            ProgressView(value: snapshot.memory.usedFraction)
                .tint(snapshot.memory.pressure == .normal ? .teal : .orange)
        }
    }

    private var powerCard: some View {
        MetricCard(title: "Consumo",
                   value: snapshot.power.watts.map { "\($0.oneDecimal) W" } ?? "—",
                   caption: powerCaption,
                   tint: .pink)
    }

    private var powerCaption: String {
        guard snapshot.power.hasBattery else { return "sin batería" }
        var parts = ["batería \(snapshot.power.charge.percent)"]
        if snapshot.power.watts == nil {
            parts.append("solo medible sin enchufar")
        } else if let minutes = snapshot.power.minutesRemaining {
            parts.append("\(minutes) min")
        }
        return parts.joined(separator: " · ")
    }

    private var diskCard: some View {
        MetricCard(title: "Disco",
                   value: snapshot.storage.free.byteSize,
                   caption: "libres de \(snapshot.storage.total.byteSize)",
                   tint: .indigo) {
            ProgressView(value: snapshot.storage.usedFraction).tint(.indigo)
        }
    }

    // MARK: Detalle de CPU

    @ViewBuilder
    private var clusters: some View {
        if !snapshot.cpu.clusters.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Clusters de núcleos").font(.headline)
                ForEach(snapshot.cpu.clusters) { cluster in
                    LabeledBar(label: "\(cluster.name) (\(cluster.coreCount))",
                               fraction: cluster.usage,
                               detail: cluster.usage.percent,
                               tint: .blue)
                }
                if !snapshot.cpu.loadAverage.isEmpty {
                    Text("Carga media: " + snapshot.cpu.loadAverage.map(\.oneDecimal).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var cores: some View {
        if !snapshot.cpu.perCore.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Núcleos").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 10)], spacing: 6) {
                    ForEach(Array(snapshot.cpu.perCore.enumerated()), id: \.offset) { index, usage in
                        LabeledBar(label: "Núcleo \(index + 1)",
                                   fraction: usage,
                                   detail: usage.percent,
                                   tint: .blue)
                    }
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
        }
    }

    private var transfers: some View {
        HStack(spacing: 12) {
            transferRow("Red", down: snapshot.network.downloadRate, up: snapshot.network.uploadRate)
            transferRow("Disco", down: snapshot.storage.readRate, up: snapshot.storage.writeRate)
        }
    }

    private func transferRow(_ title: String, down: Double, up: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            HStack(spacing: 14) {
                Label(down.byteRate, systemImage: "arrow.down").monospacedDigit()
                Label(up.byteRate, systemImage: "arrow.up").monospacedDigit()
            }
            .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }
}
