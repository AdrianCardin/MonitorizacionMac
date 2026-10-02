//
//  SensorsView.swift
//  Monitorizacion
//
//  Todos los sensores de temperatura, agrupados por tipo.
//

import SwiftUI

struct SensorsView: View {
    let thermal: ThermalMetrics
    let sensorsAvailable: Bool

    /// Grupos con al menos un sensor, en el orden declarado por `SensorKind`.
    private var groups: [(kind: SensorKind, sensors: [TemperatureSensor])] {
        SensorKind.allCases.compactMap { kind in
            let sensors = thermal.sensors
                .filter { $0.kind == kind }
                .sorted { $0.celsius > $1.celsius }
            return sensors.isEmpty ? nil : (kind, sensors)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !sensorsAvailable {
                    GroupBox {
                        Text("Este Mac no expone sensores de temperatura legibles.")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(groups, id: \.kind) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group.kind.label).font(.headline)
                            Spacer()
                            if let hottest = group.sensors.map(\.celsius).max() {
                                Text("máx. \(hottest.degrees)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(TemperatureScale.color(hottest))
                            }
                        }
                        ForEach(group.sensors) { sensor in
                            LabeledBar(label: sensor.name,
                                       // 110 °C como techo de la escala: por
                                       // encima el chip ya está en apuros.
                                       fraction: sensor.celsius / 110,
                                       detail: sensor.celsius.degrees,
                                       tint: TemperatureScale.color(sensor.celsius))
                        }
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
                }

                Text("Los ventiladores no aparecen porque este Mac no publica sus revoluciones a través del SMC.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }
}
