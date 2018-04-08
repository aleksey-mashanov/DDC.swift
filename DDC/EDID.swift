internal enum Bit {
  case one
  case zero

  init(_ value: UInt8) {
    if value == 0 {
      self = .zero
    } else {
      self = .one
    }
  }
}

internal extension Bool {
  init(_ bit: Bit) {
    self.init(bit == .one)
  }
}

internal extension UInt8 {
  var bit7: Bit { get { return Bit(self >> 7             ) } }
  var bit6: Bit { get { return Bit(self >> 6 & 0b00000001) } }
  var bit5: Bit { get { return Bit(self >> 5 & 0b00000001) } }
  var bit4: Bit { get { return Bit(self >> 4 & 0b00000001) } }
  var bit3: Bit { get { return Bit(self >> 3 & 0b00000001) } }
  var bit2: Bit { get { return Bit(self >> 2 & 0b00000001) } }
  var bit1: Bit { get { return Bit(self >> 1 & 0b00000001) } }
  var bit0: Bit { get { return Bit(self      & 0b00000001) } }
}

internal extension UInt16 {
  init(_ byte1: UInt8, _ byte2: UInt8) {
    self.init(
      UInt16(byte1) << 8 |
      UInt16(byte2)
    )
  }
}

internal extension UInt32 {
  init(_ byte1: UInt8, _ byte2: UInt8, _ byte3: UInt8, _ byte4: UInt8) {
    self.init(
      UInt32(UInt16(byte1, byte2)) << 16 |
      UInt32(UInt16(byte3, byte4))
    )
  }
}

internal extension UInt64 {
  init(_ byte1: UInt8, _ byte2: UInt8, _ byte3: UInt8, _ byte4: UInt8, _ byte5: UInt8, _ byte6: UInt8, _ byte7: UInt8, _ byte8: UInt8) {
    self.init(
      UInt64(UInt32(byte1, byte2, byte3, byte4)) << 32 |
      UInt64(UInt32(byte5, byte6, byte7, byte8))
    )
  }
}

internal extension String {
  init<T: Sequence>(_ bytes: T) where T.Iterator.Element == UInt8 {
    let characters = bytes.map() { Character(UnicodeScalar($0)) }
    self.init(characters)
  }
}

class EDID {
  private static let HEADER = 0x00ffffffffffff00

  enum VideoInputDefinition {
    struct Analog {
      struct SignalLevel {
        let video: Float
        let sync: Float
        var total: Float {
          get { return self.video + self.sync }
        }
      }

      enum VideoSetup {
        case blankLevelIsBlackLevel
        case blankToBlackSetupOrPedestal
      }

      let signalLevel: SignalLevel
      let videoSetup: VideoSetup
      let separateSyncHorizontalAndVerticalSignalsSupported: Bool
      let compositeSyncSignalOnHorizontalSupported: Bool
      let compositeSyncSignalOnGreenVideoSupported: Bool
      let serrationOnVerticalSyncSupported: Bool

      internal init(_ byte: UInt8) {
        switch (byte.bit6, byte.bit5) {
          case (.zero, .zero):
            self.signalLevel = SignalLevel(video: 0.700, sync: 0.300)
          case (.zero, .one):
            self.signalLevel = SignalLevel(video: 0.714, sync: 0.286)
          case (.one, .zero):
            self.signalLevel = SignalLevel(video: 1.000, sync: 0.400)
          case (.one, .one):
            self.signalLevel = SignalLevel(video: 0.700, sync: 0.000)
        }

        switch byte.bit4 {
          case .one:
            self.videoSetup = .blankLevelIsBlackLevel
          case .zero:
            self.videoSetup = .blankToBlackSetupOrPedestal
        }

        self.separateSyncHorizontalAndVerticalSignalsSupported = Bool(byte.bit3)
        self.compositeSyncSignalOnHorizontalSupported = Bool(byte.bit2)
        self.compositeSyncSignalOnGreenVideoSupported = Bool(byte.bit1)
        self.serrationOnVerticalSyncSupported = Bool(byte.bit0)
      }
    }
    
    struct Digital {
      enum ColorBitDepth {
        case undefined
        case bitsPerPrimaryColor(UInt8)
        case reserved
      }

      enum DigitalVideoInterfaceStandardSupported {
        case undefined
        case dvi
        case hdmiA
        case hdmiB
        case mddi
        case displayPort
        case reserved
      }

      let colorBitDepth: ColorBitDepth
      let digitalVideoInterfaceStandardSupported: DigitalVideoInterfaceStandardSupported

