//
//  MonitorizacionApp.swift
//  Monitorizacion
//
//  Monitor de temperatura y carga del Mac.
//

import SwiftUI

@main
struct MonitorizacionApp: App {

    /// Un único monitor compartido por la ventana y por la barra de menús.
    @State private var monitor = SystemMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitor)
                .frame(minWidth: 720, minHeight: 520)
                .task { monitor.start() }
        }
        .windowResizability(.contentSize)

        // Permite vigilar la temperatura con la ventana cerrada, que es lo
        // normal mientras se juega o se ejecuta un modelo.
        MenuBarExtra {
            MenuBarSummary()
                .environment(monitor)
        } label: {
            MenuBarLabel()
                .environment(monitor)
        }
    }
}

/// Texto que aparece en la barra de menús: temperatura y uso de CPU.
private struct MenuBarLabel: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        if let temperature = monitor.current.thermal.chipTemperature {
            Text("\(Int(temperature.rounded()))° · \(monitor.current.cpu.total.percent)")
        } else {
            Image(systemName: "thermometer.medium")
        }
    }
}

/// Menú desplegable con lo esencial.
private struct MenuBarSummary: View {
    @Environment(SystemMonitor.self) private var monitor

    var body: some View {
        let snapshot = monitor.current

        if let temperature = snapshot.thermal.chipTemperature {
            Text("Chip: \(temperature.degrees) · \(TemperatureScale.description(temperature))")
        }
        Text("Estado térmico: \(snapshot.thermal.pressure.label)")
        Divider()
        Text("CPU: \(snapshot.cpu.total.percent)")
        if snapshot.gpu.available {
            Text("GPU: \(snapshot.gpu.utilization.percent)")
        }
        Text("Memoria: \(snapshot.memory.used.byteSize) de \(snapshot.memory.total.byteSize)")
        if let watts = snapshot.power.watts {
            Text("Consumo: \(watts.oneDecimal) W")
        }
        if let peak = monitor.session.maxTemperature {
            Divider()
            Text("Máxima de la sesión: \(peak.degrees)")
        }
        Divider()
        Button(monitor.isRunning ? "Pausar medición" : "Reanudar medición") {
            monitor.isRunning ? monitor.stop() : monitor.start()
        }
        Button("Salir") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}
