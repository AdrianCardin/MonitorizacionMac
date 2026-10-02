//
//  TemperatureReader.swift
//  Monitorizacion
//
//  Lectura de los sensores de temperatura del Mac.
//
//  macOS no publica ninguna API para leer grados centígrados: ni IOKit ni
//  ProcessInfo lo ofrecen (ProcessInfo solo da un nivel de presión térmica).
//  Los sensores están expuestos como servicios HID en la página de uso 0xFF00,
//  uso 5, accesibles con las funciones IOHIDEventSystemClient* — que existen en
//  IOKit pero no están en sus cabeceras públicas.
//
//  Para no depender de símbolos en tiempo de enlace (lo que rompería la
//  compilación si Apple los retira) se resuelven en caliente con dlsym. Si
//  alguno falta, el lector se queda inactivo y la app sigue funcionando sin
//  temperaturas en lugar de caerse.
//

import Foundation

/// Lee las temperaturas de los sensores del SoC, la batería y el almacenamiento.
nonisolated final class TemperatureReader {

    // MARK: Firmas de las funciones privadas de IOKit

    private typealias ClientCreate = @convention(c) (CFAllocator?) -> Unmanaged<AnyObject>?
    private typealias ClientSetMatching = @convention(c) (AnyObject, CFDictionary) -> Void
    private typealias ClientCopyServices = @convention(c) (AnyObject) -> Unmanaged<CFArray>?
    private typealias ServiceCopyProperty = @convention(c) (AnyObject, CFString) -> Unmanaged<AnyObject>?
    private typealias ServiceCopyEvent = @convention(c) (AnyObject, Int64, Int32, UInt64) -> Unmanaged<AnyObject>?
    private typealias EventGetFloatValue = @convention(c) (AnyObject, UInt32) -> Double

    private struct Symbols {
        let create: ClientCreate
        let setMatching: ClientSetMatching
        let copyServices: ClientCopyServices
        let copyProperty: ServiceCopyProperty
        let copyEvent: ServiceCopyEvent
        let floatValue: EventGetFloatValue
    }

    /// Página de uso HID de los sensores del SoC.
    private static let sensorUsagePage = 0xff00
    /// Uso HID de los sensores de temperatura dentro de esa página.
    private static let temperatureUsage = 5
    /// `kIOHIDEventTypeTemperature`.
    private static let temperatureEventType: Int64 = 15

    private let symbols: Symbols?
    private let client: AnyObject?
    private let services: [AnyObject]
    /// Nombre y clasificación cacheados: no cambian durante la ejecución.
    private let descriptors: [(name: String, kind: SensorKind)]

    /// `true` si el equipo expone sensores legibles.
    var isAvailable: Bool { !services.isEmpty }

    init() {
        guard let symbols = Self.loadSymbols(),
              let clientRef = symbols.create(kCFAllocatorDefault)?.takeRetainedValue() else {
            self.symbols = nil
            self.client = nil
            self.services = []
            self.descriptors = []
            return
        }

        let matching: [String: Any] = [
            "PrimaryUsagePage": Self.sensorUsagePage,
            "PrimaryUsage": Self.temperatureUsage,
        ]
        symbols.setMatching(clientRef, matching as CFDictionary)
        let found = (symbols.copyServices(clientRef)?.takeRetainedValue() as? [AnyObject]) ?? []

        self.symbols = symbols
        self.client = clientRef
        self.services = found
        self.descriptors = found.map { service in
            let name = (symbols.copyProperty(service, "Product" as CFString)?
                .takeRetainedValue() as? String) ?? "Sensor"
            return (name, SensorKind(sensorName: name))
        }
    }

    private static func loadSymbols() -> Symbols? {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else {
            return nil
        }
        func resolve<T>(_ name: String, as type: T.Type) -> T? {
            dlsym(handle, name).map { unsafeBitCast($0, to: type) }
        }
        guard let create = resolve("IOHIDEventSystemClientCreate", as: ClientCreate.self),
              let setMatching = resolve("IOHIDEventSystemClientSetMatching", as: ClientSetMatching.self),
              let copyServices = resolve("IOHIDEventSystemClientCopyServices", as: ClientCopyServices.self),
              let copyProperty = resolve("IOHIDServiceClientCopyProperty", as: ServiceCopyProperty.self),
              let copyEvent = resolve("IOHIDServiceClientCopyEvent", as: ServiceCopyEvent.self),
              let floatValue = resolve("IOHIDEventGetFloatValue", as: EventGetFloatValue.self) else {
            return nil
        }
        return Symbols(create: create, setMatching: setMatching, copyServices: copyServices,
                       copyProperty: copyProperty, copyEvent: copyEvent, floatValue: floatValue)
    }

    /// Lee todos los sensores y descarta las lecturas que no son temperaturas reales.
    func read() -> [TemperatureSensor] {
        guard let symbols else { return [] }
        let field = UInt32(Self.temperatureEventType << 16)
        var result: [TemperatureSensor] = []
        result.reserveCapacity(services.count)

        for (index, service) in services.enumerated() {
            guard let event = symbols.copyEvent(service, Self.temperatureEventType, 0, 0)?
                .takeRetainedValue() else { continue }
            let celsius = symbols.floatValue(event, field)
            let descriptor = descriptors[index]
            guard Self.isPlausible(celsius, name: descriptor.name) else { continue }
            result.append(TemperatureSensor(id: index, name: descriptor.name,
                                            kind: descriptor.kind, celsius: celsius))
        }
        return result
    }

    /// Filtra basura: hay sensores que devuelven valores imposibles cuando están
    /// apagados (del orden de -9200 °C) y otros, como `tcal`, que son constantes
    /// de calibración y no miden nada.
    private static func isPlausible(_ celsius: Double, name: String) -> Bool {
        guard celsius > 1, celsius < 150 else { return false }
        return !name.localizedCaseInsensitiveContains("tcal")
    }
}

private extension SensorKind {
    /// Clasifica un sensor por su nombre. Los nombres varían entre modelos:
    /// los M1-M4 usan "pACC/eACC/GPU/ANE MTR Temp Sensor" y los más recientes
    /// exponen los sensores de die del SoC como "PMU tdieN".
    init(sensorName name: String) {
        let lower = name.lowercased()
        if lower.contains("battery") || lower.contains("gas gauge") {
            self = .battery
        } else if lower.contains("nand") || lower.contains("ssd") {
            self = .storage
        } else if lower.contains("gpu") {
            self = .gpu
        } else if lower.contains("ane") {
            self = .neuralEngine
        } else if lower.contains("dram") || lower.contains("lpddr") {
            self = .memory
        } else if lower.contains("acc") || lower.contains("cpu") {
            self = .cpu
        } else if lower.contains("tdie") || lower.contains("tdev") || lower.contains("soc") || lower.contains("pmu") {
            self = .soc
        } else {
            self = .other
        }
    }
}
