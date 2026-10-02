//
//  PowerReader.swift
//  Monitorizacion
//
//  Consumo, estado de la batería y presión térmica.
//
//  El consumo en vatios se obtiene de la propia batería (tensión x corriente),
//  que es lo único medible sin privilegios: el desglose por CPU/GPU/Neural
//  Engine vive en los canales "Energy Model" de IOReport y devuelve ceros si el
//  proceso no es root, que es la razón por la que `powermetrics` pide sudo.
//  Con el portátil enchufado la corriente refleja la carga de la batería y no
//  el gasto del sistema, así que en ese caso no se publica ningún vatiaje.
//

import Foundation
import IOKit
import IOKit.ps

nonisolated final class PowerReader {

    func read() -> PowerMetrics {
        var metrics = PowerMetrics()
        guard let properties = batteryProperties() else { return metrics }
        metrics.hasBattery = true

        let number = { (key: String) in (properties[key] as? NSNumber)?.doubleValue }
        let flag = { (key: String) in (properties[key] as? Bool) ?? false }

        metrics.isPluggedIn = flag("ExternalConnected")
        metrics.isCharging = flag("IsCharging")

        if let current = number("CurrentCapacity"), let max = number("MaxCapacity"), max > 0 {
            metrics.charge = min(current / max, 1)
        }
        metrics.cycleCount = Int(number("CycleCount") ?? 0)

        if let remaining = number("TimeRemaining"), remaining > 0, remaining < 60 * 24 {
            metrics.minutesRemaining = Int(remaining)
        }

        // La corriente se publica como entero sin signo de 64 bits: hay que
        // reinterpretarla con signo, porque es negativa al descargar.
        if let raw = (properties["InstantAmperage"] ?? properties["Amperage"]) as? NSNumber,
           let millivolts = number("Voltage") {
            let milliamps = Double(Int64(bitPattern: raw.uint64Value))
            // Solo tiene sentido como consumo del sistema cuando se descarga.
            if milliamps < 0 {
                metrics.watts = abs(milliamps) / 1000 * millivolts / 1000
            }
        }

        if let data = properties["BatteryData"] as? [String: Any] {
            let value = { (key: String) in (data[key] as? NSNumber)?.doubleValue }
            if let full = value("FullChargeCapacity"), let design = value("DesignCapacity"), design > 0 {
                metrics.health = min(full / design, 1)
            }
        }
        if let charger = properties["ChargerData"] as? [String: Any],
           let limited = (charger["TimeChargingThermallyLimited"] as? NSNumber)?.intValue {
            metrics.chargingThermallyLimited = limited > 0
        }
        return metrics
    }

    /// Nivel de presión térmica del sistema. Es la señal pública de que macOS
    /// está limitando el rendimiento para bajar la temperatura.
    func thermalPressure() -> ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }

    private func batteryProperties() -> [String: Any]? {
        guard let matching = IOServiceMatching("AppleSmartBattery") else { return nil }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &unmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS else {
            return nil
        }
        return unmanaged?.takeRetainedValue() as? [String: Any]
    }
}
