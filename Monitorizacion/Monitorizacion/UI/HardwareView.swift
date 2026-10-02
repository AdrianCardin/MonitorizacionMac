//
//  HardwareView.swift
//  Monitorizacion
//
//  Ficha del equipo, estado de la batería y ajustes del aviso de temperatura.
//

import SwiftUI

struct HardwareView: View {
    @Environment(SystemMonitor.self) private var monitor
    let hardware: HardwareSummary
    let power: PowerMetrics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                group("Equipo") {
                    row("Chip", hardware.chip)
                    row("Modelo", hardware.modelIdentifier)
                    row("Núcleos", "\(hardware.coreCount)")
                    ForEach(hardware.clusters) { cluster in
                        row("Cluster \(cluster.name)", "\(cluster.coreCount) núcleos")
                    }
                    row("Memoria", hardware.physicalMemory.byteSize)
                    row("Sistema", hardware.osVersion)
                    row("Encendido desde",
                        hardware.bootDate.formatted(date: .abbreviated, time: .shortened))
                }

                if power.hasBattery {
                    group("Batería") {
                        row("Carga", power.charge.percent)
                        row("Estado", power.isCharging ? "Cargando"
                            : (power.isPluggedIn ? "Conectada a la red" : "En uso"))
                        row("Salud", power.health > 0 ? power.health.percent : "—")
                        row("Ciclos", "\(power.cycleCount)")
                        if let minutes = power.minutesRemaining {
                            row(power.remainingLabel, "\(minutes) min")
                        }
                        if power.chargingThermallyLimited {
                            row("Carga limitada por temperatura", "Sí")
                        }
                    }
                }

                group("Aviso de temperatura") {
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(value: Binding(get: { monitor.alertThreshold },
                                              set: { monitor.alertThreshold = $0 }),
                               in: 60...105, step: 1) {
                            Text("Umbral")
                        } minimumValueLabel: {
                            Text("60")
                        } maximumValueLabel: {
                            Text("105")
                        }
                        Text("Aviso al superar \(Int(monitor.alertThreshold)) °C. Se muestra en la cabecera y en la barra de menús.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                group("Qué no se puede medir") {
                    Text("""
                    Las revoluciones de los ventiladores y el consumo desglosado por CPU, GPU \
                    y Neural Engine no son accesibles sin privilegios de administrador: los \
                    canales del sistema que los publican devuelven ceros a los procesos \
                    normales, y es la razón por la que `powermetrics` se ejecuta con sudo. \
                    El consumo que se muestra proviene de la propia batería y es real, pero \
                    solo se puede medir mientras no está enchufado.
                    """)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 20)
            Text(value).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
