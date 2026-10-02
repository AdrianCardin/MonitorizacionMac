//
//  SystemMonitor.swift
//  Monitorizacion
//
//  Orquesta los lectores: muestrea en segundo plano, guarda el histórico y
//  calcula los máximos de la sesión.
//

import Foundation
import Observation

/// Agrupa los lectores y toma una muestra completa. Es un actor para que el
/// muestreo no bloquee el hilo principal y para que dos muestras no se solapen.
actor Sampler {

    private let temperature = TemperatureReader()
    private let cpu = CPUReader()
    private let gpu = GPUReader()
    private let memory = MemoryReader()
    private let power = PowerReader()
    private let storageNetwork = StorageNetworkReader()
    private let processes = ProcessReader()

    var sensorsAvailable: Bool { temperature.isAvailable }

    func sample(includeProcesses: Bool) -> Snapshot {
        var snapshot = Snapshot()
        snapshot.cpu = cpu.read()
        snapshot.gpu = gpu.read()
        snapshot.memory = memory.read()
        snapshot.power = power.read()
        snapshot.thermal.sensors = temperature.read()
        snapshot.thermal.pressure = power.thermalPressure()
        snapshot.storage = storageNetwork.readStorage()
        snapshot.network = storageNetwork.readNetwork()
        if includeProcesses {
            snapshot.processes = processes.read()
        }
        return snapshot
    }
}

@Observable
final class SystemMonitor {

    /// Última lectura.
    private(set) var current = Snapshot()
    /// Histórico para las gráficas, limitado a `historyLimit` muestras.
    private(set) var history: [Snapshot] = []
    private(set) var hardware = HardwareInfo.summary()
    private(set) var sensorsAvailable = true
    private(set) var isRunning = false

    /// Máximos desde que arrancó la sesión de medición.
    private(set) var session = SessionPeaks()

    /// Intervalo de muestreo en segundos.
    var interval: Double = 1 {
        didSet { if isRunning { restart() } }
    }

    /// Umbral de aviso de temperatura, en grados.
    var alertThreshold: Double {
        didSet { UserDefaults.standard.set(alertThreshold, forKey: Self.thresholdKey) }
    }

    private static let thresholdKey = "alertThreshold"
    /// 30 minutos a una muestra por segundo: suficiente para repasar una partida
    /// o una inferencia sin que la memoria crezca sin control.
    private let historyLimit = 1800
    /// Los procesos se enumeran cada pocas muestras porque es la lectura más
    /// costosa y no necesita la misma frecuencia.
    private let processEveryNSamples = 3

    private let sampler = Sampler()
    private var task: Task<Void, Never>?
    private var sampleCount = 0
    private var lastProcesses: [ProcessUsage] = []

    init() {
        let stored = UserDefaults.standard.double(forKey: Self.thresholdKey)
        alertThreshold = stored > 0 ? stored : 85
    }

    // MARK: Control

    func start() {
        guard task == nil else { return }
        isRunning = true
        task = Task { [weak self] in
            guard let self else { return }
            self.sensorsAvailable = await self.sampler.sensorsAvailable
            while !Task.isCancelled {
                await self.takeSample()
                try? await Task.sleep(for: .seconds(self.interval))
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isRunning = false
    }

    private func restart() {
        stop()
        start()
    }

    /// Reinicia los máximos y el histórico, para medir una sesión concreta.
    func resetSession() {
        history.removeAll()
        session = SessionPeaks()
    }

    private func takeSample() async {
        sampleCount += 1
        let wantsProcesses = sampleCount % processEveryNSamples == 0
        var snapshot = await sampler.sample(includeProcesses: wantsProcesses)

        // Entre enumeraciones se mantiene la última lista conocida para que la
        // tabla de procesos no parpadee.
        if wantsProcesses {
            lastProcesses = snapshot.processes
        } else {
            snapshot.processes = lastProcesses
        }

        current = snapshot
        history.append(snapshot)
        if history.count > historyLimit {
            history.removeFirst(history.count - historyLimit)
        }
        session.update(with: snapshot, interval: interval)
    }

    // MARK: Derivados para la interfaz

    /// `true` cuando el chip supera el umbral configurado.
    var isOverThreshold: Bool {
        guard let temperature = current.thermal.chipTemperature else { return false }
        return temperature >= alertThreshold
    }

    /// Histórico recortado a los últimos minutos indicados.
    func history(lastMinutes minutes: Int) -> [Snapshot] {
        let cutoff = Date().addingTimeInterval(-Double(minutes) * 60)
        return history.filter { $0.date >= cutoff }
    }
}

/// Máximos y medias acumulados de la sesión de medición en curso.
struct SessionPeaks: Sendable {
    var startedAt = Date()
    var maxTemperature: Double?
    var maxCPU: Double = 0
    var maxGPU: Double = 0
    var maxWatts: Double?
    var maxMemoryUsed: UInt64 = 0
    var secondsThrottled: Double = 0
    private var temperatureSum: Double = 0
    private var temperatureSamples = 0

    var averageTemperature: Double? {
        temperatureSamples > 0 ? temperatureSum / Double(temperatureSamples) : nil
    }

    var duration: TimeInterval { Date().timeIntervalSince(startedAt) }

    mutating func update(with snapshot: Snapshot, interval: Double) {
        if let temperature = snapshot.thermal.chipTemperature {
            maxTemperature = max(maxTemperature ?? temperature, temperature)
            temperatureSum += temperature
            temperatureSamples += 1
        }
        maxCPU = max(maxCPU, snapshot.cpu.total)
        maxGPU = max(maxGPU, snapshot.gpu.utilization)
        if let watts = snapshot.power.watts {
            maxWatts = max(maxWatts ?? watts, watts)
        }
        maxMemoryUsed = max(maxMemoryUsed, snapshot.memory.used)
        if snapshot.thermal.pressure != .nominal {
            secondsThrottled += interval
        }
    }
}