      internal init(_ byte: UInt8) {
        switch (byte.bit6, byte.bit5, byte.bit4) {
          case (.zero, .zero, .zero):
            self.colorBitDepth = .undefined
          case (.zero, .zero, .one):
            self.colorBitDepth = .bitsPerPrimaryColor(6)
          case (.zero, .one, .zero):
            self.colorBitDepth = .bitsPerPrimaryColor(8)
          case (.zero, .one, .one):
            self.colorBitDepth = .bitsPerPrimaryColor(10)
          case (.one, .zero, .zero):
            self.colorBitDepth = .bitsPerPrimaryColor(12)
          case (.one, .zero, .one):
            self.colorBitDepth = .bitsPerPrimaryColor(14)
          case (.one, .one, .zero):
            self.colorBitDepth = .bitsPerPrimaryColor(16)
          case (.one, .one, .one):
            self.colorBitDepth = .reserved
        }

        switch (byte.bit3, byte.bit2, byte.bit1, byte.bit0) {
          case (.zero, .zero, .zero, .zero):
            self.digitalVideoInterfaceStandardSupported = .undefined
          case (.zero, .zero, .zero, .one):
            self.digitalVideoInterfaceStandardSupported = .dvi
          case (.zero, .zero, .one, .zero):
            self.digitalVideoInterfaceStandardSupported = .hdmiA
          case (.zero, .zero, .one, .one):
            self.digitalVideoInterfaceStandardSupported = .hdmiB
          case (.zero, .one, .zero, .zero):
            self.digitalVideoInterfaceStandardSupported = .mddi
          case (.zero, .one, .zero, .one):
            self.digitalVideoInterfaceStandardSupported = .displayPort
          case (_, _, _, _):
            self.digitalVideoInterfaceStandardSupported = .reserved
        }
      }
    }
  
    case analog(Analog)
    case digital(Digital)
    
    internal init(_ byte: UInt8)  {
      switch byte.bit7 {
        case .zero:
          self = .analog(Analog(byte))
        case .one:
          self = .digital(Digital(byte))
      }
    }
  }

  enum Descriptor {
    case timing(IODetailedTimingInformation)
    case serialNumber(String)
    case text(String)
    case rangeLimits([UInt8])
    case displayName(String)
    case whitePoint([UInt8])
    case additionalStandardTimingInformation(StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?)
    case displayColorManagement([UInt8])
    case cvtTimingCodes([UInt8])
    case additionalStandardTiming3([UInt8])
    case dummy
    case reserved

