# Brightness Control

> ROXIDE provides unified brightness control for backlight devices, LEDs, and DDC/I2C monitors.

## Table of Contents

- [Supported Device Types](#supported-device-types)
- [Device Identification](#device-identification)
- [API Endpoints](#api-endpoints)
- [Exponential Brightness Scaling](#exponential-brightness-scaling)
- [Usage Examples](#usage-examples)
- [DDC/I2C Monitor Support](#ddci2c-monitor-support)

---

## Supported Device Types

| Type | Examples | Description |
|------|----------|-------------|
| **Backlight** | `amdgpu_bl1`, `intel_backlight`, `nvidia_0` | Laptop screens, integrated displays |
| **LED** | `asus::kbd_backlight`, `phy0-led` | Keyboard backlights, indicator LEDs |
| **DDC/I2C** | `Monitor_Name` | External monitors via DDC/CI protocol |

---

## Device Identification

Devices are identified using the format `<class>:<name>`:

| Format | Example | Description |
|--------|---------|-------------|
| `backlight:<name>` | `backlight:intel_backlight` | Intel integrated graphics backlight |
| `leds:<name>` | `leds:asus::kbd_backlight` | ASUS keyboard backlight |
| `ddc:<name>` | `ddc:Monitor_Name` | External DDC monitor |

---

## API Endpoints

### Get Brightness State

```
GET /brightness
```

Returns the current brightness snapshot with available devices and selected device.

---

### List Devices

```
GET /brightness/devices
```

Returns all available brightness devices with their current values.

---

### Select Device

```
POST /brightness/select
{
  "device": "backlight:intel_backlight"
}
```

Sets the active device for brightness control.

---

### Set Brightness

```
POST /brightness
{
  "value": 50,
  "exponential": false,   // optional, default false
  "exponent": 1.2          // optional, default 1.2
}
```

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `device` | string | Device ID (uses selected if omitted) | — |
| `value` | number | Brightness percentage (0-100) | — |
| `exponential` | boolean | Enable exponential scaling | `false` |
| `exponent` | number | Exponential curve value | `1.2` |

---

### Increase Brightness

```
POST /brightness/increase
{
  "delta": 5,
  "exponential": false,
  "exponent": 1.2
}
```

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `delta` | number | Percentage to increase | — |
| `exponential` | boolean | Enable exponential scaling | `false` |
| `exponent` | number | Exponential curve value | `1.2` |

---

### Decrease Brightness

```
POST /brightness/decrease
{
  "delta": 5,
  "exponential": false,
  "exponent": 1.2
}
```

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `delta` | number | Percentage to decrease | — |
| `exponential` | boolean | Enable exponential scaling | `false` |
| `exponent` | number | Exponential curve value | `1.2` |

---

## Exponential Brightness Scaling

> Human perception of brightness is non-linear. A 50% brightness value may appear much brighter than expected. Exponential scaling makes brightness changes feel more natural.

### How it works

- Applies an exponential curve to the brightness value before setting it
- Default exponent: `1.2`
- Higher exponents create more aggressive curves (darker at mid-range)
- Lower exponents create gentler curves

### Example

```json
{
  "value": 50,
  "exponential": true,
  "exponent": 1.5
}
```

---

## Usage Examples

### List all devices

```bash
curl --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/brightness/devices
```

### Set brightness to 50%

```bash
curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/brightness \
  -H "Content-Type: application/json" \
  -d '{"value": 50}'
```

### Increase brightness by 5%

```bash
curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/brightness/increase \
  -H "Content-Type: application/json" \
  -d '{"delta": 5}'
```

### Select a specific device

```bash
curl -X POST --unix-socket $XDG_RUNTIME_DIR/roxide.sock http://localhost/brightness/select \
  -H "Content-Type: application/json" \
  -d '{"device": "backlight:intel_backlight"}'
```

---

## DDC/I2C Monitor Support

> External monitors can be controlled via the DDC/CI protocol over I2C. This is automatically detected when available.

### Requirements

- Monitor must support DDC/CI
- I2C permissions (typically handled by udev rules or user groups)

> **Note:** DDC operations are slower than backlight operations due to the I2C communication protocol.