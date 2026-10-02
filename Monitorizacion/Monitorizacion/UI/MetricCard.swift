//
//  MetricCard.swift
//  Monitorizacion
//
//  Piezas reutilizables de la interfaz: tarjeta con valor destacado y barras.
//

import SwiftUI

/// Tarjeta con un título, un valor grande y contenido opcional debajo.
struct MetricCard<Content: View>: View {
    let title: String
    let value: String
    var caption: String?
    var tint: Color = .accentColor
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .monospacedDigit()

            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }
}

extension MetricCard where Content == EmptyView {
    init(title: String, value: String, caption: String? = nil, tint: Color = .accentColor) {
        self.init(title: title, value: value, caption: caption, tint: tint) { EmptyView() }
    }
}

/// Barra horizontal con etiqueta y valor, para listas de núcleos o sensores.
struct LabeledBar: View {
    let label: String
    /// Valor normalizado, 0...1.
    let fraction: Double
    let detail: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.caption)
                .frame(width: 118, alignment: .leading)
                .lineLimit(1)
            ProgressView(value: min(max(fraction, 0), 1))
                .progressViewStyle(.linear)
                .tint(tint)
            Text(detail)
                .font(.caption)
                .monospacedDigit()
                .frame(width: 66, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
    }
}

/// Indicador compacto de estado con punto de color.
struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: .capsule)
    }
}