    internal init<T: Collection>(data: T) where T.Index == Int, T.Element == UInt8 {
      let type = data[3]

      switch type {
      case 0xFF:
        self = .serialNumber(String(data[5...17]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
      case 0xFE:
        self = .text(String(data[5...17]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
      case 0xFD:
        self = .rangeLimits(Array(data))
      case 0xFC:
        self = .displayName(String(data[5...17]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))
      case 0xFB:
        self = .whitePoint(Array(data))
      case 0xFA:
        self = .additionalStandardTimingInformation(
          StandardTimingInformation(with: data[5...6]),
          StandardTimingInformation(with: data[7...8]),
          StandardTimingInformation(with: data[9...10]),
          StandardTimingInformation(with: data[11...12]),
          StandardTimingInformation(with: data[13...14]),
          StandardTimingInformation(with: data[15...16])
        )
      case 0xF9:
        self = .displayColorManagement(Array(data))
      case 0xF8:
        self = .cvtTimingCodes(Array(data))
      case 0xF7:
        self = .additionalStandardTiming3(Array(data))
      case 0x10:
        self = .dummy
      default:
        self = .reserved
      }
    }
  }

  struct StandardTimingInformation {
    let resolution: UInt8
    let aspectRatio: UInt8
    let verticalFrequency: UInt8

    init?<T: Collection>(with data: T) where T.Index == Int, T.Element == UInt8 {
      if data[0] == 1 && data[1] == 1 {
        return nil
      }

      self.resolution = data[0]
      self.aspectRatio = data[1] >> 6
      self.verticalFrequency = data[1] & 0b111111
    }
  }

  let rawValue: [UInt8]

  lazy var header: UInt64 = { [unowned self] in UInt64(self.rawValue[0], self.rawValue[1], self.rawValue[2], self.rawValue[3], self.rawValue[4], self.rawValue[5], self.rawValue[6], self.rawValue[7]) }()

  lazy var manufacturerId: UInt16 = { [unowned self] in UInt16(self.rawValue[8], self.rawValue[9]) }()

  lazy var productCode: UInt16 = { [unowned self] in UInt16(self.rawValue[11], self.rawValue[10]) }()

  lazy var serialNumber: UInt32 = { [unowned self] in UInt32(self.rawValue[15], self.rawValue[14], self.rawValue[13], self.rawValue[12]) }()

  lazy var week: UInt8 = { [unowned self] in self.rawValue[16] }()
  lazy var year: Int = { [unowned self] in 1990 + Int(self.rawValue[17]) }()

  lazy var edidVersion: UInt8 = { [unowned self] in self.rawValue[18] }()
  lazy var edidRevision: UInt8 = { [unowned self] in self.rawValue[19] }()

  lazy var videoInputDefinition: VideoInputDefinition = { [unowned self] in VideoInputDefinition(self.rawValue[20]) }()

  lazy var screenWidth: Measurement? = { [unowned self] in
    if self.rawValue[21] == 0 {
      return nil
    }

    return Measurement(value: Double(self.rawValue[21]), unit: UnitLength.centimeters)
  }()
  lazy var screenHeight: Measurement? = { [unowned self] in
    if self.rawValue[22] == 0 {
      return nil
    }

    return Measurement(value: Double(self.rawValue[22]), unit: UnitLength.centimeters)
  }()
  lazy var aspectRatio: Float? = { [unowned self] in
    if self.screenWidth != nil, self.screenHeight == nil {
      let landscapeAspectRatio = Float(self.rawValue[21]) * 2.54 + 1.0
      return landscapeAspectRatio
    }

    if self.screenHeight != nil, self.screenWidth == nil {
      let portraitAspectRatio = Float(self.rawValue[22]) * 0.71 + 0.28
      let landscapeAspectRatio = 1.0 / portraitAspectRatio
      return landscapeAspectRatio
    }

    return nil
  }()

  lazy var gamma: Float = { [unowned self] in ((Float(self.rawValue[23]) / 255.0 * 2.54 + 1.0) * 100.0).rounded() / 100.0 }()

  lazy var features: UInt8 = { [unowned self] in self.rawValue[24] }()

  lazy var redAndGreenLeastSignificantBits: UInt8 = { [unowned self] in self.rawValue[25] }()
  lazy var blueAndWhiteLeastSignificantBits: UInt8 = { [unowned self] in self.rawValue[26] }()
  lazy var redXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[27] }()
  lazy var redYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[28] }()
  lazy var greenXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[29] }()
  lazy var greenYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[30] }()
  lazy var blueXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[31] }()
  lazy var blueYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[32] }()
  lazy var whitePointXValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[33] }()
  lazy var whitePointYValueMostSignificantBits: UInt8 = { [unowned self] in self.rawValue[34] }()

  lazy var timing720x400At70Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b10000000 == 1 }()
  lazy var timing720x400At88Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b01000000 == 1 }()
  lazy var timing640x480At60Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00100000 == 1 }()
  lazy var timing640x480At67Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00010000 == 1 }()
  lazy var timing640x480At72Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00001000 == 1 }()
  lazy var timing640x480At75Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00000100 == 1 }()
  lazy var timing800x600At56Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00000010 == 1 }()
  lazy var timing800x600At60Hz: Bool   = { [unowned self] in self.rawValue[35] & 0b00000001 == 1 }()

  lazy var timing800x600At72Hz: Bool   = { [unowned self] in self.rawValue[36] & 0b10000000 == 1 }()
  lazy var timing800x600At75Hz: Bool   = { [unowned self] in self.rawValue[36] & 0b01000000 == 1 }()
  lazy var timing832x624At75Hz: Bool   = { [unowned self] in self.rawValue[36] & 0b00100000 == 1 }()
  lazy var timing1024x768At87Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00010000 == 1 }()
  lazy var timing1024x768At60Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00001000 == 1 }()
  lazy var timing1024x768At72Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00000100 == 1 }()
  lazy var timing1024x768At75Hz: Bool  = { [unowned self] in self.rawValue[36] & 0b00000010 == 1 }()
  lazy var timing1280x1024At75Hz: Bool = { [unowned self] in self.rawValue[36] & 0b00000001 == 1 }()

  lazy var timing1152x870At75Hz: Bool  = { [unowned self] in self.rawValue[37] & 0b10000000 == 1 }()
  lazy var timingModeA: Bool           = { [unowned self] in self.rawValue[37] & 0b01000000 == 1 }()
  lazy var timingModeB: Bool           = { [unowned self] in self.rawValue[37] & 0b00100000 == 1 }()
  lazy var timingModeC: Bool           = { [unowned self] in self.rawValue[37] & 0b00010000 == 1 }()
  lazy var timingModeD: Bool           = { [unowned self] in self.rawValue[37] & 0b00001000 == 1 }()
  lazy var timingModeE: Bool           = { [unowned self] in self.rawValue[37] & 0b00000100 == 1 }()
  lazy var timingModeF: Bool           = { [unowned self] in self.rawValue[37] & 0b00000010 == 1 }()
  lazy var timingModeG: Bool           = { [unowned self] in self.rawValue[37] & 0b00000001 == 1 }()

  lazy var standardDisplayModes: (StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?, StandardTimingInformation?) = { [unowned self] in
    (
      StandardTimingInformation(with: self.rawValue[38...39]),
      StandardTimingInformation(with: self.rawValue[40...41]),
      StandardTimingInformation(with: self.rawValue[42...43]),
      StandardTimingInformation(with: self.rawValue[44...45]),
      StandardTimingInformation(with: self.rawValue[46...47]),
      StandardTimingInformation(with: self.rawValue[48...49]),
      StandardTimingInformation(with: self.rawValue[50...51]),
      StandardTimingInformation(with: self.rawValue[52...53])
    )
  }()

  lazy var descriptors: (Descriptor, Descriptor, Descriptor, Descriptor) =  { [unowned self] in
    (
      EDID.detailedTimingInformation(from: Array(self.rawValue[54...71])),
      EDID.detailedTimingInformation(from: Array(self.rawValue[72...89])),
      EDID.detailedTimingInformation(from: Array(self.rawValue[90...107])),
      EDID.detailedTimingInformation(from: Array(self.rawValue[108...125]))
    )
  }()

  lazy var extensions: UInt8 = { [unowned self] in self.rawValue[126] }()

  lazy var checksum: UInt8 = { [unowned self] in self.rawValue[0...127].reduce(UInt8(0)) { $0.addingReportingOverflow($1).partialValue } }()

  init?(data: [UInt8]) {
    guard data.count >= 128 else {
      return nil
    }

    self.rawValue = data

    guard self.header == EDID.HEADER else {
      return nil
    }

    guard self.checksum == 0 else {
      return nil
    }
  }

  func manufacturerString() -> String {
    let offset = UInt16("A".unicodeScalars.first!.value - 1)

    let letter1 = self.manufacturerId >> 10 & 0b11111 + offset
    let letter2 = self.manufacturerId >>  5 & 0b11111 + offset
    let letter3 = self.manufacturerId >>  0 & 0b11111 + offset

    return String(format: "%c%c%c", letter1, letter2, letter3)
  }

  func edidVersionString() -> String {
    return "\(self.edidVersion).\(self.edidRevision)"
  }

  private static func detailedTimingInformation<T: Collection>(from data: T) -> Descriptor where T.Index == Int, T.Element == UInt8 {
    let pixelClock = UInt16(data[0], data[1])

    if pixelClock == 0 {
      return Descriptor(data: data)
    }

    var timingInformation = IODetailedTimingInformation()

    timingInformation.pixelClock = UInt64(pixelClock)

    timingInformation.horizontalActive = UInt32(UInt16(data[4] >> 4, data[2]))
    timingInformation.horizontalBlanking = UInt32(UInt16(data[4] & 0b1111, data[3]))

    timingInformation.verticalActive =  UInt32(UInt16(data[7] >> 4, data[5]))
    timingInformation.verticalBlanking =  UInt32(UInt16(data[7] & 0b1111, data[6]))

    timingInformation.horizontalSyncOffset = UInt32(UInt16(data[11] >> 6, data[8]))
    timingInformation.horizontalSyncPulseWidth = UInt32(UInt16(data[11] >> 4 & 0b11, data[9]))

    timingInformation.verticalSyncOffset = UInt32((data[10] >> 4) & 0b1111) | (UInt32((data[11] >> 2) & 0b11) << 4)
    timingInformation.verticalSyncPulseWidth = UInt32(data[10] & 0b1111) | (UInt32(data[11] & 0b11) << 4)

    timingInformation.horizontalScaled =   UInt32(UInt16(data[14] >> 4, data[12]))
    timingInformation.verticalScaled = UInt32(UInt16(data[14] & 0b1111, data[13]))

    timingInformation.horizontalBorderLeft = UInt32(data[15])
    timingInformation.horizontalBorderRight = UInt32(data[15])

    timingInformation.verticalBorderTop = UInt32(data[16])
    timingInformation.verticalBorderBottom = UInt32(data[16])

    return Descriptor.timing(timingInformation)
  }
}
