//
//  HistoryChart.swift
//  Monitorizacion
//
//  Gráficas del histórico con Swift Charts: sirven para repasar una partida o
//  una inferencia una vez terminada.
//

import Charts
import SwiftUI

struct HistoryChart: View {
    let title: String
    let samples: [Snapshot]
    /// Valor a dibujar de cada muestra. Devolver `nil` deja un hueco en la línea.
    let value: (Snapshot) -> Double?
    let unit: String
    var tint: Color = .accentColor
    /// Techo del eje vertical. Si es `nil` se ajusta al máximo observado.
    var upperBound: Double?

    private var points: [(date: Date, value: Double)] {
        samples.compactMap { snapshot in
            value(snapshot).map { (snapshot.date, $0) }
        }
    }

    private var domain: ClosedRange<Double> {
        if let upperBound { return 0...upperBound }
        let maximum = points.map(\.value).max() ?? 1
        return 0...(maximum * 1.15 + 0.001)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                if let last = points.last {
                    Text("\(last.value.oneDecimal) \(unit)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if points.count < 2 {
                Text("Recogiendo datos…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(height: 90, alignment: .center)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    ForEach(points, id: \.date) { point in
                        AreaMark(x: .value("Hora", point.date), y: .value(unit, point.value))
                            .foregroundStyle(tint.opacity(0.18))
                        LineMark(x: .value("Hora", point.date), y: .value(unit, point.value))
                            .foregroundStyle(tint)
                            .interpolationMethod(.monotone)
                    }
                }
                .chartYScale(domain: domain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) {
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 4))
                }
                .frame(height: 90)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }
}
