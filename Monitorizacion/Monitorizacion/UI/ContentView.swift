//
//  ContentView.swift
//  Monitorizacion
//
//  Ventana principal: barra lateral con las secciones y cabecera con el estado
//  térmico siempre visible.
//

import SwiftUI

struct ContentView: View {
    @Environment(SystemMonitor.self) private var monitor
    @State private var section: Section = .summary

    enum Section: String, CaseIterable, Identifiable {
        case summary, charts, sensors, processes, hardware

        var id: Self { self }

        var title: String {
            switch self {
            case .summary: return "Resumen"
            case .charts: return "Histórico"
            case .sensors: return "Sensores"
            case .processes: return "Procesos"
            case .hardware: return "Equipo"
            }
        }

        var symbol: String {
            switch self {
            case .summary: return "gauge.with.dots.needle.67percent"
            case .charts: return "chart.xyaxis.line"
            case .sensors: return "thermometer.medium"
            case .processes: return "list.bullet.rectangle"
            case .hardware: return "cpu"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.symbol).tag(item)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 180, max: 220)
        } detail: {
            VStack(spacing: 0) {
                ThermalHeader()
                Divider()
                detail
            }
            .navigationTitle(section.title)
            .toolbar { toolbar }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .summary:
            SummaryView(snapshot: monitor.current, hardware: monitor.hardware)
        case .charts:
            ChartsView()
        case .sensors:
            SensorsView(thermal: monitor.current.thermal, sensorsAvailable: monitor.sensorsAvailable)
        case .processes:
            ProcessesView(processes: monitor.current.processes)
        case .hardware:
            HardwareView(hardware: monitor.hardware, power: monitor.current.power)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem {
            Picker("Frecuencia", selection: Binding(
                get: { monitor.interval },
                set: { monitor.interval = $0 })) {
                Text("1 s").tag(1.0)
                Text("2 s").tag(2.0)
                Text("5 s").tag(5.0)
            }
            .pickerStyle(.segmented)
            .help("Cada cuánto se toma una medida")
        }
        ToolbarItem {
            Button {
                monitor.isRunning ? monitor.stop() : monitor.start()
            } label: {
                Label(monitor.isRunning ? "Pausar" : "Reanudar",
                      systemImage: monitor.isRunning ? "pause.fill" : "play.fill")
            }
        }
    }
}

/// Cabecera fija: temperatura del chip, estado térmico y aviso de umbral.
private struct ThermalHeader: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        HStack(spacing: 16) {
            if let temperature = monitor.current.thermal.chipTemperature {
                HStack(spacing: 8) {
                    Image(systemName: "thermometer.medium")
                        .foregroundStyle(TemperatureScale.color(temperature))
                    Text(temperature.degrees)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(TemperatureScale.description(temperature))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sin lectura de temperatura").foregroundStyle(.secondary)
            }

            StatusBadge(text: monitor.current.thermal.pressure.label,
                        color: monitor.current.thermal.pressure.color)
                .help(monitor.current.thermal.pressure.explanation)

            if monitor.isOverThreshold {
                StatusBadge(text: "Supera \(Int(monitor.alertThreshold)) °C", color: .red)
            }

            Spacer()

            if !monitor.isRunning {
                StatusBadge(text: "En pausa", color: .secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
