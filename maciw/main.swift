//
//  main.swift
//  maciw
//
//  Created by Hitoshi MORIOKA on 2025/07/10.
//

import Foundation
import ArgumentParser
import CoreWLAN

extension CWChannelBand {
    func ToInt() -> Int {
        switch self {
        case .band2GHz:
            return 2
        case .band5GHz:
            return 5
        case .band6GHz:
            return 6
        default:
            return 0
        }
    }
}

extension CWChannelWidth {
    func ToInt() -> Int {
        switch self {
        case .width20MHz:
            return 20
        case .width40MHz:
            return 40
        case .width80MHz:
            return 80
        case .width160MHz:
            return 160
        default:
            return 0
        }
    }
}

extension CWChannel {
    func ToStr() -> String {
        return "band \(self.channelBand.ToInt()), chan \(self.channelNumber), width \(self.channelWidth.ToInt())"
    }
}

struct Maciw: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "maciw",
        abstract: "Wi-Fi interface control tool",
        version: "0.1.0",
        shouldDisplay: true,
        subcommands: [Interface.self, Disassociate.self, Channel.self],
        defaultSubcommand: Interface.self,
        helpNames: [.long, .short]
    )

    @Flag(name: .customLong("verbose")) var verbose: Bool = false
    
    struct Interface: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Show interface"
        )

        mutating func run() {
            print("interface")
            let client = CWWiFiClient.shared()
            guard let iface = client.interface() else {
                print("No Wi-Fi interface.")
                return
            }
            guard let ifname = iface.interfaceName else {
                print("No interface name.")
                return
            }
            print(ifname)
        }
    }

    struct Disassociate: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Disassociate",
            aliases: ["disassoc"]
        )

        mutating func run() {
            print("disassociate")
            let client = CWWiFiClient.shared()
            guard let iface = client.interface() else {
                print("No Wi-Fi interface.")
                return
            }
            guard let ifname = iface.interfaceName else {
                print("No interface name.")
                return
            }
            print(ifname)
            iface.disassociate()
            print("disassociated")
        }
    }

    struct Channel: ParsableCommand {
        static let configuration = CommandConfiguration(
            abstract: "Channel control",
            aliases: ["chan"]
        )
        @Argument(help: "Channel")
        var chan: Int
        @Argument(help: "Channelwidth (20(default), 40, 80 or 160)")
        var chanwidth: Int = 20
        @Argument(help: "Band (2, 5, or 6) (priority 2 / 5)")
        var band: Int = 0

        mutating func run() {
            print("channel")
            print("chan \(chan), chanwidth \(chanwidth)")
            let client = CWWiFiClient.shared()
            guard let iface = client.interface() else {
                print("No Wi-Fi interface.")
                return
            }
            guard let ifname = iface.interfaceName else {
                print("No interface name.")
                return
            }
            print(ifname)

            var cwChanWidth: CWChannelWidth
            var cwChanBand: CWChannelBand
            switch chanwidth {
            case 20:
                cwChanWidth = .width20MHz
            case 40:
                cwChanWidth = .width40MHz
            case 80:
                cwChanWidth = .width80MHz
            case 160:
                cwChanWidth = .width160MHz
            default:
                print("invalid chanwidth \(chanwidth)")
                return
            }

            switch chan {
            case 1...13:
                if band == 0 || band == 2 {
                    cwChanBand = .band2GHz
                    band = 2
                } else if band == 6 {
                    cwChanBand = .band6GHz
                } else {
                    print("invalid chan \(chan) or band \(band).")
                    return
                }
            case 14...31:
                if band == 0 || band == 6 {
                    cwChanBand = .band6GHz
                    band = 6
                } else {
                    print("invalid chan \(chan) or band \(band).")
                    return
                }
            case 32...177:
                if band == 0 || band == 5 {
                    cwChanBand = .band5GHz
                    band = 5
                } else if band == 6 {
                    cwChanBand = .band6GHz
                } else {
                    print("invalid chan \(chan) or band \(band).")
                    return
                }
            case 178...233:
                if band == 0 || band == 6 {
                    cwChanBand = .band6GHz
                    band = 6
                } else {
                    print("invalid chan \(chan) or band \(band).")
                    return
                }
            default:
                print("invalid chan \(chan).")
                return
            }

            guard var chans = iface.supportedWLANChannels() else {
                print("Failed to get supported WLAN channels.")
                return
            }

            chans = chans.filter { ($0.channelBand.rawValue == cwChanBand.rawValue) && ($0.channelNumber == chan) && ($0.channelWidth.rawValue == cwChanWidth.rawValue) }
            if chans.count == 0 {
                print("Not supported band \(band), chan \(chan), chanwisth \(chanwidth)")
                return
            } else if chans.count > 1 {
                print("multiple CWChannel found")
                chans.forEach { print($0.ToStr()) }
                return
            }

            do {
                try iface.setWLANChannel(chans.first!)
            } catch {
                print("Failed to set channel")
                return
            }
            guard let curChan = iface.wlanChannel() else {
                print("Failed to get current channel.")
                return
            }

            print("set to \(curChan.ToStr())")
        }
    }
}

Maciw.main()
